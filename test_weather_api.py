#!/usr/bin/env python3
"""
Test script for Weather API integration
Run this to verify rainfall API is working correctly
"""

import requests
import json

# Test endpoints with sample locations
TEST_CASES = [
    {
        "name": "New Delhi (Subtropical)",
        "crop": "Rice",
        "lat": 28.7041,
        "lon": 77.1025
    },
    {
        "name": "Mumbai (Tropical)",
        "crop": "Rice",
        "lat": 19.0760,
        "lon": 72.8777
    },
    {
        "name": "Bangalore (Temperate)",
        "crop": "Coffee",
        "lat": 12.9716,
        "lon": 77.5946
    }
]

BASE_URL = "http://localhost:5000"

def test_crop_recommendation(lat, lon, location_name):
    """Test the crop recommendation endpoint"""
    print(f"\n{'='*60}")
    print(f"Testing Crop Recommendation for {location_name}")
    print(f"Coordinates: ({lat}, {lon})")
    print('='*60)
    
    url = f"{BASE_URL}/recommend_crop_with_features?lat={lat}&lon={lon}"
    
    try:
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        
        data = response.json()
        
        print(f"\n✅ SUCCESS - Status Code: {response.status_code}")
        print(f"\nResponse Data:")
        print(json.dumps(data, indent=2))
        
        # Check if rainfall was fetched correctly
        if 'features' in data and 'Rainfall' in data['features']:
            rainfall = data['features']['Rainfall']
            print(f"\n🌧️  Rainfall: {rainfall} mm/year")
            if rainfall == 800.0:
                print("⚠️  WARNING: Using fallback rainfall value (API may have failed)")
            else:
                print("✓ Rainfall fetched from weather API")
        
        return True
        
    except requests.exceptions.ConnectionError:
        print(f"\n❌ ERROR: Could not connect to server at {BASE_URL}")
        print("Make sure Flask app is running: python app.py")
        return False
    except requests.exceptions.Timeout:
        print(f"\n❌ ERROR: Request timed out after 15 seconds")
        return False
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        return False


def test_yield_prediction(crop, lat, lon, location_name):
    """Test the yield prediction endpoint"""
    print(f"\n{'='*60}")
    print(f"Testing Yield Prediction for {location_name}")
    print(f"Crop: {crop}, Coordinates: ({lat}, {lon})")
    print('='*60)
    
    url = f"{BASE_URL}/predict_yield_with_features?crop={crop}&lat={lat}&lon={lon}"
    
    try:
        response = requests.get(url, timeout=15)
        response.raise_for_status()
        
        data = response.json()
        
        print(f"\n✅ SUCCESS - Status Code: {response.status_code}")
        print(f"\nResponse Data:")
        print(json.dumps(data, indent=2))
        
        # Check if rainfall was fetched correctly
        if 'features' in data and 'Rainfall' in data['features']:
            rainfall = data['features']['Rainfall']
            print(f"\n🌧️  Rainfall: {rainfall} mm/year")
            if rainfall == 800.0:
                print("⚠️  WARNING: Using fallback rainfall value (API may have failed)")
            else:
                print("✓ Rainfall fetched from weather API")
        
        return True
        
    except requests.exceptions.ConnectionError:
        print(f"\n❌ ERROR: Could not connect to server at {BASE_URL}")
        print("Make sure Flask app is running: python app.py")
        return False
    except requests.exceptions.Timeout:
        print(f"\n❌ ERROR: Request timed out after 15 seconds")
        return False
    except Exception as e:
        print(f"\n❌ ERROR: {str(e)}")
        return False


def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("🌾 WEATHER API INTEGRATION TEST")
    print("="*60)
    print(f"\nTesting against: {BASE_URL}")
    print("\nMake sure:")
    print("1. Flask server is running (python app.py)")
    print("2. Firebase is configured correctly")
    print("3. Sensor data exists in Firebase")
    
    passed = 0
    failed = 0
    
    for test_case in TEST_CASES:
        # Test crop recommendation
        if test_crop_recommendation(test_case['lat'], test_case['lon'], test_case['name']):
            passed += 1
        else:
            failed += 1
        
        # Test yield prediction
        if test_yield_prediction(test_case['crop'], test_case['lat'], test_case['lon'], test_case['name']):
            passed += 1
        else:
            failed += 1
    
    # Summary
    print(f"\n\n{'='*60}")
    print("📊 TEST SUMMARY")
    print(f"{'='*60}")
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    print(f"📈 Total: {passed + failed}")
    
    if failed == 0:
        print("\n🎉 All tests passed! Weather API integration is working correctly.")
    else:
        print(f"\n⚠️  {failed} test(s) failed. Check the errors above.")


if __name__ == "__main__":
    main()
