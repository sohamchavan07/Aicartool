# frozen_string_literal: true

require 'singleton'
require 'numo/narray'
require 'json'
require 'time'

class CarPriceEstimator
  include Singleton

  MODEL_PATH = Rails.root.join('models', 'rf_model.bin').freeze
  SCALER_PATH = Rails.root.join('models', 'scaler.bin').freeze
  METADATA_PATH = Rails.root.join('models', 'metadata.json').freeze

  class MissingArtifactError < StandardError; end

  def predict(payload)
    ensure_artifacts!

    features = build_feature_vector(payload)
    scaled = scaler.transform(Numo::DFloat[features])
    prediction = model.predict(scaled)
    prediction[0].to_f
  end

  private

  def ensure_artifacts!
    missing = []
    missing << MODEL_PATH unless File.exist?(MODEL_PATH)
    missing << SCALER_PATH unless File.exist?(SCALER_PATH)
    missing << METADATA_PATH unless File.exist?(METADATA_PATH)
    raise MissingArtifactError, "Missing artifact(s): #{missing.join(', ')}" if missing.any?
  end

  def model
    @model ||= Marshal.load(File.binread(MODEL_PATH))
  end

  def scaler
    @scaler ||= Marshal.load(File.binread(SCALER_PATH))
  end

  def metadata
    @metadata ||= JSON.parse(File.read(METADATA_PATH))
  end

  def defaults
    metadata.fetch('defaults', {})
  end

  def encoders
    metadata.fetch('encoders')
  end

  def conditioned_value(raw)
    key = raw.to_s.strip.downcase
    case key
    when 'new', 'excellent'
      2.0
    when 'like new'
      1.0
    when 'used', 'good', 'fair'
      0.0
    else
      0.0
    end
  end

  def lookup_index(map, raw)
    key = raw.to_s.strip.downcase
    key = 'unknown' if key.empty?
    return map[key] if map.key?(key)

    map['unknown'] || 0
  end

  def build_feature_vector(payload)
    year = fetch_numeric(payload, :year)
    mileage = fetch_numeric(payload, :mileage)
    engine_size = fetch_numeric(payload, :engine_size, required: false, default: defaults['engine_size'])
    condition = conditioned_value(payload[:condition])

    brand_idx = lookup_index(encoders.fetch('brand'), payload[:brand])
    fuel_idx = lookup_index(encoders.fetch('fuel_type'), payload[:fuel_type])
    transmission_idx = lookup_index(encoders.fetch('transmission'), payload[:transmission])
    model_idx = lookup_index(encoders.fetch('model'), payload[:model])

    [
      year,
      mileage,
      engine_size,
      condition,
      brand_idx.to_f,
      fuel_idx.to_f,
      transmission_idx.to_f,
      model_idx.to_f
    ]
  end

  def fetch_numeric(payload, key, required: true, default: nil)
    value = payload[key]
    value = nil if value.respond_to?(:strip) && value.strip.empty?

    return Float(value) unless value.nil?
    return Float(default) unless default.nil?

    raise ArgumentError, "Missing required numeric field: #{key}" if required

    nil
  rescue ArgumentError, TypeError
    raise ArgumentError, "Invalid numeric value for #{key}: #{value.inspect || default.inspect}"
  end
end
