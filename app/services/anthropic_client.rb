# frozen_string_literal: true

class AnthropicClient
  def self.instance
    @instance ||= Anthropic::Client.new(api_key: Rails.application.credentials.dig(:anthropic,
                                                                                   :api_key) || ENV.fetch(
                                                                                     "ANTHROPIC_API_KEY", nil
                                                                                   ))
  end

  def self.agents
    instance.beta.agents.list
  end

  def self.agent(id)
    instance.beta.agents.retrieve(id)
  end

  def self.environments
    instance.beta.environments.list
  end

  def self.list_sessions
    instance.beta.sessions.list
  end

  def self.get_session(session_id:)
    instance.beta.sessions.retrieve(session_id)
  end

  def self.create_session(agent_id:, environment_id:, title: nil, resources: nil)
    params = {
      agent: agent_id,
      environment_id: environment_id,
      title: title
    }
    params[:resources] = resources.map { |r| r.slice(:type, :file_id, :mount_path) } if resources
    instance.beta.sessions.create(**params)
  end

  def self.add_session_resource(session_id:, file_id:, mount_path: nil)
    params = { file_id: file_id, type: "file" }
    params[:mount_path] = mount_path if mount_path
    instance.beta.sessions.resources.add(session_id, **params)
  end

  def self.send_message(session_id:, text:)
    instance.beta.sessions.events.send_(
      session_id,
      events: [{ type: "user.message", content: [{ type: "text", text: text }] }]
    )
  end

  def self.stream_events(session_id:)
    instance.beta.sessions.events.stream_events(session_id)
  end

  def self.list_events(session_id:)
    instance.beta.sessions.events.list(session_id)
  end

  def self.session_files(session_id:)
    instance.beta.files.list(
      scope_id: session_id,
      request_options: {
        extra_headers: {
          "anthropic-beta" => "managed-agents-2026-04-01,files-api-2025-04-14"
        }
      }
    )
  end

  def self.download_file(file_id:)
    instance.beta.files.download(file_id)
  end

  def self.delete_session(session_id:)
    instance.beta.sessions.delete(session_id)
  end

  def self.delete_file(file_id:)
    instance.beta.files.delete(file_id)
  end

  def self.upload_file(io:, filename:, content_type: "application/octet-stream")
    file = Anthropic::FilePart.new(io.read, filename: filename, content_type: content_type)
    instance.beta.files.upload(file: file)
  end
end
