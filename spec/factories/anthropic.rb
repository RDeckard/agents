# frozen_string_literal: true

AnthropicEvent = Struct.new(:id, :type, :content, :name, :input, :stop_reason, keyword_init: true)
AnthropicTextBlock = Struct.new(:type, :text, keyword_init: true)
AnthropicStopReason = Struct.new(:type, keyword_init: true)
AnthropicAgent = Struct.new(:id, :name, :description, :model, :tools, keyword_init: true)
AnthropicModel = Struct.new(:id, keyword_init: true)
AnthropicEnvironment = Struct.new(:id, :name, keyword_init: true)
AnthropicSessionAgent = Struct.new(:name, :id, keyword_init: true)
AnthropicSession = Struct.new(:id, :title, :status, :agent, keyword_init: true)
AnthropicFile = Struct.new(:id, :filename, keyword_init: true)
AnthropicList = Struct.new(:data, keyword_init: true)

FactoryBot.define do
  factory :anthropic_agent, class: "AnthropicAgent" do
    id { "agent_test123" }
    name { "Deep researcher" }
    description { "Conducts multi-step web research" }
    model { AnthropicModel.new(id: "claude-sonnet-4-6") }
    tools { [{ type: "agent_toolset_20260401" }] }

    initialize_with { AnthropicAgent.new(**attributes) }
  end

  factory :anthropic_model, class: "AnthropicModel" do
    id { "claude-sonnet-4-6" }

    initialize_with { AnthropicModel.new(**attributes) }
  end

  factory :anthropic_environment, class: "AnthropicEnvironment" do
    id { "env_test456" }
    name { "default" }

    initialize_with { AnthropicEnvironment.new(**attributes) }
  end

  factory :anthropic_session, class: "AnthropicSession" do
    id { "sesn_test789" }
    title { "Deep researcher — Apr 19 16:30" }
    status { "idle" }
    agent { AnthropicSessionAgent.new(name: "Deep researcher", id: "agent_test123") }

    initialize_with { AnthropicSession.new(**attributes) }
  end

  factory :anthropic_file, class: "AnthropicFile" do
    id { "file_abc" }
    filename { "output.html" }

    initialize_with { AnthropicFile.new(**attributes) }
  end
end
