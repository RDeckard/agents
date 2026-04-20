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

  it "allows nil session" do
    attachment = build(:attachment, session: nil)
    expect(attachment).to be_valid
  end

  it "allows nil user" do
    attachment = build(:attachment, user: nil)
    expect(attachment).to be_valid
  end

  it "validates kind inclusion" do
    attachment = build(:attachment, kind: "invalid")
    expect(attachment).not_to be_valid
  end

  it "survives session deletion" do
    session_record = create(:session)
    attachment = create(:attachment, session: session_record)

    session_record.destroy!
    attachment.reload

    expect(attachment).to be_persisted
    expect(attachment.session_id).to be_nil
  end

  describe "scopes" do
    it "filters outputs and inputs" do
      output = create(:attachment, :output)
      input = create(:attachment, :input)

      expect(described_class.outputs).to contain_exactly(output)
      expect(described_class.inputs).to contain_exactly(input)
    end

    it "filters html files" do
      html = create(:attachment, filename: "report.html")
      _csv = create(:attachment, filename: "data.csv")

      expect(described_class.html).to contain_exactly(html)
    end
  end
end
