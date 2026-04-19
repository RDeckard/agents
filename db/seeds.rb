# frozen_string_literal: true

if User.none?
  User.create!(
    email: "gabriel@agents.com",
    name: "Gabriel",
    password: "password",
    password_confirmation: "password",
    admin: true
  )
  Rails.logger.debug "Created default admin user: admin@example.com / password"
end
