# frozen_string_literal: true

require "administrate/base_dashboard"

class SessionDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    title: Field::String,
    anthropic_session_id: Field::String,
    user: Field::BelongsTo.with_options(optional: true),
    attachments: Field::HasMany,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    title
    anthropic_session_id
    user
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    title
    anthropic_session_id
    user
    attachments
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    anthropic_session_id
    user
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(session)
    session.title.presence || "Session ##{session.id}"
  end
end
