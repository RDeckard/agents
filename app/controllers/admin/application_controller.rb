# frozen_string_literal: true

module Admin
  class ApplicationController < Administrate::ApplicationController
    before_action :require_login
    before_action :require_admin

    private

    def require_admin
      return if current_user&.admin?

      redirect_to root_path, alert: "Not authorized"
    end

    def not_authenticated
      redirect_to login_path
    end
  end
end
