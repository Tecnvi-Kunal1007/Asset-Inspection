class WorkReport {
  final String id;
  final String freelancerId;
  final String taskId;
  final String equipmentName;
  final String workDescription;
  final String replacedParts;
  final DateTime repairDate;
  final DateTime nextDueDate;
  final String? workPhotoUrl;
  final String? finishedPhotoUrl;
  final String? geotaggedPhotoUrl;
  final double? latitude;
  final double? longitude;
  final String? locationAddress;
  final String? qrCodeData;
  final DateTime createdAt;

  WorkReport({
    required this.id,
    required this.freelancerId,
    required this.taskId,
    required this.equipmentName,
    required this.workDescription,
    required this.replacedParts,
    required this.repairDate,
    required this.nextDueDate,
    this.workPhotoUrl,
    this.finishedPhotoUrl,
    this.geotaggedPhotoUrl,
    this.latitude,
    this.longitude,
    this.locationAddress,
    this.qrCodeData,
    required this.createdAt,
  });

  factory WorkReport.fromJson(Map<String, dynamic> json) {
    return WorkReport(
      id: json['id'] as String,
      freelancerId: json['freelancer_id'] as String,
      taskId: json['task_id'] as String,
      equipmentName: json['equipment_name'] as String,
      workDescription: json['work_description'] as String,
      replacedParts: json['replaced_parts'] as String,
      repairDate: DateTime.parse(json['repair_date'] as String),
      nextDueDate: DateTime.parse(json['next_due_date'] as String),
      workPhotoUrl: json['work_photo_url'] as String?,
      finishedPhotoUrl: json['finished_photo_url'] as String?,
      geotaggedPhotoUrl: json['geotagged_photo_url'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      locationAddress: json['location_address'] as String?,
      qrCodeData: json['qr_code_data'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'freelancer_id': freelancerId,
      'task_id': taskId,
      'equipment_name': equipmentName,
      'work_description': workDescription,
      'replaced_parts': replacedParts,
      'repair_date': repairDate.toIso8601String(),
      'next_due_date': nextDueDate.toIso8601String(),
      'work_photo_url': workPhotoUrl,
      'finished_photo_url': finishedPhotoUrl,
      'geotagged_photo_url': geotaggedPhotoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'location_address': locationAddress,
      'qr_code_data': qrCodeData,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
