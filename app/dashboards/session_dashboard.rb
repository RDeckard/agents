# frozen_string_literal: true

require "administrate/base_dashboard"

class SessionDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    anthropic_session_id: Field::String,
    user: Field::BelongsTo.with_options(optional: true),
    reports: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    anthropic_session_id
    user
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    anthropic_session_id
    user
    reports
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    anthropic_session_id
    user
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(session)
    "Session ##{session.id}"
  end
end
