import 'package:supabase_flutter/supabase_flutter.dart';

class HydrantValve {
  final String id;
  final String floorId;
  final String valveType; // 'Single' or 'Double'
  String status; // Removed final to make it mutable
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  HydrantValve({
    required this.id,
    required this.floorId,
    required this.valveType,
    required this.status,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HydrantValve.fromJson(Map<String, dynamic> json) {
    return HydrantValve(
      id: json['id'],
      floorId: json['floor_id'],
      valveType: json['valve_type'],
      status: json['status'],
      note: json['note'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'floor_id': floorId,
      'valve_type': valveType,
      'status': status,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
