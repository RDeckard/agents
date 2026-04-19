# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reports", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin) { create(:user, :admin) }

  describe "authentication" do
    it "redirects to login when not authenticated" do
      get reports_path
      expect(response).to redirect_to(login_path)
    end
  end

  describe "GET /reports" do
    it "shows only the current user's reports" do
      create(:report, user: user, filename: "my_report.html")
      create(:report, user: other_user, filename: "other_report.html")

      login_as user
      get reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("my_report.html")
      expect(response.body).not_to include("other_report.html")
    end

    it "shows all reports to admins" do
      create(:report, user: user, filename: "user_report.html")
      create(:report, user: other_user, filename: "other_report.html")
      create(:report, user: nil, filename: "orphan_report.html")

      login_as admin
      get reports_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("user_report.html")
      expect(response.body).to include("other_report.html")
      expect(response.body).to include("orphan_report.html")
    end
  end

  describe "GET /reports/:id" do
    it "serves the HTML content of the report" do
      report = create(:report, user: user, content: "<html><h1>My Report</h1></html>")

      login_as user
      get report_path(report)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("My Report")
    end

    it "denies access to another user's report" do
      report = create(:report, user: other_user)

      login_as user
      get report_path(report)

      expect(response).to have_http_status(:not_found)
    end

    it "allows admins to view any report" do
      report = create(:report, user: other_user, content: "<html><h1>Admin View</h1></html>")

      login_as admin
      get report_path(report)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Admin View")
    end
  end

  describe "report persistence" do
    it "reports survive session deletion" do
      session_record = create(:session, user: user)
      report = create(:report, session: session_record, user: user, filename: "surviving.html")

      session_record.destroy!

      expect(Report.find(report.id)).to be_present
      expect(Report.find(report.id).session_id).to be_nil
    end

    it "reports without sessions are still listed" do
      create(:report, session: nil, user: user, filename: "orphan.html")

      login_as user
      get reports_path

      expect(response.body).to include("orphan.html")
    end
  end
end
