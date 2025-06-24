class FlasherHooterAlarm {
  final String id;
  String status;
  String? note;
  final String floorId;

  FlasherHooterAlarm({
    required this.id,
    required this.status,
    this.note,
    required this.floorId,
  });

  factory FlasherHooterAlarm.fromJson(Map<String, dynamic> json) {
    return FlasherHooterAlarm(
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
