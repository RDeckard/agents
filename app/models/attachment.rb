# frozen_string_literal: true

class Attachment < ApplicationRecord
  has_one_attached :file

  belongs_to :session, optional: true
  belongs_to :user, optional: true

  validates :anthropic_file_id, uniqueness: true, allow_nil: true
  validates :filename, presence: true
  validates :kind, inclusion: { in: %w[agent_output uploaded_input] }

  scope :outputs, -> { where(kind: "agent_output") }
  scope :inputs, -> { where(kind: "uploaded_input") }
  scope :html, -> { where("filename LIKE '%.html'") }
end
