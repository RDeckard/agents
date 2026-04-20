# frozen_string_literal: true

require "administrate/base_dashboard"

class AttachmentDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    session: Field::BelongsTo.with_options(optional: true),
    user: Field::BelongsTo.with_options(optional: true),
    kind: Field::String,
    anthropic_file_id: Field::String,
    filename: Field::String,
    content_type: Field::String,
    byte_size: Field::Number,
    anthropic_created_at: Field::DateTime,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  COLLECTION_ATTRIBUTES = %i[
    id
    filename
    kind
    user
    session
    created_at
  ].freeze

  SHOW_PAGE_ATTRIBUTES = %i[
    id
    session
    user
    kind
    anthropic_file_id
    filename
    content_type
    byte_size
    anthropic_created_at
    created_at
    updated_at
  ].freeze

  FORM_ATTRIBUTES = %i[
    session
    user
    kind
    anthropic_file_id
    filename
    content_type
  ].freeze

  COLLECTION_FILTERS = {}.freeze

  def display_resource(attachment)
    attachment.filename
  end
end
