# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Agents", type: :request do
  let(:user) { create(:user) }

  before { login_as user }

  describe "GET / (agents#index)" do
    it "lists all agents from the Anthropic API" do
      stub_anthropic_agents_list

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Deep researcher")
    end

    it "redirects to login when not authenticated" do
      # reset session by deleting cookie
      reset!
      get root_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "GET /agents/:id (agents#show)" do
    it "displays the agent details and a session creation form" do
      stub_anthropic_agent
      stub_anthropic_environments

      get agent_path("agent_test123")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Deep researcher")
      expect(response.body).to include("Start a new session")
    end
  end
end
