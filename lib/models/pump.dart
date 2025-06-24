class Pump {
  final String id;
  final String siteId;
  final String name;
  final int capacity;
  final int head;
  final int ratedPower;
  final String uid;
  final String qrImageUrl;
  final String status;
  final String mode;
  final num startPressure;
  final String stopPressure;
  final String suctionValve;
  final String deliveryValve;
  final String pressureGauge;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String operationalStatus;
  final String? comments;

  Pump({
    required this.id,
    required this.siteId,
    required this.name,
    required this.capacity,
    required this.head,
    required this.ratedPower,
    required this.uid,
    required this.qrImageUrl,
    required this.status,
    required this.mode,
    required this.startPressure,
    required this.stopPressure,
    required this.suctionValve,
    required this.deliveryValve,
    required this.pressureGauge,
    required this.createdAt,
    required this.updatedAt,
    required this.operationalStatus,
    this.comments,
  });

  factory Pump.fromJson(Map<String, dynamic> json) {
    // Calculate operational status based on valve and pressure gauge states
    final suctionValve = json['suction_valve'] as String? ?? 'Closed';
    final deliveryValve = json['delivery_valve'] as String? ?? 'Closed';
    final pressureGauge = json['pressure_gauge'] as String? ?? 'Not Working';

    String operationalStatus = 'Non-Operating';
    if (suctionValve.toLowerCase() == 'opened' &&
        deliveryValve.toLowerCase() == 'opened' &&
        pressureGauge.toLowerCase() == 'working') {
      operationalStatus = 'Operating';
    }

    return Pump(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      name: json['name'] as String,
      capacity: json['capacity'] as int? ?? 0,
      head: json['head'] as int? ?? 0,
      ratedPower: json['rated_power'] as int? ?? 0,
      uid: json['uid'] as String,
      qrImageUrl: json['qr_image_url'] as String? ?? '',
      status: json['status'] as String? ?? 'Not Working',
      mode: json['mode'] as String? ?? 'Manual',
      startPressure: json['start_pressure'] as num? ?? 0,
      stopPressure: json['stop_pressure'] as String? ?? '0',
      suctionValve: suctionValve,
      deliveryValve: deliveryValve,
      pressureGauge: pressureGauge,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      operationalStatus:
          json['operational_status'] as String? ?? operationalStatus,
      comments: json['comments'] as String? ?? 'Please enter comments',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'site_id': siteId,
      'name': name,
      'capacity': capacity,
      'head': head,
      'rated_power': ratedPower,
      'uid': uid,
      'qr_image_url': qrImageUrl,
      'status': status,
      'mode': mode,
      'start_pressure': startPressure,
      'stop_pressure': stopPressure,
      'suction_valve': suctionValve,
      'delivery_valve': deliveryValve,
      'pressure_gauge': pressureGauge,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'operational_status': operationalStatus,
      'comments': comments,
    };
  }

  String calculateOperationalStatus() {
    if (suctionValve.toLowerCase() == 'opened' &&
        deliveryValve.toLowerCase() == 'opened' &&
        pressureGauge.toLowerCase() == 'working') {
      return 'Operating';
    }
    return 'Non-Operating';
  }

  Pump copyWith({
    String? id,
    String? siteId,
    String? name,
    int? capacity,
    int? head,
    int? ratedPower,
    String? uid,
    String? qrImageUrl,
    String? status,
    String? mode,
    num? startPressure,
    String? stopPressure,
    String? suctionValve,
    String? deliveryValve,
    String? pressureGauge,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? operationalStatus,
    String? comments,
  }) {
    return Pump(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      head: head ?? this.head,
      ratedPower: ratedPower ?? this.ratedPower,
      uid: uid ?? this.uid,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
      status: status ?? this.status,
      mode: mode ?? this.mode,
      startPressure: startPressure ?? this.startPressure,
      stopPressure: stopPressure ?? this.stopPressure,
      suctionValve: suctionValve ?? this.suctionValve,
      deliveryValve: deliveryValve ?? this.deliveryValve,
      pressureGauge: pressureGauge ?? this.pressureGauge,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      operationalStatus: operationalStatus ?? this.operationalStatus,
      comments: comments ?? this.comments,
    );
  }
}
