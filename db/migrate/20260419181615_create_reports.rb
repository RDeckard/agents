# frozen_string_literal: true

class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.references :session, null: false, foreign_key: true
      t.string :anthropic_file_id
      t.string :filename
      t.text :content

      t.timestamps
    end
    add_index :reports, :anthropic_file_id, unique: true
  end
end
