import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Get address from coordinates using Google Maps Geocoding API
/// Falls back to local geocoding if Google API fails
Future<String> getAddressFromCoordinates(double lat, double lng, String apiKey) async {
  try {
    // First try with Google Maps API
    final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey");

    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (kDebugMode) {
        print("Google API status: ${data['status']}");
      }
      
      if (data['status'] == 'OK' && data['results'].isNotEmpty) {
        return data['results'][0]['formatted_address'];
      }
    }
    
    // If Google API fails, fall back to local geocoding
    return await _getAddressFromLocalGeocoding(lat, lng);
  } catch (e) {
    if (kDebugMode) {
      print('Error in getAddressFromCoordinates: $e');
    }
    // Fall back to local geocoding
    return await _getAddressFromLocalGeocoding(lat, lng);
  }
}

/// Get address from coordinates using local geocoding package
Future<String> _getAddressFromLocalGeocoding(double lat, double lng) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
    if (placemarks.isNotEmpty) {
      Placemark place = placemarks[0];
      return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.postalCode}, ${place.country}';
    } else {
      return 'No address found';
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error in local geocoding: $e');
    }
    // If all else fails, return coordinates as string
    return '$lat, $lng';
  }
}


/// Check and request location permissions, then get current location
Future<Position> getCurrentLocation() async {
  try {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Try to enable location services
      if (kDebugMode) {
        print("Location services are disabled. Requesting to enable...");
      }
      // This will show a dialog to the user to enable location services
      bool userEnabledLocation = await Geolocator.openLocationSettings();
      if (!userEnabledLocation) {
        throw PlatformException(
          code: 'LOCATION_SERVICES_DISABLED',
          message: "Location services are disabled. Please enable them in settings."
        );
      }
      // Check again after user interaction
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw PlatformException(
          code: 'LOCATION_SERVICES_STILL_DISABLED',
          message: "Location services are still disabled."
        );
      }
    }

    // Check location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw PlatformException(
          code: 'LOCATION_PERMISSION_DENIED',
          message: "Location permissions are denied."
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Guide user to app settings
      if (kDebugMode) {
        print("Location permissions are permanently denied. Opening app settings...");
      }
      await Geolocator.openAppSettings();
      throw PlatformException(
        code: 'LOCATION_PERMISSION_PERMANENTLY_DENIED',
        message: "Location permissions are permanently denied. Please enable them in app settings."
      );
    }

    // Get current position with timeout
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  } catch (e) {
    if (kDebugMode) {
      print('Error getting current location: $e');
    }
    rethrow;
  }
}

/// Get current address using current location
Future<String> getCurrentAddress(String apiKey) async {
  try {
    final position = await getCurrentLocation();
    if (kDebugMode) {
      print('Current position: ${position.latitude}, ${position.longitude}');
    }
    final address = await getAddressFromCoordinates(position.latitude, position.longitude, apiKey);
    return address;
  } catch (e) {
    if (kDebugMode) {
      print('Error getting current address: $e');
    }
    if (e is PlatformException) {
      return 'Error: ${e.message}';
    }
    return 'Unable to get current address';
  }
}

// Google Maps API key - consider moving this to environment variables for security
const String apiKey = 'AIzaSyA-j5inZ4Cn4P9uFh5MH9Qf0lWJ_8eKdD4';

/// Convenience method to fetch current address
Future<String> fetchAddress() async {
  try {
    String address = await getCurrentAddress(apiKey);
    if (kDebugMode) {
      print("Current Address: $address");
    }
    return address;
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching address: $e');
    }
    return 'Unable to fetch address';
  }
}

/// Check if location services are available and permissions are granted
Future<bool> isLocationAvailable() async {
  try {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse || 
           permission == LocationPermission.always;
  } catch (e) {
    if (kDebugMode) {
      print('Error checking location availability: $e');
    }
    return false;
  }
}