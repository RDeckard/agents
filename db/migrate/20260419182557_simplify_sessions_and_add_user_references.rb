# frozen_string_literal: true

class SimplifySessionsAndAddUserReferences < ActiveRecord::Migration[8.1]
  def change
    change_table :sessions, bulk: true do |t|
      t.remove :agent_id, type: :string
      t.remove :agent_name, type: :string
      t.remove :title, type: :string
      t.remove :status, type: :string
      t.references :user, null: true, foreign_key: true
    end

    add_reference :reports, :user, null: true, foreign_key: true
    change_column_null :reports, :session_id, true
  end
end
