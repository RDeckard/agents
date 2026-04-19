# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let(:admin) { create(:user, :admin) }

  before { login_as(admin) }

  describe "PATCH /admin/users/:id" do
    let(:user) { create(:user) }

    it "updates the password when provided" do
      patch admin_user_path(user), params: {
        user: { password: "newpassword123", password_confirmation: "newpassword123" }
      }
      expect(response).to redirect_to(admin_user_path(user))
      expect(user.reload.valid_password?("newpassword123")).to be true
    end

    it "does not change the password when left blank" do
      original = user.crypted_password
      patch admin_user_path(user), params: {
        user: { email: user.email, password: "", password_confirmation: "" }
      }
      expect(response).to redirect_to(admin_user_path(user))
      expect(user.reload.crypted_password).to eq(original)
    end

    it "updates other attributes without affecting the password" do
      original = user.crypted_password
      patch admin_user_path(user), params: {
        user: { name: "New Name", password: "", password_confirmation: "" }
      }
      expect(user.reload.name).to eq("New Name")
      expect(user.reload.crypted_password).to eq(original)
    end
  end
end
