# frozen_string_literal: true

class RenameReportsToAttachments < ActiveRecord::Migration[8.1]
  def change
    rename_table :reports, :attachments

    change_table :attachments, bulk: true do |t|
      t.string :kind, null: false, default: "agent_output"
      t.string :content_type
      t.datetime :anthropic_created_at
      t.integer :byte_size
    end
  end
end
