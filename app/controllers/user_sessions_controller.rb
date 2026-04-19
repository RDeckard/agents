# frozen_string_literal: true

class UserSessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    if (@user = login(params[:email], params[:password]))
      redirect_to_before_login_path(root_path)
    else
      flash.now[:alert] = "Invalid email or password" # rubocop:disable Rails/I18nLocaleTexts
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    logout
    redirect_to login_path, status: :see_other
  end
end
