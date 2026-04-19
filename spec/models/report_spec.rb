# frozen_string_literal: true

require "rails_helper"

RSpec.describe Report, type: :model do
  it "validates anthropic_file_id uniqueness" do
    create(:report, anthropic_file_id: "file_dup")
    duplicate = build(:report, anthropic_file_id: "file_dup")
    expect(duplicate).not_to be_valid
  end

  it "allows nil session" do
    report = build(:report, session: nil)
    expect(report).to be_valid
  end

  it "allows nil user" do
    report = build(:report, user: nil)
    expect(report).to be_valid
  end

  it "survives session deletion" do
    session_record = create(:session)
    report = create(:report, session: session_record)

    session_record.destroy!
    report.reload

    expect(report).to be_persisted
    expect(report.session_id).to be_nil
  end
end
