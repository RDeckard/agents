# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:session_record) { create(:session, user: user, anthropic_session_id: "sesn_test789") }

  before do
    stub_anthropic_list_sessions
    stub_anthropic_get_session
    stub_anthropic_list_events
    stub_anthropic_session_files
  end

  def parse_sse(body)
    body.split("\n\n").filter_map do |chunk|
      next unless chunk.start_with?("data: ")

      JSON.parse(chunk.sub("data: ", ""))
    end
  end

  describe "authentication" do
    it "redirects to login when not authenticated" do
      get sessions_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "GET /sessions" do
    it "shows only the current user's sessions" do
      session_record # create it
      create(:session, user: other_user, anthropic_session_id: "sesn_other")

      login_as user
      get sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(session_path(session_record))
      expect(response.body).not_to include("sesn_other")
    end

    it "shows only admin's own sessions in index" do
      admin_session = create(:session, user: admin, anthropic_session_id: "sesn_admin_own")
      create(:session, user: user, anthropic_session_id: "sesn_other")
      create(:session, user: nil, anthropic_session_id: "sesn_orphan")

      login_as admin
      get sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(session_path(admin_session))
      expect(response.body).not_to include("unowned")
    end

    it "syncs bookmarks for unknown Anthropic sessions" do
      stub_anthropic_list_sessions([build(:anthropic_session, id: "sesn_new_from_api")])

      login_as admin
      expect { get sessions_path }.to change(Session, :count).by(1)

      new_session = Session.find_by(anthropic_session_id: "sesn_new_from_api")
      expect(new_session.user).to be_nil
    end

    it "does not create duplicate bookmarks on reload" do
      session_record # create it

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

      created = Session.last
      expect(created.user).to eq(user)
      expect(created.anthropic_session_id).to eq("sesn_test789")
      expect(response).to redirect_to(session_path(created))
    end

    it "creates session without files when none provided" do
      stub_anthropic_upload_file
      login_as user

      post agent_sessions_path("agent_test123"), params: { environment_id: "env_test456" }

      expect(AnthropicClient).not_to have_received(:upload_file)
      expect(response).to redirect_to(session_path(Session.last))
    end

    context "with file uploads" do
      let(:tempfile) do
        file = Tempfile.new(["test", ".csv"])
        file.write("col1,col2\na,b")
        file.rewind
        file
      end

      let(:uploaded_file) do
        Rack::Test::UploadedFile.new(tempfile.path, "text/csv", false, original_filename: "data.csv")
      end

      before { stub_anthropic_upload_file }

      after { tempfile.close! }

      it "uploads files and creates input attachments" do
        login_as user

        expect do
          post agent_sessions_path("agent_test123"), params: {
            environment_id: "env_test456",
            files: [uploaded_file]
          }
        end.to change(Attachment, :count).by(1)

        expect(AnthropicClient).to have_received(:upload_file)
        expect(AnthropicClient).to have_received(:create_session).with(
          hash_including(resources: a_collection_containing_exactly(
            hash_including(type: "file", mount_path: a_string_matching(%r{^/workspace/}))
          ))
        )

        attachment = Attachment.last
        expect(attachment.kind).to eq("uploaded_input")
        expect(attachment.file).to be_attached
        expect(attachment.user).to eq(user)
      end

      it "handles multiple file uploads" do
        file_ids = %w[file_up1 file_up2].each
        allow(AnthropicClient).to receive(:upload_file) do
          AnthropicFile.new(id: file_ids.next, filename: "uploaded")
        end

        tempfile2 = Tempfile.new(["test2", ".txt"])
        tempfile2.write("hello")
        tempfile2.rewind
        uploaded_file2 = Rack::Test::UploadedFile.new(tempfile2.path, "text/plain", false,
                                                      original_filename: "notes.txt")

        login_as user

        expect do
          post agent_sessions_path("agent_test123"), params: {
            environment_id: "env_test456",
            files: [uploaded_file, uploaded_file2]
          }
        end.to change(Attachment, :count).by(2)

        expect(AnthropicClient).to have_received(:upload_file).twice

        kinds = Attachment.last(2).map(&:kind)
        expect(kinds).to all(eq("uploaded_input"))
      ensure
        tempfile2.close!
      end
    end
  end

  describe "GET /sessions/:id" do
    context "when HTML format" do
      it "allows the owner to view their session" do
        login_as user
        get session_path(session_record)

        expect(response).to have_http_status(:ok)
      end

      it "denies access to another user's session" do
        other_session = create(:session, user: other_user, anthropic_session_id: "sesn_test789")

        login_as user
        get session_path(other_session)

        expect(response).to have_http_status(:not_found)
      end

      it "allows admins to view any session" do
        login_as admin
        get session_path(session_record)

        expect(response).to have_http_status(:ok)
      end

      it "persists outputs when loading a session" do
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
        create(:attachment, session: session_record, user: user, anthropic_file_id: "file_abc")
        stub_anthropic_session_files([build(:anthropic_file, id: "file_abc")])

        login_as user
        expect { get session_path(session_record) }.not_to change(Attachment, :count)
      end
    end

    context "when JSON format" do
      before { login_as user }

      it "returns output files as JSON" do
        create(:attachment, :output, session: session_record, user: user, filename: "report.html")

        get session_path(session_record, format: :json)

        expect(response).to have_http_status(:ok)
        data = response.parsed_body
        expect(data["outputs"].size).to eq(1)
        expect(data["outputs"].first["filename"]).to eq("report.html")
        expect(data["outputs"].first["url"]).to be_present
      end

      it "returns empty array when no outputs exist" do
        get session_path(session_record, format: :json)

        data = response.parsed_body
        expect(data["outputs"]).to eq([])
      end

      it "excludes input attachments from outputs" do
        create(:attachment, :output, session: session_record, user: user, filename: "result.html")
        create(:attachment, :input, session: session_record, user: user)

        get session_path(session_record, format: :json)

        data = response.parsed_body
        expect(data["outputs"].size).to eq(1)
        expect(data["outputs"].first["filename"]).to eq("result.html")
      end
    end
  end

  describe "POST /sessions/:id/message" do
    it "sends a message scoped to the owner" do
      stub_anthropic_send_message

      login_as user
      post message_session_path(session_record), params: { text: "Hello" }

      expect(response).to have_http_status(:ok)
      expect(AnthropicClient).to have_received(:send_message).with(
        session_id: "sesn_test789", text: "Hello", file_ids: []
      )
    end

    it "denies message to another user's session" do
      other_session = create(:session, user: other_user, anthropic_session_id: "sesn_test789")

      login_as user
      post message_session_path(other_session), params: { text: "Hello" }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /sessions/:id/events" do
    let(:idle_end_turn) do
      AnthropicEvent.new(type: :"session.status_idle",
                         stop_reason: AnthropicStopReason.new(type: :end_turn))
    end

    before { login_as user }

    it "streams agent.message events" do
      stub_anthropic_stream_events([
                                     build_anthropic_event(type: "agent.message", text: "Hello world"),
                                     idle_end_turn
                                   ])

      get events_session_path(session_record)

      message = parse_sse(response.body).find { |e| e["type"] == "message" }
      expect(message).to be_present
      expect(message["content"]).to eq("Hello world")
    end

    it "streams thinking events" do
      stub_anthropic_stream_events([
                                     build_anthropic_event(type: "agent.thinking", text: "Let me think..."),
                                     idle_end_turn
                                   ])

      get events_session_path(session_record)

      thinking = parse_sse(response.body).find { |e| e["type"] == "thinking" }
      expect(thinking).to be_present
      expect(thinking["content"]).to eq("Let me think...")
    end

    it "streams tool_use events" do
      stub_anthropic_stream_events([
                                     AnthropicEvent.new(type: :"agent.tool_use", name: "bash",
                                                        input: { command: "ls" }),
                                     idle_end_turn
                                   ])

      get events_session_path(session_record)

      tool = parse_sse(response.body).find { |e| e["type"] == "tool_use" }
      expect(tool).to be_present
      expect(tool["name"]).to eq("bash")
      expect(tool["input"]).to eq({ "command" => "ls" })
    end

    it "streams tool_result events" do
      stub_anthropic_stream_events([
                                     build_anthropic_event(type: "agent.tool_result", text: "file1.txt\nfile2.txt"),
                                     idle_end_turn
                                   ])

      get events_session_path(session_record)

      result = parse_sse(response.body).find { |e| e["type"] == "tool_result" }
      expect(result).to be_present
      expect(result["content"]).to include("file1.txt")
    end

    it "streams status running events" do
      stub_anthropic_stream_events([
                                     AnthropicEvent.new(type: :"session.status_running"),
                                     idle_end_turn
                                   ])

      get events_session_path(session_record)

      status = parse_sse(response.body).find { |e| e["type"] == "status" && e["status"] == "running" }
      expect(status).to be_present
    end

    it "streams error events" do
      stub_anthropic_stream_events([
                                     AnthropicEvent.new(type: :"session.error"),
                                     idle_end_turn
                                   ])

      get events_session_path(session_record)

      error = parse_sse(response.body).find { |e| e["type"] == "error" }
      expect(error).to be_present
    end

    it "breaks on idle with end_turn" do
      stub_anthropic_stream_events([
                                     build_anthropic_event(type: "agent.message", text: "Done"),
                                     idle_end_turn,
                                     build_anthropic_event(type: "agent.message", text: "Should not appear")
                                   ])

      get events_session_path(session_record)

      messages = parse_sse(response.body).select { |e| e["type"] == "message" }
      expect(messages.size).to eq(1)
      expect(messages.first["content"]).to eq("Done")
    end

    it "does not break on idle with requires_action" do
      stub_anthropic_stream_events([
                                     build_anthropic_event(type: "agent.message", text: "Need approval"),
                                     AnthropicEvent.new(type: :"session.status_idle",
                                                        stop_reason: AnthropicStopReason.new(type: :requires_action)),
                                     build_anthropic_event(type: "agent.message", text: "Continuing"),
                                     idle_end_turn
                                   ])

      get events_session_path(session_record)

      messages = parse_sse(response.body).select { |e| e["type"] == "message" }
      expect(messages.size).to eq(2)
    end

    it "breaks on terminated" do
      stub_anthropic_stream_events([
                                     build_anthropic_event(type: "agent.message", text: "Oops"),
                                     AnthropicEvent.new(type: :"session.status_terminated"),
                                     build_anthropic_event(type: "agent.message", text: "Should not appear")
                                   ])

      get events_session_path(session_record)

      messages = parse_sse(response.body).select { |e| e["type"] == "message" }
      expect(messages.size).to eq(1)
    end

    it "persists outputs on idle" do
      stub_anthropic_session_files([build(:anthropic_file)])
      stub_anthropic_download_file("<html><body>Generated</body></html>")
      stub_anthropic_stream_events([
                                     build_anthropic_event(type: "agent.message", text: "Done"),
                                     idle_end_turn
                                   ])

      expect { get events_session_path(session_record) }.to change(Attachment, :count).by(1)
    end

    it "skips unknown event types" do
      stub_anthropic_stream_events([
                                     AnthropicEvent.new(type: :"session.some_unknown_type"),
                                     build_anthropic_event(type: "agent.message", text: "Real message"),
                                     idle_end_turn
                                   ])

      get events_session_path(session_record)

      types = parse_sse(response.body).pluck("type")
      expect(types).not_to include("some_unknown_type")
      expect(types).to include("message")
    end
  end

  describe "GET /sessions/:id/output" do
    before { login_as user }

    it "redirects to the persisted output file" do
      create(:attachment, session: session_record, user: user)

      get output_session_path(session_record)

      expect(response).to have_http_status(:redirect)
    end

    it "fetches and persists on first access if not in DB" do
      stub_anthropic_session_files([build(:anthropic_file)])
      stub_anthropic_download_file("<html><h1>Fetched</h1></html>")

      expect { get output_session_path(session_record) }.to change(Attachment, :count).by(1)

      expect(response).to have_http_status(:redirect)
    end

    it "returns 404 when no output exists" do
      get output_session_path(session_record)

      expect(response).to have_http_status(:not_found)
    end
  end
end
