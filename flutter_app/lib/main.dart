import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart'; // Make sure api_service.dart is in the same lib folder

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crop Assistant',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto', // Using Roboto font
      ),
      home: const MainNavigationScreen(),
      debugShowCheckedModeBanner: false, // Hides the debug banner
    );
  }
}

// Main screen with bottom navigation
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0; // Index for the current screen

  // List of screens to navigate between
  final List<Widget> _screens = [
    const CropRecommendationScreen(),
    const YieldPredictionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack( // Use IndexedStack to keep state of inactive screens
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Update the index when an item is tapped
          });
        },
        type: BottomNavigationBarType.fixed, // Ensures items are always visible
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green[700], // Darker green for selected item
        unselectedItemColor: Colors.grey[600], // Slightly darker grey for unselected
        selectedFontSize: 12, // Slightly smaller font size
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.eco_outlined), // Using outlined icons
            activeIcon: Icon(Icons.eco),     // Filled icon when active
            label: 'Recommendation',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined), // Using outlined icons
            activeIcon: Icon(Icons.bar_chart),      // Filled icon when active
            label: 'Yield Prediction',
          ),
        ],
      ),
    );
  }
}

// Screen for Crop Recommendation
class CropRecommendationScreen extends StatefulWidget {
  const CropRecommendationScreen({super.key});

