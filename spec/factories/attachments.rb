# frozen_string_literal: true

FactoryBot.define do
  factory :attachment do
    session
    user { session&.user }
    sequence(:anthropic_file_id) { |n| "file_#{n}" }
    filename { "output.html" }
    kind { "agent_output" }

    after(:build) do |attachment|
      attachment.file.attach(
        io: StringIO.new("<html><body><h1>Output</h1></body></html>"),
        filename: attachment.filename,
        content_type: "text/html"
      )
    end

    trait :output do
      kind { "agent_output" }
      filename { "output.html" }
    end

    trait :input do
      kind { "uploaded_input" }
      filename { "data.csv" }
      anthropic_file_id { nil }

      after(:build) do |attachment|
        attachment.file.attach(
          io: StringIO.new("col1,col2\na,b"),
          filename: attachment.filename,
          content_type: "text/csv"
        )
      end
    end
  end
end
