# frozen_string_literal: true

class PredictionsController < ApplicationController
  require 'numo/narray'

  MODEL_PATH = Rails.root.join('models', 'car_model.bin')
  SCALER_PATH = Rails.root.join('models', 'scaler.bin')

  def new
    # just render the form
  end

  def predict
    year = params[:year].to_f
    engine_size = params[:engine_size].to_f
    mileage = params[:mileage].to_f

    fuel_type = case params[:fuel_type].to_s.downcase
                when 'petrol' then 0
                when 'diesel' then 1
                when 'electric' then 2
                when 'hybrid' then 3
                else 4
                end

    transmission = params[:transmission].to_s.downcase == 'automatic' ? 1 : 0

    condition = case params[:condition].to_s.downcase
                when 'new' then 2
                when 'like new' then 1
                when 'used' then 0
                else 0
                end

    x = Numo::DFloat[[year, engine_size, mileage, fuel_type, transmission, condition]]
    scaler = Marshal.load(File.read(SCALER_PATH))
    model = Marshal.load(File.read(MODEL_PATH))

    x_scaled = scaler.transform(x)
    @predicted_price = model.predict(x_scaled)[0].round(2)

    render :new
  rescue StandardError => e
    @error = e.message
    render :new
  end
end
