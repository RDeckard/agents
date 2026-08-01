# frozen_string_literal: true

require "rails_helper"

RSpec.describe Attachment, type: :model do
  it "validates anthropic_file_id uniqueness" do
    create(:attachment, anthropic_file_id: "file_dup")
    duplicate = build(:attachment, anthropic_file_id: "file_dup")
    expect(duplicate).not_to be_valid
  end

  it "allows nil anthropic_file_id" do
    attachment = build(:attachment, :input)
    expect(attachment).to be_valid
  end

  it "requires a session" do
    attachment = build(:attachment, session: nil)
    expect(attachment).not_to be_valid
  end

  it "requires a user" do
    attachment = build(:attachment, user: nil)
    expect(attachment).not_to be_valid
  end

  it "validates kind inclusion" do
    attachment = build(:attachment, kind: "invalid")
    expect(attachment).not_to be_valid
  end

  it "is destroyed when session is destroyed" do
    session_record = create(:session)
    attachment = create(:attachment, session: session_record)

    session_record.destroy!
    expect(described_class.exists?(attachment.id)).to be false
  end

  describe "scopes" do
    it "filters outputs and inputs" do
      output = create(:attachment, :output)
      input = create(:attachment, :input)

      expect(described_class.outputs).to contain_exactly(output)
      expect(described_class.inputs).to contain_exactly(input)
    end

    it "filters html files" do
      html = create(:attachment, filename: "output.html")
      _csv = create(:attachment, filename: "data.csv")

      expect(described_class.html).to contain_exactly(html)
    end
  end
end
