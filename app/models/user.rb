# frozen_string_literal: true

class User < ApplicationRecord
  authenticates_with_sorcery!

  validates :email, presence: true, uniqueness: true
  validates :password, length: { minimum: 8 }, if: -> { new_record? || changes[:crypted_password] }
  validates :password, confirmation: true, if: -> { new_record? || changes[:crypted_password] }

  has_many :sessions, dependent: :nullify
  has_many :attachments, dependent: :nullify

  def admin?
    admin
  end
end
