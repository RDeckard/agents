# frozen_string_literal: true

class EnforceUserIdAndAddAgentName < ActiveRecord::Migration[8.1]
  def up
    Attachment.where(user_id: nil).or(Attachment.where(session_id: nil)).delete_all
    Session.where(user_id: nil).delete_all

    change_column_null :sessions, :user_id, false

    change_table :attachments, bulk: true do |t|
      t.change_null :user_id, false
      t.change_null :session_id, false
    end

    add_column :sessions, :agent_name, :string
  end

  def down
    change_column_null :sessions, :user_id, true

    change_table :attachments, bulk: true do |t|
      t.change_null :user_id, true
      t.change_null :session_id, true
    end

    remove_column :sessions, :agent_name
  end
end
