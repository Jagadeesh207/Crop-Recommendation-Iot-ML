import firebase_admin
from firebase_admin import credentials, firestore
from flask import Flask, request, jsonify
from flask_cors import CORS
from tensorflow.keras.models import load_model
import pickle
import pandas as pd
import numpy as np
import requests
import os
import sys # Import sys for flushing output

# --- API KEYS AND CONFIGURATION ---
# Option 1: Open-Meteo (Free - No API Key Needed)
WEATHER_API_PROVIDER = "open_meteo"  # Can switch to "openweather" if preferred

# Option 2: OpenWeatherMap (Requires API Key)
# Sign up free at https://openweathermap.org/api
OPENWEATHER_API_KEY = os.environ.get("OPENWEATHER_API_KEY", "")  # Set as environment variable

# --- 1. Initialize Flask App and Services ---
app = Flask(__name__)
# Enable CORS for development so Flutter web can call this API
CORS(app, resources={r"/*": {"origins": "*"}})

# Load Firebase credentials from a file
# Ensure 'credentials.json' is in the same folder as app.py
try:
    cred = credentials.Certificate("credentials.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase initialized successfully.")
    sys.stdout.flush()
except Exception as e:
    print(f"❌ Error initializing Firebase: {e}", file=sys.stderr)
    sys.stderr.flush()
    # Depending on your setup, you might want to exit if Firebase fails
    # exit()


# --- 2. Load the Saved Models and Preprocessors ---
print("Loading models and preprocessors...")
sys.stdout.flush()
try:
    # Load Keras models
    ann_classifier = load_model('ann_classifier_model.h5')
    ann_regressor = load_model('ann_regressor_model.h5')

    # Load pickle files
    with open('classifier_scaler.pkl', 'rb') as f:
        classifier_scaler = pickle.load(f)
    with open('classifier_columns.pkl', 'rb') as f:
        classifier_columns = pickle.load(f)
    with open('label_encoder.pkl', 'rb') as f:
        label_encoder = pickle.load(f)
    with open('regressor_scaler.pkl', 'rb') as f:
        regressor_scaler = pickle.load(f)
    with open('regressor_columns.pkl', 'rb') as f:
        regressor_columns = pickle.load(f)
    print("✅ Models and preprocessors loaded successfully.")
    sys.stdout.flush()
except FileNotFoundError as e:
    print(f"❌ Error loading model or preprocessor file: {e}", file=sys.stderr)
    print("Ensure all required .h5 and .pkl files are in the C:\\CropProject_Conda folder.", file=sys.stderr)
    sys.stderr.flush()
    exit() # Exit if essential files are missing
except Exception as e:
    print(f"❌ An unexpected error occurred during loading: {e}", file=sys.stderr)
    sys.stderr.flush()
    exit()


# --- 3. API Helper Functions ---
def get_yearly_average_rainfall(latitude, longitude):
    """Fetches yearly average rainfall from Open-Meteo weather API based on coordinates."""
    try:
        lat = float(latitude)
        lon = float(longitude)
    except (ValueError, TypeError):
        print("Warning: Invalid latitude/longitude format received. Using default rainfall 800mm.", file=sys.stderr)
        sys.stderr.flush()
        return 800.0

    try:
        # Use Open-Meteo API for historical climate data (free, no API key required)
        # This API provides precipitation climatology data
        url = f"https://climate-api.open-meteo.com/v1/climate?latitude={lat}&longitude={lon}&hourly=precipitation&start_date=2015-01-01&end_date=2020-12-31"
        
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        
        if 'hourly' in data and 'precipitation' in data['hourly']:
            precipitation_data = data['hourly']['precipitation']
            # Calculate yearly average from the data
            if precipitation_data:
                total_precipitation = sum([p for p in precipitation_data if p is not None])
                num_days = len([p for p in precipitation_data if p is not None]) / 24  # Convert hours to days
                yearly_avg = (total_precipitation / num_days * 365) if num_days > 0 else 800.0
                yearly_avg = round(yearly_avg, 1)
                print(f"Rainfall from API for ({lat}, {lon}): {yearly_avg} mm/year", file=sys.stdout)
                sys.stdout.flush()
                return yearly_avg
        
        print(f"Warning: Could not parse rainfall data from API. Using fallback.", file=sys.stderr)
        sys.stderr.flush()
        return get_fallback_rainfall(lat, lon)
        
    except requests.exceptions.Timeout:
        print(f"Warning: Rainfall API request timed out. Using fallback.", file=sys.stderr)
        sys.stderr.flush()
        return get_fallback_rainfall(lat, lon)
    except Exception as e:
        print(f"Warning: Failed to fetch rainfall from API ({e}). Using fallback.", file=sys.stderr)
        sys.stderr.flush()
        return get_fallback_rainfall(lat, lon)


