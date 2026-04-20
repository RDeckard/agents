# frozen_string_literal: true

class AttachmentsController < ApplicationController
  def index
    @attachments = current_user.attachments.includes(:session).order(created_at: :desc)

    @attachments = @attachments.where(kind: params[:kind]) if params[:kind].present?
  end

  def show
    attachment = find_attachment(params[:id])

    if attachment.file.attached?
      redirect_to rails_blob_path(attachment.file, disposition: :inline), allow_other_host: true
    else
      render plain: "File not available.", status: :not_found
    end
  end

  private

  def find_attachment(id)
    if current_user.admin?
      Attachment.find(id)
    else
      current_user.attachments.find(id)
    end
  end
end
