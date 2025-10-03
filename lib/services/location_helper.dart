import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// A helper class to manage location-related functionality
class LocationHelper {
  // Singleton pattern
  static final LocationHelper _instance = LocationHelper._internal();
  factory LocationHelper() => _instance;
  LocationHelper._internal();

  // Get API key from environment variables
  String get apiKey {
    // For web builds, prioritize dart-define values over .env file
    if (kIsWeb) {
      final key = const String.fromEnvironment('Google_Api_Key', defaultValue: '');
      if (key.isNotEmpty) return key;
    }
    
    // For mobile/desktop, use .env file
    final key = dotenv.env['Google_Api_Key'] ?? '';
    if (key.isEmpty) {
      if (kDebugMode) {
        print('⚠️ [LocationHelper] Google API key not found in .env file');
      }
    }
    return key;
  }

  /// Check if location services are available and permissions are granted
  Future<bool> isLocationAvailable() async {
    try {
      if (kDebugMode) {
        print('🔍 [LocationHelper] Checking location availability...');
      }
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('❌ [LocationHelper] Location services are disabled');
        }
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      bool hasPermission = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      if (kDebugMode) {
        print('📍 [LocationHelper] Location permission status: $permission');
        print('✅ [LocationHelper] Has permission: $hasPermission');
      }

      return hasPermission;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Error checking location availability: $e');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
      return false;
    }
  }

  /// Request location permissions with a user-friendly dialog
  Future<bool> requestLocationPermission(BuildContext context) async {
    try {
      if (kDebugMode) {
        print('🔐 [LocationHelper] Requesting location permission...');
      }
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('⚠️ [LocationHelper] Location services disabled, showing dialog...');
        }
        final bool shouldProceed = await _showLocationServiceDialog(context);
        if (!shouldProceed) {
          if (kDebugMode) {
            print('❌ [LocationHelper] User declined to enable location services');
          }
          return false;
        }

        await Geolocator.openLocationSettings();
        await Future.delayed(const Duration(seconds: 1));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (kDebugMode) {
            print('❌ [LocationHelper] Location services still disabled after settings');
          }
          return false;
        }
        if (kDebugMode) {
          print('✅ [LocationHelper] Location services enabled');
        }
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print('⚠️ [LocationHelper] Location permission denied, showing rationale dialog...');
        }
        final bool shouldProceed = await _showPermissionRationaleDialog(context);
        if (!shouldProceed) {
          if (kDebugMode) {
            print('❌ [LocationHelper] User declined permission rationale');
          }
          return false;
        }

        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('❌ [LocationHelper] Permission denied after request');
          }
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('⚠️ [LocationHelper] Permission permanently denied, showing settings dialog...');
        }
        final bool shouldOpenSettings = await _showOpenSettingsDialog(context);
        if (shouldOpenSettings) {
          await Geolocator.openAppSettings();
          await Future.delayed(const Duration(seconds: 2));
          bool result = await isLocationAvailable();
          if (kDebugMode) {
            print('✅ [LocationHelper] Permission check after settings: $result');
          }
          return result;
        }
        if (kDebugMode) {
          print('❌ [LocationHelper] User declined to open settings');
        }
        return false;
      }

      if (kDebugMode) {
        print('✅ [LocationHelper] Location permission granted: $permission');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Error requesting location permission: $e');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
      return false;
    }
  }

  /// Get current location with enhanced error handling
  Future<Position?> getCurrentLocationSafely(BuildContext context) async {
    try {
      if (kDebugMode) {
        print('🌍 [LocationHelper] Starting getCurrentLocationSafely...');
      }
      // Check if location is available
      bool isAvailable = await isLocationAvailable();
      if (!isAvailable) {
        if (kDebugMode) {
          print('📍 [LocationHelper] Location not available, requesting permission...');
        }
        bool permissionGranted = await requestLocationPermission(context);
        if (!permissionGranted) {
          if (kDebugMode) {
            print('❌ [LocationHelper] Permission not granted, cannot get location');
          }
          _showSnackBar(context, 'Location permission is required');
          return null;
        }
      }

      _showSnackBar(context, 'Getting your location...', isLoading: true);

      if (kDebugMode) {
        print('🎯 [LocationHelper] Attempting to get current position...');
      }

      // Get current position with enhanced accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      if (kDebugMode) {
        print('✅ [LocationHelper] Position obtained: ${position.latitude}, ${position.longitude}');
        print('🎯 [LocationHelper] Accuracy: ${position.accuracy} meters');
        print('📍 [LocationHelper] Timestamp: ${position.timestamp}');
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      return position;
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('⏱️ [LocationHelper] Location request timed out: $e');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
      _showSnackBar(context, 'Location request timed out. Please try again.');
      return null;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('🚫 [LocationHelper] Platform exception getting location: ${e.code} - ${e.message}');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
      String message;
      switch (e.code) {
        case 'LOCATION_SERVICES_DISABLED':
          message = 'Location services are disabled. Please enable them in settings.';
          break;
        case 'LOCATION_PERMISSION_DENIED':
          message = 'Location permission denied. Please grant permission.';
          break;
        case 'LOCATION_PERMISSION_PERMANENTLY_DENIED':
          message = 'Location permission permanently denied. Please enable in app settings.';
          break;
        default:
          message = 'Error getting location: ${e.message ?? 'Unknown error'}';
      }
      _showSnackBar(context, message);
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Unexpected error getting current location: $e');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
      _showSnackBar(context, 'Unexpected error getting location. Please try again.');
      return null;
    }
  }

  /// Enhanced address fetching with better validation and debugging
  Future<String?> getAddressFromCoordinates(double lat, double lng, String apiKey) async {
    if (kDebugMode) {
      print('🌍 [LocationHelper] Getting address for coordinates: $lat, $lng');
      print('🔑 [LocationHelper] Using API key: ${apiKey.substring(0, 10)}... (hidden for security)');
    }

    // First try Google Geocoding API
    try {
      if (kDebugMode) {
        print('🌐 [LocationHelper] Attempting Google Geocoding API...');
      }
      final googleAddress = await _getGoogleGeocodingAddress(lat, lng, apiKey);
      if (googleAddress != null && _isValidAddress(googleAddress)) {
        if (kDebugMode) {
          print('✅ [LocationHelper] Google API returned valid address: $googleAddress');
        }
        return googleAddress;
      } else {
        if (kDebugMode) {
          print('⚠️ [LocationHelper] Google API returned invalid or null address: $googleAddress');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Google API failed: $e');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
    }

    // Fallback to local geocoding
    try {
      if (kDebugMode) {
        print('📱 [LocationHelper] Attempting local geocoding...');
      }
      final localAddress = await _getLocalGeocodingAddress(lat, lng);
      if (localAddress != null && _isValidAddress(localAddress)) {
        if (kDebugMode) {
          print('✅ [LocationHelper] Local geocoding returned valid address: $localAddress');
        }
        return localAddress;
      } else {
        if (kDebugMode) {
          print('⚠️ [LocationHelper] Local geocoding returned invalid or null address: $localAddress');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Local geocoding failed: $e');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
    }

    // Last resort: return formatted coordinates
    final fallbackAddress = "Location: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}";
    if (kDebugMode) {
      print('📍 [LocationHelper] Falling back to coordinates: $fallbackAddress');
    }
    return fallbackAddress;
  }

  /// Fetch address using Google Geocoding API
  Future<String?> _getGoogleGeocodingAddress(double lat, double lng, String apiKey) async {
    if (apiKey.isEmpty) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Invalid Google Maps API key: $apiKey');
      }
      return null;
    }

    final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json"
            "?latlng=$lat,$lng"
            "&key=$apiKey"
            "&language=en"
            "&result_type=street_address|route|locality|administrative_area_level_1|country"
    );

    if (kDebugMode) {
      print('🌐 [LocationHelper] Making Google API request to: ${url.toString().replaceAll(apiKey, 'API_KEY_HIDDEN')}');
    }

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        print('🌐 [LocationHelper] Google API Response Status: ${response.statusCode}');
        print('📋 [LocationHelper] Full Google API Response: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (kDebugMode) {
          print('📋 [LocationHelper] Google API Status: ${data['status']}');
          if (data['results'] != null) {
            print('📍 [LocationHelper] Found ${data['results'].length} results');
            for (var i = 0; i < data['results'].length; i++) {
              print('📍 [LocationHelper] Result $i: ${data['results'][i]['formatted_address'] ?? 'No address'}');
            }
          } else {
            print('📍 [LocationHelper] No results found in response');
          }
        }

        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          // Try to get the most specific address first
          for (var result in data['results']) {
            final address = result['formatted_address'] as String?;
            if (address != null && address.isNotEmpty) {
              final cleanedAddress = _cleanAddress(address);
              if (kDebugMode) {
                print('🏠 [LocationHelper] Found address: $cleanedAddress');
              }
              return cleanedAddress;
            }
          }
          if (kDebugMode) {
            print('⚠️ [LocationHelper] No valid formatted_address found in results');
          }
        } else {
          if (kDebugMode) {
            print('❌ [LocationHelper] Google API Error: ${data['status']} - ${data['error_message'] ?? 'No error message'}');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ [LocationHelper] HTTP Error: ${response.statusCode} - ${response.reasonPhrase}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Exception in Google API call: $e');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
      rethrow;
    }

    return null;
  }

  /// Fetch address using local geocoding
  Future<String?> _getLocalGeocodingAddress(double lat, double lng) async {
    if (kDebugMode) {
      print('📱 [LocationHelper] Attempting local geocoding for: $lat, $lng');
    }

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (kDebugMode) {
        print('📍 [LocationHelper] Local geocoding found ${placemarks.length} placemarks');
      }

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        if (kDebugMode) {
          print('🏷️ [LocationHelper] Placemark details:');
          print('  Street: ${place.street}');
          print('  SubLocality: ${place.subLocality}');
          print('  Locality: ${place.locality}');
          print('  Administrative Area: ${place.administrativeArea}');
          print('  Country: ${place.country}');
          print('  Postal Code: ${place.postalCode}');
          print('  Name: ${place.name}');
        }

        // Build address from most specific to least specific
        List<String> addressComponents = [];

        // Add street number and name if available
        if (place.street?.isNotEmpty == true) {
          addressComponents.add(place.street!);
        } else if (place.name?.isNotEmpty == true && place.name != place.locality) {
          // Use name if it's different from locality (to avoid duplication)
          addressComponents.add(place.name!);
        }

        // Add sub-locality or locality
        if (place.subLocality?.isNotEmpty == true) {
          addressComponents.add(place.subLocality!);
        } else if (place.locality?.isNotEmpty == true) {
          addressComponents.add(place.locality!);
        }

        // Add administrative area (state/province) if different from locality
        if (place.administrativeArea?.isNotEmpty == true && 
            place.administrativeArea != place.locality) {
          addressComponents.add(place.administrativeArea!);
        }

        // Add postal code if available
        if (place.postalCode?.isNotEmpty == true) {
          addressComponents.add(place.postalCode!);
        }

        // Add country
        if (place.country?.isNotEmpty == true) {
          addressComponents.add(place.country!);
        }

        if (addressComponents.isNotEmpty) {
          final address = addressComponents.join(", ");
          if (kDebugMode) {
            print('🏠 [LocationHelper] Built local address: $address');
          }
          return address;
        } else {
          if (kDebugMode) {
            print('⚠️ [LocationHelper] No valid address components found in placemark');
          }
          
          // Fallback: try to create a minimal address from available data
          List<String> fallbackComponents = [];
          
          if (place.locality?.isNotEmpty == true) {
            fallbackComponents.add(place.locality!);
          }
          if (place.country?.isNotEmpty == true) {
            fallbackComponents.add(place.country!);
          }
          
          if (fallbackComponents.isNotEmpty) {
            final fallbackAddress = fallbackComponents.join(", ");
            if (kDebugMode) {
              print('🏠 [LocationHelper] Using fallback address: $fallbackAddress');
            }
            return fallbackAddress;
          }
        }
      } else {
        if (kDebugMode) {
          print('⚠️ [LocationHelper] No placemarks returned from local geocoding');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Exception in local geocoding: $e');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
      rethrow;
    }

    return null;
  }

  /// Check if an address is valid (not just coordinates)
  bool _isValidAddress(String address) {
    if (kDebugMode) {
      print('🔍 [LocationHelper] Validating address: $address');
    }

    // Check if address is null or empty
    if (address.trim().isEmpty) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Address is empty');
      }
      return false;
    }

    // Check if address is ONLY our fallback coordinate pattern
    final fallbackCoordPattern = RegExp(r'^Location:\s*[\d\.\-]+,\s*[\d\.\-]+$');
    if (fallbackCoordPattern.hasMatch(address)) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Address is just our fallback coordinates pattern');
      }
      return false;
    }

    // Check if address is ONLY raw coordinates (like "12.345, 67.890")
    final rawCoordPattern = RegExp(r'^[\d\.\-]+\s*,\s*[\d\.\-]+$');
    if (rawCoordPattern.hasMatch(address)) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Address is just raw coordinates');
      }
      return false;
    }

    // Address should contain at least one alphabetic character (for place names, street names, etc.)
    if (!RegExp(r'[a-zA-Z]').hasMatch(address)) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Address contains no alphabetic characters');
      }
      return false;
    }

    // Address should be reasonably long (at least 3 characters)
    if (address.trim().length < 3) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Address too short: ${address.length} characters');
      }
      return false;
    }

    // If it passes all checks, it's a valid address
    if (kDebugMode) {
      print('✅ [LocationHelper] Address is valid: $address');
    }
    return true;
  }

  /// Clean up address formatting
  String _cleanAddress(String address) {
    if (kDebugMode) {
      print('🧹 [LocationHelper] Cleaning address: $address');
    }
    final cleaned = address
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r',\s*,'), ',')
        .trim();
    if (kDebugMode) {
      print('🧹 [LocationHelper] Cleaned address: $cleaned');
    }
    return cleaned;
  }

  /// Get current address with enhanced error handling and debugging
  Future<String?> getCurrentAddressSafely(BuildContext context) async {
    if (kDebugMode) {
      print('🎯 [LocationHelper] Starting getCurrentAddressSafely...');
    }

    try {
      final position = await getCurrentLocationSafely(context);
      if (position == null) {
        if (kDebugMode) {
          print('❌ [LocationHelper] Position is null, cannot get address');
        }
        return null;
      }

      _showSnackBar(context, 'Converting location to address...', isLoading: true);

      final address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
        apiKey,
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (address != null) {
        if (_isValidAddress(address)) {
          _showSnackBar(context, 'Address found successfully!', isSuccess: true);
          if (kDebugMode) {
            print('✅ [LocationHelper] Final valid address result: $address');
          }
          return address;
        } else {
          // Address exists but failed validation (likely coordinates)
          if (kDebugMode) {
            print('⚠️ [LocationHelper] Address validation failed, but returning result: $address');
          }
          _showSnackBar(context, 'Location found (coordinates only)', isSuccess: true);
          return address; // Return coordinates as fallback
        }
      } else {
        _showSnackBar(context, 'Could not determine address from location');
        if (kDebugMode) {
          print('❌ [LocationHelper] No address result returned');
        }
        // Return coordinates as last resort
        final fallbackAddress = "Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}";
        if (kDebugMode) {
          print('📍 [LocationHelper] Returning fallback coordinates: $fallbackAddress');
        }
        return fallbackAddress;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Error in getCurrentAddressSafely: $e');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      // Provide more specific error messages
      String errorMessage = 'Error getting address';
      if (e.toString().contains('network') || e.toString().contains('internet')) {
        errorMessage = 'Network error: Please check your internet connection';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Request timeout: Please try again';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Location permission required';
      } else {
        errorMessage = 'Error getting address: Please try again';
      }
      
      _showSnackBar(context, errorMessage);
      return null;
    }
  }

  /// Generate a Google Maps link from current location
  Future<String?> generateLocationLink(BuildContext context) async {
    try {
      if (kDebugMode) {
        print('🗺️ [LocationHelper] Generating Google Maps link...');
      }
      final position = await getCurrentLocationSafely(context);
      if (position == null) {
        if (kDebugMode) {
          print('❌ [LocationHelper] No position available for maps link');
        }
        return null;
      }

      final lat = position.latitude;
      final lng = position.longitude;
      final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      if (kDebugMode) {
        print('✅ [LocationHelper] Generated maps URL: $mapsUrl');
      }
      return mapsUrl;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [LocationHelper] Error generating location link: $e');
        print('📋 [LocationHelper] Stack trace: ${StackTrace.current}');
      }
      _showSnackBar(context, 'Error generating location link');
      return null;
    }
  }

  /// Enhanced snackbar helper
  void _showSnackBar(BuildContext context, String message, {bool isSuccess = false, bool isLoading = false}) {
    if (!context.mounted) {
      if (kDebugMode) {
        print('⚠️ [LocationHelper] Context not mounted, skipping SnackBar');
      }
      return;
    }

    if (kDebugMode) {
      print('🔔 [LocationHelper] Showing SnackBar: $message (isSuccess: $isSuccess, isLoading: $isLoading)');
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            if (isLoading) const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess
            ? Colors.green
            : isLoading
            ? Colors.blue
            : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: isLoading ? const Duration(seconds: 30) : const Duration(seconds: 4),
      ),
    );
  }

  // Dialog helper methods remain the same...
  Future<bool> _showLocationServiceDialog(BuildContext context) async {
    if (kDebugMode) {
      print('🔔 [LocationHelper] Showing location service dialog...');
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
              'Location services are disabled. Would you like to enable them?'),
          actions: <Widget>[
            TextButton(
              child: const Text('No'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
    if (kDebugMode) {
      print('🔔 [LocationHelper] Location service dialog result: $result');
    }
    return result;
  }

  Future<bool> _showPermissionRationaleDialog(BuildContext context) async {
    if (kDebugMode) {
      print('🔔 [LocationHelper] Showing permission rationale dialog...');
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
              'We need your location to provide accurate information about nearby sites and to share your location with team members.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Deny'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Allow'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
    if (kDebugMode) {
      print('🔔 [LocationHelper] Permission rationale dialog result: $result');
    }
    return result;
  }

  Future<bool> _showOpenSettingsDialog(BuildContext context) async {
    if (kDebugMode) {
      print('🔔 [LocationHelper] Showing open settings dialog...');
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Denied'),
          content: const Text(
              'Location permission is permanently denied. Please open app settings to enable location permission.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
    if (kDebugMode) {
      print('🔔 [LocationHelper] Open settings dialog result: $result');
    }
    return result;
  }
}