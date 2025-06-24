class SmokeDetector {
  final String id;
  String status;
  String? note;
  final String floorId;

  SmokeDetector({
    required this.id,
    required this.status,
    this.note,
    required this.floorId,
  });

  factory SmokeDetector.fromJson(Map<String, dynamic> json) {
    return SmokeDetector(
      id: json['id'],
      status: json['status'],
      note: json['note'],
      floorId: json['floor_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'status': status, 'note': note, 'floor_id': floorId};
  }
}
