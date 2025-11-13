# frozen_string_literal: true

# scripts/train.rb
require 'csv'
require 'numo/narray'
require 'rumale'

DATA_PATH = 'data/car_prices.csv'
MODEL_DIR = 'models'
Dir.mkdir(MODEL_DIR) unless Dir.exist?(MODEL_DIR)

# === Load Data ===
data = CSV.read(DATA_PATH, headers: true)

features = []
targets = []

data.each do |row|
  year = row['Year'].to_f
  engine_size = row['Engine Size'].to_f
  mileage = row['Mileage'].to_f

  # Encode fuel type
  fuel_type = case row['Fuel Type'].downcase
              when 'petrol' then 0
              when 'diesel' then 1
              when 'electric' then 2
              when 'hybrid' then 3
              else 4
              end

  # Encode transmission
  transmission = row['Transmission'].downcase == 'automatic' ? 1 : 0

  # Encode condition
  condition = case row['Condition'].downcase
              when 'new' then 2
              when 'like new' then 1
              when 'used' then 0
              else 0
              end

  price = row['Price'].to_f

  features << [year, engine_size, mileage, fuel_type, transmission, condition]
  targets << price
rescue StandardError
  next
end

x = Numo::DFloat[*features]
y = Numo::DFloat[*targets]

# === Train/Test Split ===
n_samples = x.shape[0]
idx = (0...n_samples).to_a.shuffle(random: Random.new(42))
train_size = (n_samples * 0.8).to_i
train_idx = idx[0...train_size]
test_idx  = idx[train_size..]

x_train = x[train_idx, true]
x_test = x[test_idx, true]
y_train = y[train_idx]
y_test = y[test_idx]

# === Scale ===
scaler = Rumale::Preprocessing::StandardScaler.new
x_train_scaled = scaler.fit_transform(x_train)
x_test_scaled = scaler.transform(x_test)

# === Model ===
model = Rumale::Ensemble::RandomForestRegressor.new(n_estimators: 100, max_depth: 10, random_seed: 1)
model.fit(x_train_scaled, y_train)

# === Evaluate ===
pred = model.predict(x_test_scaled)
mean_y = y_test.mean
r2 = 1 - ((y_test - pred)**2).sum / ((y_test - mean_y)**2).sum
puts "Model R² Score: #{r2.round(3)}"

# === Save Model ===
File.open("#{MODEL_DIR}/car_model.bin", 'wb') { |f| f.write(Marshal.dump(model)) }
File.open("#{MODEL_DIR}/scaler.bin", 'wb') { |f| f.write(Marshal.dump(scaler)) }

puts "✅ Model and scaler saved in #{MODEL_DIR}/"
