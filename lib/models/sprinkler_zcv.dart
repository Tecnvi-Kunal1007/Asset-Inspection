class SprinklerZCV {
  final String id;
  final String floorId;
  String status; // Can only be 'Open' or 'Close'
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  SprinklerZCV({
    required this.id,
    required this.floorId,
    required this.status,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SprinklerZCV.fromJson(Map<String, dynamic> json) {
    return SprinklerZCV(
      id: json['id'] as String,
      floorId: json['floor_id'] as String,
      status: json['status'] as String,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
