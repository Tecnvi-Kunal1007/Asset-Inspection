import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> getAddressFromCoordinates(double lat, double lng, String apiKey) async {
  final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey");

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print("Data status: ${data['status']}");
    print("Data results: ${data['results']}");
    if (data['status'] == 'OK' && data['results'].isNotEmpty) {
      return data['results'][0]['formatted_address'];
    } else {
      return 'No address found';
    }
  } else {
    throw Exception('Failed to fetch address: ${response.reasonPhrase}');
  }
}


Future<Position> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception("Location services are disabled.");
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception("Location permissions are denied.");
    }
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception("Location permissions are permanently denied.");
  }

  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}

Future<String> getCurrentAddress(String apiKey) async {
  final position = await getCurrentLocation();
  print(position.latitude); print(position.longitude);
  final address = await getAddressFromCoordinates(position.latitude, position.longitude, apiKey);
  return address;
}

String apiKey = 'AIzaSyA-j5inZ4Cn4P9uFh5MH9Qf0lWJ_8eKdD4';

Future<String> fetchAddress() async {
  String address = await getCurrentAddress(apiKey);
  print("Current Address: $address");
  return address;
}