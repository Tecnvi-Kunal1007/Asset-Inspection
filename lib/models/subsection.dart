import 'package:postgrest/src/types.dart';

class Subsection {
  final String id;
  final String sectionId;
  final String name;
  final Map<String, dynamic>? data; // JSONB column for additional key-value pairs

  Subsection({
    required this.id,
    required this.sectionId,
    required this.name,
    this.data,
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
    );
  }
  
  // Convert Subsection to Map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'section_id': sectionId,
      'name': name,
      'data': data ?? {},
    };
  }
}
