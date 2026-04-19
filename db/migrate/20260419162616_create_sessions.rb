# frozen_string_literal: true

class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.string :anthropic_session_id
      t.string :agent_id
      t.string :agent_name
      t.string :title
      t.string :status

      t.timestamps
    end
  end
end
