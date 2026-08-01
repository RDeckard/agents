# frozen_string_literal: true

module Admin
  class UsersController < Admin::ApplicationController
    def resource_params
      # params.expect(key => [attrs]) wraps the already-array permitted_attributes
      # in a second array, triggering the "array of hashes" form that expects
      # params[:user] to be an array. Administrate swallows the resulting
      # ParameterMissing silently — password is never assigned on update.
      permitted = params
                  .require(resource_class.model_name.param_key) # rubocop:disable Rails/StrongParametersExpect
                  .permit(dashboard.permitted_attributes(action_name))

      if action_name.in?(%w[update]) && permitted[:password].blank?
        permitted.except(:password, :password_confirmation)
      else
        permitted
      end
    end
  end
end
