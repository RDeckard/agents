# frozen_string_literal: true

class Session < ApplicationRecord
  belongs_to :user, optional: true
  has_many :reports, dependent: :nullify
end
