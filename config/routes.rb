# frozen_string_literal: true

Rails.application.routes.draw do
  root 'predictions#new'
  post '/predict', to: 'predictions#predict'
end
