import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // Import for debugPrint
import 'dart:async'; // Import for TimeoutException
import 'dart:io'; // Import for Platform

class ApiService {
  // Using 10.0.2.2 for Android emulator (special IP to access host machine's localhost)
  // For web or real devices, use your actual IP address or the Cloud Run URL
  static String get baseUrl {
    if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine's localhost
      return "http://10.0.2.2:5000";
    } else if (Platform.isIOS) {
      // For iOS simulator, use localhost
      return "http://localhost:5000";
    } else {
      // For web or other platforms, use localhost
      return "http://localhost:5000";
    }
  }
  
  // For production, use this Cloud Run URL instead:
  // static const String baseUrl = "https://crop-yield-api-103191170489.asia-south1.run.app";
  
  static const Duration timeoutDuration = Duration(seconds: 45);

  // Method that returns both recommendation and feature data
  static Future<Map<String, dynamic>> recommendCropWithFeatures(
      double latitude, double longitude) async {
    // Construct the URL with query parameters
    final uriWithFeatures = Uri.parse(
        '$baseUrl/recommend_crop_with_features?lat=$latitude&lon=$longitude');
    print('Calling: $uriWithFeatures'); // Log the URL being called

    try {
      // Make the GET request with a timeout
      final response = await http.get(uriWithFeatures).timeout(timeoutDuration);

      // Check if the server responded successfully (Status Code 200)
      if (response.statusCode == 200) {
        final data = json.decode(response.body); // Parse the JSON response
        // Check if the parsed data is a Map and contains the expected key
        if (data is Map && data.containsKey('recommended_crop')) {
          return data.cast<String, dynamic>(); // Return the data as the correct type
        } else {
          // Log if the response structure is unexpected
          debugPrint("Server Response Missing Key or wrong format (recommendCropWithFeatures): ${response.body}");
          // Extract error message from server response if available
          String errorMsg = (data is Map && data.containsKey('error')) ? data['error'] : 'Unexpected response format';
          throw Exception('Failed to recommend crop: $errorMsg'); // Throw specific error
        }
      } else {
        // Handle non-200 server responses (e.g., 500 Internal Server Error, 404 Not Found)
        debugPrint("Server Error ${response.statusCode} (recommendCropWithFeatures): ${response.body}");
        throw Exception(
            'Server error (${response.statusCode}). Please try again later.'); // User-friendly error
      }
    } on TimeoutException {
       // Handle cases where the request takes too long
       debugPrint("TimeoutException (recommendCropWithFeatures)");
       throw Exception('The request timed out. Please check your connection and try again.');
    } catch (e) {
       // Handle other potential errors (e.g., no internet connection, DNS issues)
       debugPrint("Generic Exception (recommendCropWithFeatures): $e");
       if (e is Exception && e.toString().contains('Failed host lookup')) {
           throw Exception('Could not connect to the server. Check your internet connection.');
       }
        if (e is Exception && e.toString().contains('Connection refused')) {
            // This is less likely with a deployed URL, but good to keep
           throw Exception('Connection refused by the server.');
       }
       // Rethrow specific exceptions or provide a generic message
       if (e is Exception && e.toString().startsWith('Exception: Failed')) {
           rethrow;
       }
       throw Exception('An error occurred: ${e.toString()}');
    }
  }

  // Method that returns both yield prediction and feature data
  static Future<Map<String, dynamic>> predictYieldWithFeatures(
      String cropName, double latitude, double longitude) async {
    // Construct the URL with query parameters
    final uriWithFeatures = Uri.parse(
        '$baseUrl/predict_yield_with_features?crop=$cropName&lat=$latitude&lon=$longitude');
    print('Calling: $uriWithFeatures'); // Log the URL being called

    try {
        // Make the GET request with a timeout
        final response = await http.get(uriWithFeatures).timeout(timeoutDuration);

        // Check if the server responded successfully (Status Code 200)
        if (response.statusCode == 200) {
            final data = json.decode(response.body); // Parse the JSON response
            // Check if the parsed data is a Map and contains the expected key
            if (data is Map && data.containsKey('predicted_yield')) {
                return data.cast<String, dynamic>(); // Return the data as the correct type
            } else {
                // Log if the response structure is unexpected
                debugPrint("Server Response Missing Key or wrong format (predictYieldWithFeatures): ${response.body}");
                 // Extract error message from server response if available
                String errorMsg = (data is Map && data.containsKey('error')) ? data['error'] : 'Unexpected response format';
                throw Exception('Failed to predict yield: $errorMsg'); // Throw specific error
            }
        } else {
            // Handle non-200 server responses
            debugPrint("Server Error ${response.statusCode} (predictYieldWithFeatures): ${response.body}");
            throw Exception(
                 'Server error (${response.statusCode}). Please try again later.'); // User-friendly error
        }
    } on TimeoutException {
        // Handle cases where the request takes too long
       debugPrint("TimeoutException (predictYieldWithFeatures)");
       throw Exception('The request timed out. Please check your connection and try again.');
    } catch (e) {
       // Handle other potential errors
       debugPrint("Generic Exception (predictYieldWithFeatures): $e");
        if (e is Exception && e.toString().contains('Failed host lookup')) {
           throw Exception('Could not connect to the server. Check your internet connection.');
       }
        if (e is Exception && e.toString().contains('Connection refused')) {
            // Less likely with deployed URL
           throw Exception('Connection refused by the server.');
       }
       // Rethrow specific exceptions or provide a generic message
       if (e is Exception && e.toString().startsWith('Exception: Failed')) {
           rethrow;
       }
       throw Exception('An error occurred: ${e.toString()}');
    }
  }
}

