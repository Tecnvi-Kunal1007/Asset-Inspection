import 'package:supabase_flutter/supabase_flutter.dart';

class Floor {
  final String id;
  final String siteId;
  String floorType;
  String? remarks;
  final DateTime createdAt;
  final DateTime updatedAt;

  Floor({
    required this.id,
    required this.siteId,
    required this.floorType,
    this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Floor.fromJson(Map<String, dynamic> json) {
    return Floor(
      id: json['id'],
      siteId: json['site_id'],
      floorType: json['floor_type'],
      remarks: json['remarks'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'site_id': siteId,
      'floor_type': floorType,
      'remarks': remarks,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