def get_fallback_rainfall(latitude, longitude):
    """Fallback: Basic rainfall estimation based on latitude and climate zones."""
    try:
        lat = float(latitude)
    except (ValueError, TypeError):
        return 800.0
    
    # Simple climate zone estimation
    if abs(lat) > 60: rainfall = 300.0   # Polar
    elif abs(lat) > 40: rainfall = 750.0  # Temperate
    elif abs(lat) > 20: rainfall = 1200.0 # Subtropical
    else: rainfall = 2000.0              # Tropical
    
    return round(rainfall, 1)


def get_rainfall_from_openweather(latitude, longitude):
    """Fetch rainfall from OpenWeatherMap API (requires API key)."""
    if not OPENWEATHER_API_KEY:
        return None
    
    try:
        url = f"https://api.openweathermap.org/data/2.5/weather?lat={latitude}&lon={longitude}&appid={OPENWEATHER_API_KEY}"
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        
        # OpenWeatherMap returns current rainfall, but for historical avg we use another endpoint
        # For now, we'll use current conditions as proxy
        rainfall = 0
        if 'rain' in data:
            rainfall = data['rain'].get('1h', 0)  # 1-hour rainfall
        
        # This is not ideal for yearly average - consider using their Historical API
        # For better results, use their One Call API with historical data
        print(f"Current rainfall from OpenWeatherMap: {rainfall} mm", file=sys.stdout)
        sys.stdout.flush()
        return rainfall
        
    except Exception as e:
        print(f"Error fetching from OpenWeatherMap: {e}", file=sys.stderr)
        sys.stderr.flush()
        return None


def get_live_data(latitude, longitude):
    """Fetches sensor data from Firebase and estimated rainfall."""
    print(f"--- Fetching data for Lat: {latitude}, Lon: {longitude} ---", file=sys.stdout)
    sys.stdout.flush()
    doc_ref = db.collection('sensor_data').document('latest_readings')
    doc = doc_ref.get()
    if not doc.exists:
        print("Error: Firebase document 'sensor_data/latest_readings' not found!", file=sys.stderr)
        sys.stderr.flush()
        raise Exception("Firebase document 'sensor_data/latest_readings' not found!")
    
    sensor_data = doc.to_dict()
    print(f"Raw Firebase Data: {sensor_data}", file=sys.stdout)
    sys.stdout.flush()

    rainfall = get_yearly_average_rainfall(latitude, longitude)
    print(f"Estimated Rainfall: {rainfall}", file=sys.stdout)
    sys.stdout.flush()
    
    # Prepare the dictionary matching expected feature names from training
    live_data = {
        'N': sensor_data.get('n_value'),
        'P': sensor_data.get('p_value'),
        'K': sensor_data.get('k_value'),
        'Temperature': sensor_data.get('temperature'),
        'Humidity': sensor_data.get('humidity'),
        # Ensure key matches exactly the column name used in training
        'Soil_Moisture (%)': sensor_data.get('soil_moisture'),
        'Rainfall': rainfall
    }
    
    # Data Validation and Type Conversion
    for key in classifier_columns: # Iterate based on expected columns
        value = live_data.get(key)
        if value is None:
             print(f"Warning: Data missing for '{key}'. Using 0.", file=sys.stderr)
             sys.stderr.flush()
             live_data[key] = 0.0 # Use float 0.0 for consistency
        elif not isinstance(value, (int, float)):
             try:
                 # Attempt conversion for string numbers (e.g., from Firestore if saved as string)
                 live_data[key] = float(value)
             except (ValueError, TypeError):
                 print(f"Warning: Non-numeric data for '{key}': {value}. Using 0.0.", file=sys.stderr)
                 sys.stderr.flush()
                 live_data[key] = 0.0
        else:
            # Ensure all are floats for consistency before scaling
            live_data[key] = float(value)

    print(f"Processed Live Data: {live_data}", file=sys.stdout)
    sys.stdout.flush()
    return live_data


