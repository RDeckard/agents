# frozen_string_literal: true

class MigrateAttachmentContentToActiveStorage < ActiveRecord::Migration[8.1]
  def up
    Attachment.where.not(content: nil).find_each do |attachment|
      next if attachment.file.attached?

      ct = attachment.content_type || Rack::Mime.mime_type(File.extname(attachment.filename), "text/html")
      attachment.file.attach(
        io: StringIO.new(attachment.content),
        filename: attachment.filename,
        content_type: ct
      )
    end

    remove_column :attachments, :content
  end

  def down
    add_column :attachments, :content, :text

    Attachment.find_each do |attachment|
      next unless attachment.file.attached?

      attachment.update_column(:content, attachment.file.download) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
