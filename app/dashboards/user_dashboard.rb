# frozen_string_literal: true

require "administrate/base_dashboard"

class UserDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    email: Field::String,
    name: Field::String,
    admin: Field::Boolean,
    password: Field::Password,
    password_confirmation: Field::Password,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    email
    name
    admin
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    email
    name
    admin
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    email
    name
    admin
    password
    password_confirmation
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(user)
    user.name.presence || user.email
  end
end
