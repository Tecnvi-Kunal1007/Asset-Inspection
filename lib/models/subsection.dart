import 'package:postgrest/src/types.dart';

class Subsection {
  final String id;
  final String sectionId;
  final String name;
  final Map<String, dynamic>? data; // JSONB column for additional key-value pairs
  final String? qrUrl; // Add QR URL field

  Subsection({
    required this.id,
    required this.sectionId,
    required this.name,
    this.data,
    this.qrUrl, // Add to constructor
  });

  factory Subsection.fromJson(Map<String, dynamic> json) {
    // Handle the case where data might be a String or a Map
    Map<String, dynamic>? dataMap;

    if (json['data'] == null) {
      dataMap = null;
    } else if (json['data'] is Map) {
      dataMap = Map<String, dynamic>.from(json['data'] as Map);
    } else if (json['data'] is String) {
      // If data is a String, create a map with a default key
      dataMap = {'value': json['data']};
    } else {
      // For any other type, use an empty map
      dataMap = {};
    }

    return Subsection(
      id: json['id'] as String? ?? '',
      sectionId: json['section_id'] as String? ?? '',
      name: json['name'] as String? ?? '', // Separate name column
      data: dataMap != null && dataMap.isNotEmpty ? dataMap : null, // Only key-value pairs
      qrUrl: json['subsection_qr_url'] as String?, // Updated to use subsection_qr_url
    );
  }
  
  // Convert Subsection to Map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'section_id': sectionId,
      'name': name,
      'data': data ?? {},
      'subsection_qr_url': qrUrl, // Updated to use subsection_qr_url
    };
  }

  // Check if subsection has a valid QR code
  bool get hasQrCode =>
      qrUrl != null &&
      qrUrl!.isNotEmpty &&
      qrUrl != 'pending' &&
      Uri.tryParse(qrUrl!)?.hasScheme == true;
}
