# frozen_string_literal: true

class SessionsController < ApplicationController # rubocop:disable Metrics/ClassLength
  include ActionController::Live

  def index
    anthropic_sessions = AnthropicClient.list_sessions.data
    sync_bookmarks(anthropic_sessions)

    @sessions = if current_user.admin?
                  Session.includes(:user).order(created_at: :desc)
                else
                  current_user.sessions.order(created_at: :desc)
                end

    @anthropic_data = anthropic_sessions.index_by(&:id)
  end

  DISPLAYABLE_EVENTS = %w[user.message agent.message agent.thinking agent.tool_use agent.tool_result].to_set.freeze

  def show
    @session = find_session(params[:id])
    @anthropic_session = AnthropicClient.get_session(session_id: @session.anthropic_session_id)

    persist_reports(@session)

    all_events = AnthropicClient.list_events(session_id: @session.anthropic_session_id).data
    @history = all_events.select { |e| DISPLAYABLE_EVENTS.include?(e.type.to_s) }
  end

  def create
    agent = AnthropicClient.agent(params[:agent_id])
    anthropic_session = AnthropicClient.create_session(
      agent_id: params[:agent_id],
      environment_id: params[:environment_id],
      title: params[:title].presence || "#{agent.name} — #{Time.current.strftime('%b %d %H:%M')}"
    )

    session_record = Session.create!(
      anthropic_session_id: anthropic_session.id,
      user: current_user
    )

    redirect_to session_path(session_record)
  end

  def message
    @session = find_session(params[:id])
    AnthropicClient.send_message(
      session_id: @session.anthropic_session_id,
      text: params[:text]
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
        persist_reports(@session)
        break
      end

      break if type == "session.status_terminated"
    end
  rescue ActionController::Live::ClientDisconnected
    # Client disconnected
  ensure
    response.stream.close
  end

  def report
    @session = find_session(params[:id])
    persist_reports(@session)

    report = @session.reports.order(created_at: :desc).first
    if report
      render html: report.content.html_safe, layout: false # rubocop:disable Rails/OutputSafety
    else
      render plain: "No report generated yet.", status: :not_found
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

  def persist_reports(session_record)
    files = AnthropicClient.session_files(session_id: session_record.anthropic_session_id)
    files.data.select { |f| f.filename.end_with?(".html") }.each do |file|
      next if Report.exists?(anthropic_file_id: file.id)

      content = AnthropicClient.download_file(file_id: file.id).read
      session_record.reports.create!(
        anthropic_file_id: file.id,
        filename: file.filename,
        content: content,
        user: session_record.user
      )
    end
  rescue StandardError => e
    Rails.logger.warn("Failed to persist reports for session #{session_record.id}: #{e.message}")
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
    return "" unless event.respond_to?(:content)

    Array(event.content).filter_map { |block| block.text if block.respond_to?(:text) }.join
  end
end
