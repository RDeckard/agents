# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  it "has many sessions" do
    user = create(:user)
    session = create(:session, user: user)
    expect(user.sessions).to include(session)
  end

  it "has many reports" do
    user = create(:user)
    report = create(:report, user: user)
    expect(user.reports).to include(report)
  end

  it "validates email uniqueness" do
    create(:user, email: "taken@example.com")
    duplicate = build(:user, email: "taken@example.com")
    expect(duplicate).not_to be_valid
  end

  it "validates password length on creation" do
    user = build(:user, password: "short", password_confirmation: "short")
    expect(user).not_to be_valid
  end

  it "defaults admin to false" do
    expect(create(:user)).not_to be_admin
  end

  it "nullifies sessions on destroy" do
    user = create(:user)
    session = create(:session, user: user)
    user.destroy!
    expect(session.reload.user_id).to be_nil
  end
end
