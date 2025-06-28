import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'location_service.dart';

/// A helper class to manage location-related functionality
class LocationHelper {
  // Singleton pattern
  static final LocationHelper _instance = LocationHelper._internal();
  factory LocationHelper() => _instance;
  LocationHelper._internal();

  // Google Maps API key - consider moving this to environment variables for security
  final String apiKey = 'AIzaSyA-j5inZ4Cn4P9uFh5MH9Qf0lWJ_8eKdD4';

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

  /// Request location permissions with a user-friendly dialog
  Future<bool> requestLocationPermission(BuildContext context) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show dialog to enable location services
        final bool shouldProceed = await _showLocationServiceDialog(context);
        if (!shouldProceed) return false;
        
        // Open location settings
        await Geolocator.openLocationSettings();
        
        // Check again after user interaction
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return false;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Show dialog explaining why we need location permission
        final bool shouldProceed = await _showPermissionRationaleDialog(context);
        if (!shouldProceed) return false;
        
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }

      if (permission == LocationPermission.deniedForever) {
        // Show dialog to guide user to app settings
        final bool shouldOpenSettings = await _showOpenSettingsDialog(context);
        if (shouldOpenSettings) {
          await Geolocator.openAppSettings();
          // We can't know the result of the settings change, so we check again
          return await isLocationAvailable();
        }
        return false;
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting location permission: $e');
      }
      return false;
    }
  }

  /// Get current location with error handling
  Future<Position?> getCurrentLocationSafely(BuildContext context) async {
    try {
      // First check if location is available
      bool isAvailable = await isLocationAvailable();
      if (!isAvailable) {
        // Request permission if not available
        bool permissionGranted = await requestLocationPermission(context);
        if (!permissionGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required')),
          );
          return null;
        }
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting your location...')),
      );

      // Get current position with timeout
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return position;
    } on TimeoutException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location request timed out. Please try again.')),
      );
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current location: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: ${e.toString()}')),
      );
      return null;
    }
  }

  /// Get current address with error handling
  Future<String?> getCurrentAddressSafely(BuildContext context) async {
    try {
      final position = await getCurrentLocationSafely(context);
      if (position == null) return null;

      final address = await getAddressFromCoordinates(
        position.latitude, 
        position.longitude, 
        apiKey
      );
      return address;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current address: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting address: ${e.toString()}')),
      );
      return null;
    }
  }

  /// Generate a Google Maps link from current location
  Future<String?> generateLocationLink(BuildContext context) async {
    try {
      final position = await getCurrentLocationSafely(context);
      if (position == null) return null;
      
      // Create a Google Maps URL with the coordinates
      final lat = position.latitude;
      final lng = position.longitude;
      final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      
      return mapsUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error generating location link: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating location link: ${e.toString()}')),
      );
      return null;
    }
  }

  // Private helper methods for dialogs
  Future<bool> _showLocationServiceDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Location services are disabled. Would you like to enable them?'
          ),
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
  }

  Future<bool> _showPermissionRationaleDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission'),
          content: const Text(
            'We need your location to provide accurate information about nearby sites and to share your location with team members.'
          ),
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
  }

  Future<bool> _showOpenSettingsDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Denied'),
          content: const Text(
            'Location permission is permanently denied. Please open app settings to enable location permission.'
          ),
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
  }
}