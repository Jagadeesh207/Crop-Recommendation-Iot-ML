import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
import lightgbm as lgb
from sklearn.metrics import accuracy_score, r2_score
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense, Dropout
from tensorflow.keras.utils import to_categorical
import pickle
import warnings

warnings.filterwarnings('ignore')

# --- 1. Load and Prepare Data ---
df = pd.read_csv('Epics.csv')
print("✅ Dataset loaded successfully.")

# --- Prepare data for Classification ---
X_crop = df[['N', 'P', 'K', 'Temperature', 'Humidity', 'Rainfall', 'Soil_Moisture (%)']]
y_crop_labels = df['Label']

# Split data with original labels for RF and LGBM
X_crop_train, X_crop_test, y_crop_train_labels, y_crop_test_labels = train_test_split(
    X_crop, y_crop_labels, test_size=0.2, random_state=42, stratify=y_crop_labels)

# --- Prepare data for Regression ---
df_yield = pd.get_dummies(df, columns=['Label'], prefix='crop')
y_yield = df_yield['Yield (kg/ha)']
X_yield = df_yield.drop('Yield (kg/ha)', axis=1)
X_yield_train, X_yield_test, y_yield_train, y_yield_test = train_test_split(
    X_yield, y_yield, test_size=0.2, random_state=42)

# --- Scale features for ANNs ---
scaler_clf = StandardScaler().fit(X_crop_train)
X_crop_train_scaled = scaler_clf.transform(X_crop_train)
X_crop_test_scaled = scaler_clf.transform(X_crop_test)

scaler_reg = StandardScaler().fit(X_yield_train)
X_yield_train_scaled = scaler_reg.transform(X_yield_train)
X_yield_test_scaled = scaler_reg.transform(X_yield_test)


# --- 2. Train All Models ---
print("⏳ Training all six models...")

# a) Classification models
rf_clf = RandomForestClassifier(random_state=42).fit(X_crop_train, y_crop_train_labels)
lgb_clf = lgb.LGBMClassifier(random_state=42).fit(X_crop_train, y_crop_train_labels)

# For Keras, encode labels to one-hot format
label_encoder = LabelEncoder().fit(y_crop_labels)
y_crop_train_encoded = to_categorical(label_encoder.transform(y_crop_train_labels))
y_crop_test_encoded = to_categorical(label_encoder.transform(y_crop_test_labels))

ann_classifier = Sequential([
    Dense(128, activation='relu', input_shape=(X_crop_train_scaled.shape[1],)),
    Dropout(0.3),
    Dense(64, activation='relu'),
    Dropout(0.3),
    Dense(y_crop_train_encoded.shape[1], activation='softmax')
])
ann_classifier.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])
ann_classifier.fit(X_crop_train_scaled, y_crop_train_encoded, epochs=100, batch_size=32, verbose=0)

# b) Regression models
rf_reg = RandomForestRegressor(random_state=42).fit(X_yield_train, y_yield_train)
lgb_reg = lgb.LGBMRegressor(random_state=42).fit(X_yield_train, y_yield_train)

ann_regressor = Sequential([
    Dense(128, activation='relu', input_shape=(X_yield_train_scaled.shape[1],)),
    Dropout(0.3),
    Dense(64, activation='relu'),
    Dropout(0.3),
    Dense(1)
])
ann_regressor.compile(optimizer='adam', loss='mean_squared_error')
ann_regressor.fit(X_yield_train_scaled, y_yield_train, epochs=100, batch_size=32, verbose=0)

print("✅ All models trained.")


# --- 3. Final Evaluation ---
print("\n" + "="*50)
print("              FINAL MODEL EVALUATION")
print("="*50)

# --- 📊 Classification Accuracy Scores ---
print("\n--- Crop Recommendation (Accuracy) ---")
print(f"* Random Forest: {accuracy_score(y_crop_test_labels, rf_clf.predict(X_crop_test)):.4f}")
print(f"* LightGBM:      {accuracy_score(y_crop_test_labels, lgb_clf.predict(X_crop_test)):.4f}")
# For Keras, get the class with the highest probability
y_pred_keras_clf = np.argmax(ann_classifier.predict(X_crop_test_scaled), axis=1)
y_true_keras_clf = np.argmax(y_crop_test_encoded, axis=1)
print(f"* Keras ANN:     {accuracy_score(y_true_keras_clf, y_pred_keras_clf):.4f}")

# --- 📈 Regression R² Scores ---
print("\n--- Yield Prediction (R² Score) ---")
print(f"* Random Forest: {r2_score(y_yield_test, rf_reg.predict(X_yield_test)):.4f}")
print(f"* LightGBM:      {r2_score(y_yield_test, lgb_reg.predict(X_yield_test)):.4f}")
print(f"* Keras ANN:     {r2_score(y_yield_test, ann_regressor.predict(X_yield_test_scaled)):.4f}")
print("\n" + "="*50)


# --- 4. Save Final Keras Models and Preprocessors ---
print("\n💾 Saving final Keras models and preprocessors for deployment...")

# --- Save Keras models as .h5 files ---
ann_classifier.save('ann_classifier_model.h5')
ann_regressor.save('ann_regressor_model.h5')
print("✅ Models saved as .h5 files.")

# --- Save the scalers and encoders using pickle ---
with open('classifier_scaler.pkl', 'wb') as f:
    pickle.dump(scaler_clf, f)
with open('label_encoder.pkl', 'wb') as f:
    pickle.dump(label_encoder, f)
# ADDITION: Save the classifier columns
with open('classifier_columns.pkl', 'wb') as f:
    pickle.dump(list(X_crop.columns), f)


with open('regressor_scaler.pkl', 'wb') as f:
    pickle.dump(scaler_reg, f)
with open('regressor_columns.pkl', 'wb') as f:
    pickle.dump(list(X_yield.columns), f)

print("✅ Scalers, encoder, and column lists saved as .pkl files.")

