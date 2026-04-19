# frozen_string_literal: true

require "administrate/base_dashboard"

class ReportDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    session: Field::BelongsTo.with_options(optional: true),
    user: Field::BelongsTo.with_options(optional: true),
    anthropic_file_id: Field::String,
    filename: Field::String,
    content: Field::Text,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    filename
    user
    session
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    session
    user
    anthropic_file_id
    filename
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    session
    user
    anthropic_file_id
    filename
    content
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(report)
    report.filename
  end
end