# --- 4. API Endpoints ---
@app.route('/')
def index():
    """Provides a welcome message for the API root."""
    return jsonify({
        'status': 'online',
        'message': 'Welcome to the Crop Recommendation & Yield Prediction API!'
    })

@app.route('/recommend_crop', methods=['GET'])
def recommend_crop():
    endpoint_name = '/recommend_crop'
    print(f"\n--- Request received for {endpoint_name} ---", file=sys.stdout)
    sys.stdout.flush()
    try:
        lat = request.args.get('lat')
        lon = request.args.get('lon')
        if not lat or not lon:
            print(f"Error ({endpoint_name}): Missing lat/lon parameters.", file=sys.stderr)
            sys.stderr.flush()
            return jsonify({'error': 'Query parameters "lat" and "lon" are required.'}), 400

        live_data = get_live_data(lat, lon)
        input_df = pd.DataFrame([live_data])
        
        # Ensure columns are in the correct order saved during training
        try:
            input_df = input_df[classifier_columns]
        except KeyError as e:
             print(f"Error ({endpoint_name}): Column mismatch before scaling. Missing: {e}. DataFrame columns: {input_df.columns}", file=sys.stderr)
             sys.stderr.flush()
             return jsonify({'error': f'Internal server error: Input data mismatch ({e})'}), 500
        
        print(f"DF before scaling ({endpoint_name}): \n{input_df.to_string()}", file=sys.stdout)
        sys.stdout.flush()
        
        input_scaled = classifier_scaler.transform(input_df)
        
        print(f"Scaled input ({endpoint_name}): {input_scaled}", file=sys.stdout)
        sys.stdout.flush()
        
        # Predict using Keras (add error handling around predict)
        try:
            prediction_probs = ann_classifier.predict(input_scaled)
        except Exception as pred_e:
            print(f"Error ({endpoint_name}): Keras prediction failed: {pred_e}", file=sys.stderr)
            sys.stderr.flush()
            return jsonify({'error': 'Prediction model failed.'}), 500

        class_index = np.argmax(prediction_probs, axis=1)[0]
        
        # Decode using LabelEncoder (add error handling)
        try:
            predicted_crop = label_encoder.inverse_transform([class_index])[0]
        except Exception as enc_e:
             print(f"Error ({endpoint_name}): Label decoding failed for index {class_index}: {enc_e}", file=sys.stderr)
             sys.stderr.flush()
             return jsonify({'error': 'Could not decode prediction.'}), 500
        
        print(f"Prediction ({endpoint_name}): {predicted_crop}", file=sys.stdout)
        sys.stdout.flush()
        
        return jsonify({'recommended_crop': predicted_crop})

    except Exception as e:
        print(f"Unexpected Error in {endpoint_name}: {e}", file=sys.stderr)
        sys.stderr.flush()
        return jsonify({'error': f'An unexpected server error occurred: {e}'}), 500


@app.route('/recommend_crop_with_features', methods=['GET'])
def recommend_crop_with_features():
    endpoint_name = '/recommend_crop_with_features'
    print(f"\n--- Request received for {endpoint_name} ---", file=sys.stdout)
    sys.stdout.flush()
    try:
        lat = request.args.get('lat')
        lon = request.args.get('lon')
        if not lat or not lon:
            print(f"Error ({endpoint_name}): Missing lat/lon parameters.", file=sys.stderr)
            sys.stderr.flush()
            return jsonify({'error': 'Query parameters "lat" and "lon" are required.'}), 400

        live_data = get_live_data(lat, lon)
        input_df = pd.DataFrame([live_data])

        try:
            input_df = input_df[classifier_columns] # Enforce column order
        except KeyError as e:
             print(f"Error ({endpoint_name}): Column mismatch before scaling. Missing: {e}.", file=sys.stderr)
             sys.stderr.flush()
             return jsonify({'error': f'Internal server error: Input data mismatch ({e})'}), 500

        print(f"DF before scaling ({endpoint_name}): \n{input_df.to_string()}", file=sys.stdout)
        sys.stdout.flush()
        
        input_scaled = classifier_scaler.transform(input_df)
        
        print(f"Scaled input ({endpoint_name}): {input_scaled}", file=sys.stdout)
        sys.stdout.flush()
        
        try:
            prediction_probs = ann_classifier.predict(input_scaled)
        except Exception as pred_e:
            print(f"Error ({endpoint_name}): Keras prediction failed: {pred_e}", file=sys.stderr)
            sys.stderr.flush()
            return jsonify({'error': 'Prediction model failed.'}), 500

        class_index = np.argmax(prediction_probs, axis=1)[0]
        
        try:
            predicted_crop = label_encoder.inverse_transform([class_index])[0]
        except Exception as enc_e:
             print(f"Error ({endpoint_name}): Label decoding failed for index {class_index}: {enc_e}", file=sys.stderr)
             sys.stderr.flush()
             return jsonify({'error': 'Could not decode prediction.'}), 500
        
        print(f"Prediction ({endpoint_name}): {predicted_crop}", file=sys.stdout)
        sys.stdout.flush()
        
        return jsonify({
            'recommended_crop': predicted_crop,
            'features': live_data
        })

    except Exception as e:
        print(f"Unexpected Error in {endpoint_name}: {e}", file=sys.stderr)
        sys.stderr.flush()
        return jsonify({'error': f'An unexpected server error occurred: {e}'}), 500


