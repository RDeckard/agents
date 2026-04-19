# frozen_string_literal: true

FactoryBot.define do
  factory :session do
    sequence(:anthropic_session_id) { |n| "sesn_test#{n}" }
    user
  end
end
