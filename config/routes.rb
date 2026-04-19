# frozen_string_literal: true

Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "login", to: "user_sessions#new", as: :login
  post "login", to: "user_sessions#create"
  delete "logout", to: "user_sessions#destroy", as: :logout

  namespace :admin do
    resources :users
    resources :sessions
    resources :reports

    root to: "users#index"
  end

  root "agents#index"

  resources :agents, only: %i[index show] do
    resources :sessions, only: [:create]
  end

  resources :sessions, only: %i[index show] do
    member do
      post :message
      get :events
      get :report
    end
  end

  resources :reports, only: %i[index show]
end