@app.route('/predict_yield', methods=['GET'])
def predict_yield():
    endpoint_name = '/predict_yield'
    print(f"\n--- Request received for {endpoint_name} ---", file=sys.stdout)
    sys.stdout.flush()
    try:
        crop_name = request.args.get('crop')
        lat = request.args.get('lat')
        lon = request.args.get('lon')
        if not all([crop_name, lat, lon]):
            print(f"Error ({endpoint_name}): Missing crop/lat/lon parameters.", file=sys.stderr)
            sys.stderr.flush()
            return jsonify({'error': 'Query parameters "crop", "lat", and "lon" are required.'}), 400

        live_data = get_live_data(lat, lon)
        
        # Prepare the dataframe with one-hot encoding, using saved columns
        input_df = pd.DataFrame(columns=regressor_columns)
        input_df.loc[0] = 0.0 # Initialize a row of float zeros
        
        # Fill in the live data values
        for key, value in live_data.items():
             # Check both exact match and handle the specific soil moisture case if needed
             if key in input_df.columns:
                input_df.at[0, key] = float(value) # Ensure float type
             elif key == 'Soil_Moisture (%)' and 'Soil_Moisture (%)' in input_df.columns:
                 input_df.at[0, 'Soil_Moisture (%)'] = float(value) # Ensure float type

        # Find and set the correct one-hot encoded crop column, ignoring case
        target_column_lower = f"crop_{crop_name}".lower()
        actual_column_name = None
        for col in regressor_columns:
            if col.lower() == target_column_lower:
                actual_column_name = col
                break
        
        if actual_column_name:
            input_df.at[0, actual_column_name] = 1.0 # Set the one-hot flag to 1.0
        else:
             # Check if the crop name is valid according to the label encoder
             if crop_name not in label_encoder.classes_:
                 print(f"Error ({endpoint_name}): Invalid crop name provided: {crop_name}", file=sys.stderr)
                 sys.stderr.flush()
                 return jsonify({'error': f'Invalid or unsupported crop name provided: {crop_name}'}), 400
             else:
                 # Crop name is valid, but column name wasn't found - indicates inconsistency
                 print(f"Error ({endpoint_name}): Column mismatch for crop '{crop_name}'. Expected column like '{target_column_lower}' not in {regressor_columns}", file=sys.stderr)
                 sys.stderr.flush()
                 return jsonify({'error': f'Internal configuration error processing crop: {crop_name}'}), 500

        # Ensure no NaN values remain AFTER filling live data and one-hot encoding
        input_df.fillna(0.0, inplace=True)

        print(f"DF before scaling ({endpoint_name}): \n{input_df.to_string()}", file=sys.stdout)
        sys.stdout.flush()
            
        input_scaled = regressor_scaler.transform(input_df)

        print(f"Scaled input ({endpoint_name}): {input_scaled}", file=sys.stdout)
        sys.stdout.flush()
        
        try:
            prediction = ann_regressor.predict(input_scaled)[0][0]
        except Exception as pred_e:
            print(f"Error ({endpoint_name}): Keras prediction failed: {pred_e}", file=sys.stderr)
            sys.stderr.flush()
            return jsonify({'error': 'Prediction model failed.'}), 500

        print(f"Prediction ({endpoint_name}): {prediction}", file=sys.stdout)
        sys.stdout.flush()

        # Ensure prediction is a standard Python float before returning JSON
        final_prediction = round(float(prediction), 2)

        return jsonify({'predicted_yield': final_prediction, 'unit': 'kg/ha'})

    except Exception as e:
        print(f"Unexpected Error in {endpoint_name}: {e}", file=sys.stderr)
        sys.stderr.flush()
        return jsonify({'error': f'An unexpected server error occurred: {e}'}), 500


