# frozen_string_literal: true

class Report < ApplicationRecord
  belongs_to :session, optional: true
  belongs_to :user, optional: true

  validates :anthropic_file_id, presence: true, uniqueness: true
  validates :filename, presence: true
  validates :content, presence: true
end
