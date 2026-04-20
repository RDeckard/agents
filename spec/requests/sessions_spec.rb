# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  before do
    stub_anthropic_list_sessions
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
      create(:session, user: nil, anthropic_session_id: "sesn_orphan")

      login_as admin
      get sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(session_path(Session.find_by(anthropic_session_id: "sesn_admin_own")))
      expect(response.body).not_to include("unowned")
    end

    it "syncs bookmarks for unknown Anthropic sessions" do
      stub_anthropic_list_sessions([
                                     build(:anthropic_session, id: "sesn_new_from_api")
                                   ])

      login_as admin
      expect { get sessions_path }.to change(Session, :count).by(1)

      new_session = Session.find_by(anthropic_session_id: "sesn_new_from_api")
      expect(new_session.user).to be_nil
    end

    it "does not create duplicate bookmarks on reload" do
      create(:session, user: user, anthropic_session_id: "sesn_test789")

      login_as user
      get sessions_path
      expect { get sessions_path }.not_to change(Session, :count)
    end

    it "does not show unowned sessions to regular users" do
      create(:session, user: nil, anthropic_session_id: "sesn_test789")

      login_as user
      get sessions_path

      expect(response.body).not_to include(session_path(Session.last))
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
        session_id: "sesn_test789", text: "Hello", file_ids: []
      )
    end

    it "denies message to another user's session" do
      session_record = create(:session, user: other_user, anthropic_session_id: "sesn_test789")

      login_as user
      post message_session_path(session_record), params: { text: "Hello" }

      expect(response).to have_http_status(:not_found)
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
