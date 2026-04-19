# frozen_string_literal: true

class ReportsController < ApplicationController
  def index
    @reports = if current_user.admin?
                 Report.includes(:session, :user).order(created_at: :desc)
               else
                 current_user.reports.includes(:session).order(created_at: :desc)
               end
  end

  def show
    report = find_report(params[:id])
    render html: report.content.html_safe, layout: false # rubocop:disable Rails/OutputSafety
  end

  private

  def find_report(id)
    if current_user.admin?
      Report.find(id)
    else
      current_user.reports.find(id)
    end
  end
end
