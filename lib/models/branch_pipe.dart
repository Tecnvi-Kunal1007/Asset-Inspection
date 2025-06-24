class BranchPipe {
  final String id;
  final String floorId;
  String status;
  String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  BranchPipe({
    required this.id,
    required this.floorId,
    required this.status,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BranchPipe.fromJson(Map<String, dynamic> json) {
    return BranchPipe(
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
