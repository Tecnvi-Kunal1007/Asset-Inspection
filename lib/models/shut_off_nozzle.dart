import 'package:supabase_flutter/supabase_flutter.dart';

class ShutOffNozzle {
  final String id;
  final String floorId;
  String status; // Removed final to make it mutable
  String? note; // Removed final to make it mutable
  final DateTime createdAt;
  final DateTime updatedAt;

  ShutOffNozzle({
    required this.id,
    required this.floorId,
    required this.status,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShutOffNozzle.fromJson(Map<String, dynamic> json) {
    return ShutOffNozzle(
      id: json['id'],
      floorId: json['floor_id'],
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
      'status': status,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
