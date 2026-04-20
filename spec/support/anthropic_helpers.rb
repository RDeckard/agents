# frozen_string_literal: true

module AnthropicHelpers
  def stub_anthropic_agents_list(agents = [build(:anthropic_agent)])
    response = AnthropicList.new(data: agents)
    allow(AnthropicClient).to receive(:agents).and_return(response)
  end

  def stub_anthropic_agent(agent = build(:anthropic_agent))
    allow(AnthropicClient).to receive(:agent).with(agent.id).and_return(agent)
  end

  def stub_anthropic_environments(environments = [build(:anthropic_environment)])
    response = AnthropicList.new(data: environments)
    allow(AnthropicClient).to receive(:environments).and_return(response)
  end

  def stub_anthropic_list_sessions(sessions = [build(:anthropic_session)])
    response = AnthropicList.new(data: sessions)
    allow(AnthropicClient).to receive(:list_sessions).and_return(response)
  end

  def stub_anthropic_get_session(session = build(:anthropic_session))
    allow(AnthropicClient).to receive(:get_session).and_return(session)
  end

  def stub_anthropic_create_session(session = build(:anthropic_session))
    allow(AnthropicClient).to receive(:create_session).and_return(session)
  end

  def stub_anthropic_send_message
    allow(AnthropicClient).to receive(:send_message)
  end

  def stub_anthropic_list_events(events = [])
    response = AnthropicList.new(data: events)
    allow(AnthropicClient).to receive(:list_events).and_return(response)
  end

  def build_anthropic_event(type:, text: nil, name: nil)
    content = text ? [AnthropicTextBlock.new(type: :text, text: text)] : nil
    AnthropicEvent.new(id: "sevt_#{SecureRandom.hex(8)}", type: type.to_sym, content: content, name: name)
  end

  def stub_anthropic_session_files(files = [])
    response = AnthropicList.new(data: files)
    allow(AnthropicClient).to receive(:session_files).and_return(response)
  end

  def stub_anthropic_download_file(content = "<html><body>Report</body></html>")
    allow(AnthropicClient).to receive(:download_file).and_return(StringIO.new(content))
  end

  def stub_anthropic_stream_events(events = [])
    allow(AnthropicClient).to receive(:stream_events).and_return(events)
  end

  def stub_anthropic_upload_file(file = build(:anthropic_file))
    allow(AnthropicClient).to receive(:upload_file).and_return(file)
  end
end

RSpec.configure do |config|
  config.include AnthropicHelpers
end
