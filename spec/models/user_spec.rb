# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  it "has many sessions" do
    user = create(:user)
    session = create(:session, user: user)
    expect(user.sessions).to include(session)
  end

  it "has many attachments" do
    user = create(:user)
    attachment = create(:attachment, user: user)
    expect(user.attachments).to include(attachment)
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

  it "destroys sessions on destroy" do
    user = create(:user)
    session = create(:session, user: user)
    user.destroy!
    expect(Session.exists?(session.id)).to be false
  end
end