  @override
  State<CropRecommendationScreen> createState() => _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen> with TickerProviderStateMixin {
  String _recommendationResult = "Tap the button to get a recommendation.";
  bool _isLoading = false;
  Map<String, dynamic>? _featureData; // To store features returned by API
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Setup animation controller for fade-in effect
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800), // Slightly faster animation
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut), // Smoother curve
    );
  }

  @override
  void dispose() {
    _animationController.dispose(); // Dispose controller to prevent memory leaks
    super.dispose();
  }

  // Handles requesting location permission and showing dialogs if needed
  Future<bool> _requestLocationPermission() async {
     if (!mounted) return false;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Services Required'),
              content: const Text('Please enable location services to get accurate crop recommendations based on your current location.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Geolocator.openLocationSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            );
          },
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (!mounted) return false;

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (!mounted) return false;
      
      if (permission == LocationPermission.denied) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Location Permission Required'),
                content: const Text('Location permission is required to get accurate crop recommendations. Please grant permission to continue.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await Geolocator.openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              );
            },
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Permission Permanently Denied'),
              content: const Text('Location permissions are permanently denied. Please enable them in app settings to use this feature.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Geolocator.openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            );
          },
        );
      }
      return false;
    }

    return true;
  }

  // Gets the current device position with improved timeout and fallback
  Future<Position> _determinePosition() async {
    if (!mounted) return Future.error('Widget not mounted');

    // Default location: Velagapudi Ramakrishna Siddhartha Engineering College
    const double defaultLatitude = 16.4821158;
    const double defaultLongitude = 80.6913732;

    // First check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services disabled - using default location (College)');
      return Position(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print('Location permission denied - using default location (College)');
      return Position(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    // Try to get last known position first (works better on emulators)
    try {
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        print('Using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
        // Try to get current position, but use last known if it times out
        try {
          Position currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 10),
          );
          print('Current position obtained: ${currentPosition.latitude}, ${currentPosition.longitude}');
          return currentPosition;
        } catch (e) {
          // If current position fails, use last known
          print('Current position failed, using last known: $e');
          return lastPosition;
        }
      }
    } catch (e) {
      print('Last known position not available: $e');
    }

    // If no last known position, try to get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 30),
      );
       
      print('Position obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } on TimeoutException {
      // Try last known position as fallback
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          print('Timeout occurred, using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
          return lastPosition;
        }
      } catch (e) {
        print('Last known position also unavailable: $e');
      }
      // Use default location as final fallback
      print('GPS timeout - using default location (College): $defaultLatitude, $defaultLongitude');
      return Position(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } catch (e) {
      print('Error getting position: $e');
      // Try last known position as final fallback
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          print('Error occurred, using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
          return lastPosition;
        }
      } catch (fallbackError) {
        print('Last known position unavailable: $fallbackError');
      }
      // Use default location as final fallback
      print('All location methods failed - using default location (College): $defaultLatitude, $defaultLongitude');
      return Position(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  // Fetches crop recommendation from the API
  void _getRecommendation() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _featureData = null;
      _recommendationResult = "Fetching recommendation...";
    });

    try {
      // Request location permission
      final permissionGranted = await _requestLocationPermission();
      if (!mounted) return;
      if (!permissionGranted) {
        setState(() {
          _isLoading = false;
          _recommendationResult = 'Location permission is required to get recommendations.';
        });
        return;
      }

      Position position = await _determinePosition();
      if (!mounted) return;

      final result = await ApiService.recommendCropWithFeatures(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _recommendationResult = result['recommended_crop']?.toString() ?? 'No recommendation found';
          _featureData = result['features'] as Map<String, dynamic>?;
          _animationController.reset();
          _animationController.forward();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recommendationResult = 'Error: ${e.toString()}';
          _featureData = null;
        });
      }
      print("Error in _getRecommendation: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper widget to build display cards for environmental features
  Widget _buildFeatureCard(String title, String value, String unit, IconData icon, Color color) {
    // Ensure value is not null before trying to format
    String displayValue = (value == 'N/A' || value.isEmpty) ? 'N/A' : value;
    // Attempt to parse and format only if it's not 'N/A'
    if (displayValue != 'N/A') {
        try {
            // Try parsing as double first for decimals
            double numericValue = double.parse(value);
            // Format Temp, Hum, Soil, Rainfall with 2 decimals
            if (title.contains('Temperature') || title.contains('Humidity') || title.contains('Soil') || title.contains('Rainfall')) {
                 displayValue = numericValue.toStringAsFixed(2);
            } else {
                 // Format NPK as whole numbers (assuming they are integers or don't need decimals)
                 displayValue = numericValue.toStringAsFixed(0);
            }
        } catch (e) {
           // If parsing fails, keep the original string (might already be 'N/A' or an error string)
            print("Could not format feature value '$value' for $title: $e");
        }
    }


    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '$displayValue $unit', // Use formatted or original value
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis, // Prevent long text overflow
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Background gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9), // Lighter green at top
              Color(0xFFFFFFFF), // White at bottom
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center( // Show loading indicator
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        strokeWidth: 4,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Analyzing your location...',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView( // Makes the content scrollable if it overflows
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.eco,
                              size: 60,
                              color: Colors.green[700],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Crop Recommendation',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Get AI-powered crop recommendations based on your location',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Recommendation Result Card
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(Icons.eco, color: Colors.green, size: 60),
                                const SizedBox(height: 16),
                                Text(
                                  "Recommended Crop",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[800], // Darker green
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Main Result Display
                                Container(
                                  width: double.infinity, // Take full width
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _recommendationResult,
                                    style: TextStyle(
                                      fontSize: 26, // Larger font
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green[900], // Even darker green
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                const SizedBox(height: 25), // More space

                                // Feature Data Display (only if data exists)
                                if (_featureData != null) ...[
                                  Text(
                                    'Environmental Conditions Used', // More descriptive title
                                    style: TextStyle(
                                      fontSize: 20, // Larger title
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[850], // Darker grey
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  // Animated display of feature cards
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Column(
                                      children: [
                                        _buildFeatureCard(
                                          'Temperature',
                                          _featureData!['Temperature']?.toString() ?? 'N/A',
                                          '°C',
                                          Icons.thermostat_outlined, // Outlined icon
                                          Colors.redAccent, // Slightly different red
                                        ),
                                        _buildFeatureCard(
                                          'Humidity',
                                          _featureData!['Humidity']?.toString() ?? 'N/A',
                                          '%',
                                          Icons.water_drop_outlined, // Outlined icon
                                          Colors.blueAccent, // Slightly different blue
                                        ),
                                        _buildFeatureCard(
                                          'Soil Moisture',
                                          _featureData!['Soil_Moisture (%)']?.toString() ?? 'N/A',
                                          '%',
                                          Icons.grass_outlined, // Outlined icon
                                          Colors.lightGreen, // Lighter green
                                        ),
                                        _buildFeatureCard(
                                          'Yearly Avg Rainfall', // Abbreviated
                                          _featureData!['Rainfall']?.toString() ?? 'N/A',
                                          'mm/yr', // Abbreviated unit
                                          Icons.cloud_outlined, // Outlined icon
                                          Colors.indigoAccent, // Slightly different indigo
                                        ),
                                        _buildFeatureCard(
                                          'Nitrogen (N)',
                                          _featureData!['N']?.toString() ?? 'N/A',
                                          'ppm', // Standard unit
                                          Icons.science_outlined, // Outlined icon
                                          Colors.orangeAccent, // Slightly different orange
                                        ),
                                        _buildFeatureCard(
                                          'Phosphorus (P)',
                                          _featureData!['P']?.toString() ?? 'N/A',
                                          'ppm',
                                          Icons.science_outlined,
                                          Colors.purpleAccent, // Slightly different purple
                                        ),
                                        _buildFeatureCard(
                                          'Potassium (K)',
                                          _featureData!['K']?.toString() ?? 'N/A',
                                          'ppm',
                                          Icons.science_outlined,
                                          Colors.tealAccent, // Slightly different teal
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 25), // More space
                                ],

                                // Action Button
                                ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _getRecommendation, // Disable while loading
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Get New Recommendation'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[600], // Standard green
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30), // More rounded
                                    ),
                                    elevation: 5, // Add elevation
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30), // Bottom padding
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// Screen for Yield Prediction
class YieldPredictionScreen extends StatefulWidget {
  const YieldPredictionScreen({super.key});

  @override
  State<YieldPredictionScreen> createState() => _YieldPredictionScreenState();
}

class _YieldPredictionScreenState extends State<YieldPredictionScreen> with TickerProviderStateMixin {
  String _yieldResult = "Select a crop to predict yield.";
  bool _isLoading = false;
  Map<String, dynamic>? _featureData; // To store features
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // List of crops for the dropdown - INCLUDING Sugarcane
  final List<String> _crops = [
    'Apple', 'Banana', 'Blackgram', 'Chickpea', 'Coconut', 'Coffee',
    'Cotton', 'Grapes', 'Jute', 'Kidneybeans', 'Lentil', 'Maize',
    'Mango', 'Mothbeans', 'Mungbean', 'Muskmelon', 'Orange', 'Papaya',
    'Pigeonpeas', 'Pomegranate', 'Rice', 'Sugarcane', 'Watermelon', // Added Sugarcane
  ];
  String? _selectedCrop; // Currently selected crop

  @override
  void initState() {
    super.initState();
    // Setup animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose(); // Dispose controller
    super.dispose();
  }

  // Handles requesting location permission (same as recommendation screen)
  Future<bool> _requestLocationPermission() async {
     if (!mounted) return false;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Location Services Required'),
            content: const Text('Please enable location services to get accurate yield predictions based on your current location.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await Geolocator.openLocationSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          );
        },
      );
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (!mounted) return false;

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
       if (!mounted) return false;

      if (permission == LocationPermission.denied) {
        if (mounted) {
          await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text('Location permission is required to get accurate yield predictions. Please grant permission to continue.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await Geolocator.openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            );
          },
        );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Location Permission Permanently Denied'),
            content: const Text('Location permissions are permanently denied. Please enable them in app settings to use this feature.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await Geolocator.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          );
        },
      );
      }
      return false;
    }

    return true;
  }

  // Gets the current device position with improved timeout and fallback
  Future<Position> _determinePosition() async {
    if (!mounted) return Future.error('Widget not mounted');

    // Default location: Velagapudi Ramakrishna Siddhartha Engineering College
    const double defaultLatitude = 16.4821158;
    const double defaultLongitude = 80.6913732;

    // First check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services disabled - using default location (College)');
      return Position(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    // Check permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print('Location permission denied - using default location (College)');
      return Position(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }

    // Try to get last known position first (works better on emulators)
    try {
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null) {
        print('Using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
        // Try to get current position, but use last known if it times out
        try {
          Position currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 10),
          );
          print('Current position obtained: ${currentPosition.latitude}, ${currentPosition.longitude}');
          return currentPosition;
        } catch (e) {
          // If current position fails, use last known
          print('Current position failed, using last known: $e');
          return lastPosition;
        }
      }
    } catch (e) {
      print('Last known position not available: $e');
    }

    // If no last known position, try to get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 30),
      );
      
      print('Position obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } on TimeoutException {
      // Try last known position as fallback
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          print('Timeout occurred, using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
          return lastPosition;
        }
      } catch (e) {
        print('Last known position also unavailable: $e');
      }
      // Use default location as final fallback
      print('GPS timeout - using default location (College): $defaultLatitude, $defaultLongitude');
      return Position(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } catch (e) {
      print('Error getting position: $e');
      // Try last known position as final fallback
      try {
        Position? lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          print('Error occurred, using last known position: ${lastPosition.latitude}, ${lastPosition.longitude}');
          return lastPosition;
        }
      } catch (fallbackError) {
        print('Last known position unavailable: $fallbackError');
      }
      // Use default location as final fallback
      print('All location methods failed - using default location (College): $defaultLatitude, $defaultLongitude');
      return Position(
        latitude: defaultLatitude,
        longitude: defaultLongitude,
        timestamp: DateTime.now(),
        accuracy: 100,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    }
  }

  // Fetches yield prediction from the API
  void _predictYield() async {
    if (_selectedCrop == null || !mounted) return;

    setState(() {
      _isLoading = true;
      _featureData = null;
      _yieldResult = "Predicting yield for $_selectedCrop...";
    });

    try {
      // Request location permission
      final permissionGranted = await _requestLocationPermission();
      if (!mounted) return;
      if (!permissionGranted) {
        setState(() {
          _isLoading = false;
          _yieldResult = "Location permission is required to predict yield.";
        });
        return;
      }

      Position position = await _determinePosition();
      if (!mounted) return;

      final result = await ApiService.predictYieldWithFeatures(
        _selectedCrop!,
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          dynamic yieldValRaw = result['predicted_yield'];
          String yieldVal = 'N/A';
          if(yieldValRaw != null) {
              try {
                 yieldVal = double.parse(yieldValRaw.toString()).toStringAsFixed(2);
              } catch(e){
                 print("Could not parse yield value: $yieldValRaw - $e");
                 yieldVal = yieldValRaw.toString();
              }
          }

          final unitVal = result['unit']?.toString() ?? 'kg/ha';
          _yieldResult = "$yieldVal $unitVal";
          _featureData = result['features'] as Map<String, dynamic>?;
          _animationController.reset();
          _animationController.forward();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _yieldResult = 'Error: ${e.toString()}';
          _featureData = null;
        });
      }
      print("Error in _predictYield: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper widget to build feature cards (same as recommendation screen)
 Widget _buildFeatureCard(String title, String value, String unit, IconData icon, Color color) {
    // Ensure value is not null before trying to format
    String displayValue = (value == 'N/A' || value.isEmpty) ? 'N/A' : value;
     // Attempt to parse and format only if it's not 'N/A'
    if (displayValue != 'N/A') {
        try {
            // Try parsing as double first for decimals
            double numericValue = double.parse(value);
             // Format Temp, Hum, Soil, Rainfall with 2 decimals
            if (title.contains('Temperature') || title.contains('Humidity') || title.contains('Soil') || title.contains('Rainfall')) {
                 displayValue = numericValue.toStringAsFixed(2);
            } else {
                 // Format NPK as whole numbers (assuming they are integers or don't need decimals)
                 displayValue = numericValue.toStringAsFixed(0);
            }
        } catch (e) {
           // If parsing fails, keep the original string
            print("Could not format feature value '$value' for $title: $e");
        }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '$displayValue $unit', // Use formatted value
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                   overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Background gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3E0), // Lighter orange at top
              Color(0xFFFFFFFF), // White at bottom
            ],
          ),
        ),
        child: SafeArea(
        child: _isLoading
              ? const Center( // Show loading indicator
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                        strokeWidth: 4,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Analyzing crop yield...',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView( // Make content scrollable
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.bar_chart,
                              size: 60,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Yield Prediction',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Predict crop yield based on environmental conditions',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Crop Selection Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Crop',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Dropdown for selecting crop
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: DropdownButtonHideUnderline( // Hide default underline
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    hint: const Text("Choose a crop"),
                                    value: _selectedCrop,
                                    items: _crops.map((String crop) {
                                      return DropdownMenuItem<String>(
                                        value: crop,
                                        child: Text(crop),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      setState(() {
                                        _selectedCrop = newValue;
                                        // Clear previous results when crop changes
                                        _yieldResult = "Select a crop to predict yield.";
                                        _featureData = null;
                                      });
                                    },
                                    icon: Icon(Icons.arrow_drop_down, color: Colors.grey[700]),
                                    style: TextStyle(fontSize: 16, color: Colors.black87), // Style dropdown text
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Yield Prediction Result Card
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.orange.withOpacity(0.1), Colors.orange.withOpacity(0.05)],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(Icons.show_chart, color: Colors.orange, size: 60), // Use a different icon
                                const SizedBox(height: 16),
                                Text(
                                  "Predicted Yield",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[800], // Darker orange
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Main Result Display
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _yieldResult,
                                    style: TextStyle(
                                      fontSize: 26, // Larger font
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[900], // Even darker orange
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                                const SizedBox(height: 25), // More space

                                // Feature Data Display (only if data exists)
                                if (_featureData != null) ...[
                                  Text(
                                    'Environmental Conditions Used',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[850],
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  // Animated display of feature cards
                                  FadeTransition(
                                    opacity: _fadeAnimation,
                                    child: Column(
                                      children: [
                                        _buildFeatureCard(
                                          'Temperature',
                                          _featureData!['Temperature']?.toString() ?? 'N/A',
                                          '°C',
                                          Icons.thermostat_outlined,
                                          Colors.redAccent,
                                        ),
                                        _buildFeatureCard(
                                          'Humidity',
                                          _featureData!['Humidity']?.toString() ?? 'N/A',
                                          '%',
                                          Icons.water_drop_outlined,
                                          Colors.blueAccent,
                                        ),
                                        _buildFeatureCard(
                                          'Soil Moisture',
                                          _featureData!['Soil_Moisture (%)']?.toString() ?? 'N/A',
                                          '%',
                                          Icons.grass_outlined,
                                          Colors.lightGreen,
                                        ),
                                        _buildFeatureCard(
                                          'Yearly Avg Rainfall',
                                          _featureData!['Rainfall']?.toString() ?? 'N/A',
                                          'mm/yr',
                                          Icons.cloud_outlined,
                                          Colors.indigoAccent,
                                        ),
                                         _buildFeatureCard(
                                          'Nitrogen (N)',
                                          _featureData!['N']?.toString() ?? 'N/A',
                                          'ppm',
                                          Icons.science_outlined,
                                          Colors.orangeAccent,
                                        ),
                                        _buildFeatureCard(
                                          'Phosphorus (P)',
                                          _featureData!['P']?.toString() ?? 'N/A',
                                          'ppm',
                                          Icons.science_outlined,
                                          Colors.purpleAccent,
                                        ),
                                        _buildFeatureCard(
                                          'Potassium (K)',
                                          _featureData!['K']?.toString() ?? 'N/A',
                                          'ppm',
                                          Icons.science_outlined,
                                          Colors.tealAccent,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 25), // More space
                                ],

                                // Action Button
                                ElevatedButton.icon(
                                  // Disable button if no crop is selected or if loading
                                  onPressed: (_selectedCrop != null && !_isLoading) ? _predictYield : null,
                                  icon: const Icon(Icons.analytics_outlined), // Outlined icon
                                  label: const Text('Predict Yield'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[600], // Standard orange
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 30,
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30), // More rounded
                                    ),
                                    elevation: 5, // Add elevation
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30), // Bottom padding
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
