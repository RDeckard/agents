# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  before do
    stub_anthropic_get_session
    stub_anthropic_list_events
    stub_anthropic_session_files
  end

  describe "authentication" do
    it "redirects to login when not authenticated" do
      get sessions_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "GET /sessions" do
    it "shows only the current user's sessions" do
      my_session = create(:session, user: user, anthropic_session_id: "sesn_test789")
      _other_session = create(:session, user: other_user, anthropic_session_id: "sesn_other")

      login_as user
      get sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(session_path(my_session))
      expect(response.body).not_to include("sesn_other")
    end

    it "shows only admin's own sessions in index" do
      create(:session, user: admin, anthropic_session_id: "sesn_admin_own")
      create(:session, user: user, anthropic_session_id: "sesn_other")

      login_as admin
      get sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(session_path(Session.find_by(anthropic_session_id: "sesn_admin_own")))
    end
  end

  describe "POST /agents/:agent_id/sessions" do
    before do
      stub_anthropic_agent
      stub_anthropic_create_session
    end

    it "creates a bookmark linked to the current user" do
      login_as user

      expect do
        post agent_sessions_path("agent_test123"), params: { environment_id: "env_test456" }
      end.to change(Session, :count).by(1)

      session_record = Session.last
      expect(session_record.user).to eq(user)
      expect(session_record.anthropic_session_id).to eq("sesn_test789")
      expect(response).to redirect_to(session_path(session_record))
    end

    it "stores title and agent_name locally" do
      login_as user
      post agent_sessions_path("agent_test123"), params: { environment_id: "env_test456" }

      session_record = Session.last
      expect(session_record.title).to be_present
      expect(session_record.agent_name).to eq("Deep researcher")
    end
  end

  describe "GET /sessions/:id" do
    it "allows the owner to view their session" do
      session_record = create(:session, user: user, anthropic_session_id: "sesn_test789")

      login_as user
      get session_path(session_record)

      expect(response).to have_http_status(:ok)
    end

    it "denies access to another user's session" do
      session_record = create(:session, user: other_user, anthropic_session_id: "sesn_test789")

      login_as user
      get session_path(session_record)

      expect(response).to have_http_status(:not_found)
    end

    it "allows admins to view any session" do
      session_record = create(:session, user: other_user, anthropic_session_id: "sesn_test789")

      login_as admin
      get session_path(session_record)

      expect(response).to have_http_status(:ok)
    end

    it "persists outputs when loading a session" do
      session_record = create(:session, user: user, anthropic_session_id: "sesn_test789")
      stub_anthropic_session_files([build(:anthropic_file)])
      stub_anthropic_download_file("<html><body>New Report</body></html>")

      login_as user
      expect { get session_path(session_record) }.to change(Attachment, :count).by(1)

      attachment = Attachment.last
      expect(attachment.session).to eq(session_record)
      expect(attachment.user).to eq(user)
      expect(attachment.anthropic_file_id).to eq("file_abc")
      expect(attachment.kind).to eq("agent_output")
      expect(attachment.file).to be_attached
    end

    it "does not duplicate outputs on reload" do
      session_record = create(:session, user: user, anthropic_session_id: "sesn_test789")
      create(:attachment, session: session_record, user: user, anthropic_file_id: "file_abc")
      stub_anthropic_session_files([build(:anthropic_file, id: "file_abc")])

      login_as user
      expect { get session_path(session_record) }.not_to change(Attachment, :count)
    end
  end

  describe "POST /sessions/:id/message" do
    it "sends a message scoped to the owner" do
      stub_anthropic_send_message
      session_record = create(:session, user: user, anthropic_session_id: "sesn_test789")

      login_as user
      post message_session_path(session_record), params: { text: "Hello" }

      expect(response).to have_http_status(:ok)
      expect(AnthropicClient).to have_received(:send_message).with(
        session_id: "sesn_test789", text: "Hello"
      )
    end

    it "denies message to another user's session" do
      session_record = create(:session, user: other_user, anthropic_session_id: "sesn_test789")

      login_as user
      post message_session_path(session_record), params: { text: "Hello" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /sessions/:id" do
    before do
      stub_anthropic_delete_session
      stub_anthropic_delete_file
      stub_anthropic_session_files
    end

    it "deletes the session and its attachments" do
      session_record = create(:session, user: user)
      create(:attachment, session: session_record, user: user, anthropic_file_id: "file_1")

      login_as user

      expect do
        delete session_path(session_record)
      end.to change(Session, :count).by(-1).and change(Attachment, :count).by(-1)

      expect(response).to redirect_to(sessions_path)
    end

    it "calls delete_session and delete_file on Anthropic" do
      session_record = create(:session, user: user, anthropic_session_id: "sesn_to_delete")
      create(:attachment, session: session_record, user: user, anthropic_file_id: "file_1")
      create(:attachment, session: session_record, user: user, anthropic_file_id: "file_2")

      login_as user
      delete session_path(session_record)

      expect(AnthropicClient).to have_received(:delete_session).with(session_id: "sesn_to_delete")
      expect(AnthropicClient).to have_received(:delete_file).with(file_id: "file_1")
      expect(AnthropicClient).to have_received(:delete_file).with(file_id: "file_2")
    end

    it "skips Anthropic file deletion for attachments without anthropic_file_id" do
      session_record = create(:session, user: user)
      create(:attachment, :input, session: session_record, user: user)

      login_as user
      delete session_path(session_record)

      expect(AnthropicClient).not_to have_received(:delete_file)
    end

    it "denies deletion to non-owner" do
      session_record = create(:session, user: other_user)

      login_as user
      delete session_path(session_record)

      expect(response).to have_http_status(:not_found)
      expect(Session.exists?(session_record.id)).to be true
    end

    it "allows admin to delete any session" do
      session_record = create(:session, user: other_user)

      login_as admin
      expect { delete session_path(session_record) }.to change(Session, :count).by(-1)

      expect(response).to redirect_to(sessions_path)
    end

    it "still destroys locally if Anthropic API call fails" do
      allow(AnthropicClient).to receive(:delete_session).and_raise(StandardError, "API error")

      session_record = create(:session, user: user)

      login_as user
      expect { delete session_path(session_record) }.to change(Session, :count).by(-1)

      expect(response).to redirect_to(sessions_path)
    end
  end

  describe "GET /sessions/:id/output" do
    it "redirects to the persisted output file" do
      session_record = create(:session, user: user, anthropic_session_id: "sesn_test789")
      create(:attachment, session: session_record, user: user)
      stub_anthropic_session_files

      login_as user
      get output_session_path(session_record)

      expect(response).to have_http_status(:redirect)
    end

    it "fetches and persists on first access if not in DB" do
      session_record = create(:session, user: user, anthropic_session_id: "sesn_test789")
      stub_anthropic_session_files([build(:anthropic_file)])
      stub_anthropic_download_file("<html><h1>Fetched</h1></html>")

      login_as user
      expect { get output_session_path(session_record) }.to change(Attachment, :count).by(1)

      expect(response).to have_http_status(:redirect)
    end

    it "returns 404 when no output exists" do
      session_record = create(:session, user: user, anthropic_session_id: "sesn_test789")
      stub_anthropic_session_files

      login_as user
      get output_session_path(session_record)

      expect(response).to have_http_status(:not_found)
    end
  end
end
