# frozen_string_literal: true

class SessionsController < ApplicationController # rubocop:disable Metrics/ClassLength
  include ActionController::Live

  def index
    anthropic_sessions = AnthropicClient.list_sessions.data
    sync_bookmarks(anthropic_sessions)

    @sessions = current_user.sessions.order(created_at: :desc)

    @anthropic_data = anthropic_sessions.index_by(&:id)
  end

  DISPLAYABLE_EVENTS = %w[user.message agent.message agent.thinking agent.tool_use agent.tool_result].to_set.freeze

  def show
    @session = find_session(params[:id])
    @anthropic_session = AnthropicClient.get_session(session_id: @session.anthropic_session_id)

    persist_outputs(@session)

    respond_to do |format|
      format.html do
        all_events = AnthropicClient.list_events(session_id: @session.anthropic_session_id).data
        @history = all_events.select { |e| DISPLAYABLE_EVENTS.include?(e.type.to_s) }
      end
      format.json do
        outputs = @session.attachments.outputs.order(created_at: :asc).select { |a| a.file.attached? }
        render json: {
          outputs: outputs.map { |a| { filename: a.filename, url: url_for(a.file) } }
        }
      end
    end
  end

  def create
    agent = AnthropicClient.agent(params[:agent_id])

    resources = upload_files(params[:files])

    anthropic_session = AnthropicClient.create_session(
      agent_id: params[:agent_id],
      environment_id: params[:environment_id],
      title: params[:title].presence || "#{agent.name} — #{Time.current.strftime('%b %d %H:%M')}",
      resources: resources.presence
    )

    session_record = Session.create!(
      anthropic_session_id: anthropic_session.id,
      user: current_user
    )

    persist_input_records(session_record, resources)

    redirect_to session_path(session_record)
  end

  def message
    @session = find_session(params[:id])

    file_ids = upload_and_persist_chat_files(@session, params[:files])

    AnthropicClient.send_message(
      session_id: @session.anthropic_session_id,
      text: params[:text],
      file_ids: file_ids
    )
    head :ok
  end

  def events
    @session = find_session(params[:id])

    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no"

    stream = AnthropicClient.stream_events(session_id: @session.anthropic_session_id)
    stream.each do |event|
      data = event_to_turbo_stream(event)
      next unless data

      response.stream.write("data: #{data.to_json}\n\n")

      type = event.type.to_s

      if type == "session.status_idle" && event.stop_reason&.type&.to_s != "requires_action"
        persist_outputs(@session)
        break
      end

      break if type == "session.status_terminated"
    end
  rescue ActionController::Live::ClientDisconnected
    # Client disconnected
  ensure
    response.stream.close
  end

  def output
    @session = find_session(params[:id])
    persist_outputs(@session)

    attachment = @session.attachments.outputs.html.order(created_at: :desc).first
    if attachment&.file&.attached?
      redirect_to rails_blob_path(attachment.file, disposition: :inline), allow_other_host: true
    else
      render plain: "No output generated yet.", status: :not_found
    end
  end

  private

  def find_session(id)
    if current_user.admin?
      Session.find(id)
    else
      current_user.sessions.find(id)
    end
  end

  def sync_bookmarks(anthropic_sessions)
    known_ids = Session.where(anthropic_session_id: anthropic_sessions.map(&:id))
                       .pluck(:anthropic_session_id)
                       .to_set

    anthropic_sessions.each do |as|
      next if known_ids.include?(as.id)

      Session.create!(anthropic_session_id: as.id, user: nil)
    end
  end

  def persist_outputs(session_record)
    files = AnthropicClient.session_files(session_id: session_record.anthropic_session_id)
    files.data.each do |file|
      next if Attachment.exists?(anthropic_file_id: file.id)

      content = AnthropicClient.download_file(file_id: file.id).read
      ct = mime_for(file.filename)
      attachment = session_record.attachments.create!(
        anthropic_file_id: file.id,
        filename: file.filename,
        content_type: ct,
        byte_size: content&.bytesize,
        kind: "agent_output",
        user: session_record.user
      )
      attachment.file.attach(
        io: StringIO.new(content),
        filename: file.filename,
        content_type: ct
      )
    end
  rescue StandardError => e
    Rails.logger.warn("Failed to persist outputs for session #{session_record.id}: #{e.message}")
  end

  def upload_files(uploaded_files)
    return [] if uploaded_files.blank?

    Array(uploaded_files).map do |uploaded_file|
      anthropic_file = AnthropicClient.upload_file(
        io: uploaded_file.tempfile,
        filename: uploaded_file.original_filename,
        content_type: uploaded_file.content_type
      )
      {
        type: "file",
        file_id: anthropic_file.id,
        mount_path: "/workspace/#{uploaded_file.original_filename}",
        original: uploaded_file,
        anthropic_file: anthropic_file
      }
    end
  end

  def upload_and_persist_chat_files(session_record, uploaded_files)
    return [] if uploaded_files.blank?

    Array(uploaded_files).map do |uploaded_file|
      anthropic_file = AnthropicClient.upload_file(
        io: uploaded_file.tempfile,
        filename: uploaded_file.original_filename,
        content_type: uploaded_file.content_type
      )
      attachment = session_record.attachments.create!(
        anthropic_file_id: anthropic_file.id,
        filename: uploaded_file.original_filename,
        content_type: uploaded_file.content_type,
        byte_size: uploaded_file.size,
        kind: "uploaded_input",
        user: session_record.user
      )
      attachment.file.attach(uploaded_file)
      anthropic_file.id
    end
  end

  def persist_input_records(session_record, resources)
    resources.each do |res|
      uploaded_file = res[:original]
      attachment = session_record.attachments.create!(
        anthropic_file_id: res[:anthropic_file].id,
        filename: uploaded_file.original_filename,
        content_type: uploaded_file.content_type,
        byte_size: uploaded_file.size,
        kind: "uploaded_input",
        user: session_record.user
      )
      attachment.file.attach(uploaded_file)
    end
  end

  def event_to_turbo_stream(event)
    case event.type.to_s
    when "agent.message"
      { type: "message", content: extract_text(event) }
    when "agent.thinking"
      { type: "thinking", content: extract_text(event) }
    when "agent.tool_use"
      { type: "tool_use", name: event.name, input: event.input }
    when "agent.tool_result"
      { type: "tool_result", content: extract_text(event) }
    when "session.status_idle"
      { type: "status", status: "idle", stop_reason: event.stop_reason&.type&.to_s }
    when "session.status_running"
      { type: "status", status: "running" }
    when "session.status_terminated"
      { type: "status", status: "terminated" }
    when "session.error"
      { type: "error", message: event.to_h.to_s }
    end
  end

  def extract_text(event)
    raw = begin
      event.content
    rescue StandardError
      event[:content]
    end
    return "" if raw.nil?

    Array(raw).filter_map { |block| extract_block_text(block) }.join
  end

  def extract_block_text(block)
    if block.respond_to?(:text) && block.text.present?
      block.text
    else
      begin
        block[:text] || block["text"]
      rescue StandardError
        nil
      end
    end
  end

  def mime_for(filename)
    Rack::Mime.mime_type(File.extname(filename), "application/octet-stream")
  end
end