@app.route('/predict_yield_with_features', methods=['GET'])
def predict_yield_with_features():
    endpoint_name = '/predict_yield_with_features'
    print(f"\n--- Request received for {endpoint_name} ---", file=sys.stdout)
    sys.stdout.flush()
    try:
        crop_name = request.args.get('crop')
        lat = request.args.get('lat')
        lon = request.args.get('lon')
        if not all([crop_name, lat, lon]):
            print(f"Error ({endpoint_name}): Missing crop/lat/lon parameters.", file=sys.stderr)
            sys.stderr.flush()
            return jsonify({'error': 'Query parameters "crop", "lat", and "lon" are required.'}), 400

        live_data = get_live_data(lat, lon)
        
        input_df = pd.DataFrame(columns=regressor_columns)
        input_df.loc[0] = 0.0
        
        for key, value in live_data.items():
             if key in input_df.columns:
                input_df.at[0, key] = float(value)
             elif key == 'Soil_Moisture (%)' and 'Soil_Moisture (%)' in input_df.columns:
                 input_df.at[0, 'Soil_Moisture (%)'] = float(value)
        
        target_column_lower = f"crop_{crop_name}".lower()
        actual_column_name = None
        for col in regressor_columns:
            if col.lower() == target_column_lower:
                actual_column_name = col
                break
        
        if actual_column_name:
            input_df.at[0, actual_column_name] = 1.0
        else:
             if crop_name not in label_encoder.classes_:
                 print(f"Error ({endpoint_name}): Invalid crop name provided: {crop_name}", file=sys.stderr)
                 sys.stderr.flush()
                 return jsonify({'error': f'Invalid or unsupported crop name provided: {crop_name}'}), 400
             else:
                 print(f"Error ({endpoint_name}): Column mismatch for crop '{crop_name}'.", file=sys.stderr)
                 sys.stderr.flush()
                 return jsonify({'error': f'Internal config error for crop: {crop_name}'}), 500

        input_df.fillna(0.0, inplace=True)
        
        print(f"DF before scaling ({endpoint_name}): \n{input_df.to_string()}", file=sys.stdout)
        sys.stdout.flush()
            
        input_scaled = regressor_scaler.transform(input_df)

        print(f"Scaled input ({endpoint_name}): {input_scaled}", file=sys.stdout)
        sys.stdout.flush()
        
        try:
            prediction = ann_regressor.predict(input_scaled)[0][0]
        except Exception as pred_e:
            print(f"Error ({endpoint_name}): Keras prediction failed: {pred_e}", file=sys.stderr)
            sys.stderr.flush()
            return jsonify({'error': 'Prediction model failed.'}), 500

        print(f"Prediction ({endpoint_name}): {prediction}", file=sys.stdout)
        sys.stdout.flush()

        final_prediction = round(float(prediction), 2)

        return jsonify({
            'predicted_yield': final_prediction,
            'unit': 'kg/ha',
            'features': live_data
        })

    except Exception as e:
        print(f"Unexpected Error in {endpoint_name}: {e}", file=sys.stderr)
        sys.stderr.flush()
        return jsonify({'error': f'An unexpected server error occurred: {e}'}), 500


# --- 5. Run the App ---
if __name__ == '__main__':
    # Determine port for local vs Cloud Run
    port = int(os.environ.get("PORT", 5000)) # Default to 5000 for local dev
    is_production = os.environ.get('K_SERVICE') is not None # Check if running on Cloud Run

    # In production (Cloud Run), Gunicorn is started by the Dockerfile CMD.
    # Locally, we use Flask's development server.
    if not is_production:
        print(f"Starting Flask development server on http://0.0.0.0:{port} ...")
        sys.stdout.flush()
        # Set debug=True for local development for auto-reloading and better error pages
        app.run(host='0.0.0.0', port=port, debug=True)
    # else:
    #     print("Detected production environment (Cloud Run). Gunicorn should be starting the app.")
    #     sys.stdout.flush()
    #     # Gunicorn is executed via the Dockerfile CMD:
    #     # CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 app:app

