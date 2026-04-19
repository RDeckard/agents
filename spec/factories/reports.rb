# frozen_string_literal: true

FactoryBot.define do
  factory :report do
    session
    user { session&.user }
    sequence(:anthropic_file_id) { |n| "file_#{n}" }
    filename { "report.html" }
    content { "<html><body><h1>Report</h1></body></html>" }
  end
end
