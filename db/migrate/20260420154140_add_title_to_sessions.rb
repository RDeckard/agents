# frozen_string_literal: true

class AddTitleToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :title, :string
  end
end
