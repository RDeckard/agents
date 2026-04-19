# frozen_string_literal: true

class AgentsController < ApplicationController
  def index
    response = AnthropicClient.agents
    @agents = response.data
  end

  def show
    @agent = AnthropicClient.agent(params[:id])
    @environments = AnthropicClient.environments.data
  end
end
