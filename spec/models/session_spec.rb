# frozen_string_literal: true

require "rails_helper"

RSpec.describe Session, type: :model do
  it "allows nil user" do
    session = described_class.create!(anthropic_session_id: "sesn_orphan", user: nil)
    expect(session).to be_persisted
  end

  it "allows nil anthropic_session_id" do
    session = described_class.create!(anthropic_session_id: nil, user: create(:user))
    expect(session).to be_persisted
  end

  it "allows duplicate anthropic_session_ids" do
    user = create(:user)
    described_class.create!(anthropic_session_id: "sesn_dup", user: user)
    dup = described_class.create!(anthropic_session_id: "sesn_dup", user: nil)
    expect(dup).to be_persisted
  end

  it "scopes to user via association" do
    user = create(:user)
    other = create(:user)
    mine = create(:session, user: user)
    create(:session, user: other)

    expect(user.sessions).to eq([mine])
  end

  it "has many attachments" do
    session = create(:session)
    create(:attachment, session: session, user: session.user)
    create(:attachment, session: session, user: session.user)

    expect(session.attachments.count).to eq(2)
  end

  it "nullifies attachments on destroy" do
    session = create(:session)
    attachment = create(:attachment, session: session, user: session.user)

    session.destroy!
    expect(attachment.reload.session_id).to be_nil
  end
end
