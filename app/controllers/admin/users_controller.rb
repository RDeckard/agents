# frozen_string_literal: true

module Admin
  class UsersController < Admin::ApplicationController
    def resource_params
      permitted = params
                  .expect(resource_class.model_name.param_key => [dashboard.permitted_attributes(action_name)])

      if action_name.in?(%w[update]) && permitted[:password].blank?
        permitted.except(:password, :password_confirmation)
      else
        permitted
      end
    end
  end
end
