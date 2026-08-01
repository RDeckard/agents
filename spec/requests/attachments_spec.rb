# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Attachments", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe "authentication" do
    it "redirects to login when not authenticated" do
      get attachments_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "GET /attachments" do
    it "shows only the current user's attachments" do
      create(:attachment, user: user, filename: "my_output.html")
      create(:attachment, user: other_user, filename: "other_output.html")

      login_as user
      get attachments_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("my_output.html")
      expect(response.body).not_to include("other_output.html")
    end

    it "shows only admin's own attachments in index" do
      create(:attachment, user: admin, filename: "admin_output.html")
      create(:attachment, user: other_user, filename: "other_output.html")

      login_as admin
      get attachments_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("admin_output.html")
      expect(response.body).not_to include("other_output.html")
    end

    it "filters by kind" do
      create(:attachment, user: user, filename: "output.html", kind: "agent_output")
      create(:attachment, :input, user: user, filename: "input.csv")

      login_as user
      get attachments_path(kind: "agent_output")

      expect(response.body).to include("output.html")
      expect(response.body).not_to include("input.csv")
    end
  end

  describe "GET /attachments/:id" do
    it "redirects to the file blob for an agent output" do
      attachment = create(:attachment, user: user)

      login_as user
      get attachment_path(attachment)

      expect(response).to have_http_status(:redirect)
    end

    it "denies access to another user's attachment" do
      attachment = create(:attachment, user: other_user)

      login_as user
      get attachment_path(attachment)

      expect(response).to have_http_status(:not_found)
    end

    it "allows admins to view any attachment" do
      attachment = create(:attachment, user: other_user)

      login_as admin
      get attachment_path(attachment)

      expect(response).to have_http_status(:redirect)
    end
  end

  describe "persistence" do
    it "attachments are destroyed with their session" do
      session_record = create(:session, user: user)
      attachment = create(:attachment, session: session_record, user: user, filename: "gone.html")

      session_record.destroy!

      expect(Attachment.exists?(attachment.id)).to be false
    end
  end
end
