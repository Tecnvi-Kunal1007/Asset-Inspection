class BuildingAccessories {
  final String id;
  final String siteId;
  String fireAlarmPanelStatus;
  String repeaterPanelStatus;
  String batteryStatus;
  String liftIntegrationRelayStatus;
  String accessIntegrationStatus;
  String pressFanIntegrationStatus;
  String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  BuildingAccessories({
    required this.id,
    required this.siteId,
    required this.fireAlarmPanelStatus,
    required this.repeaterPanelStatus,
    required this.batteryStatus,
    required this.liftIntegrationRelayStatus,
    required this.accessIntegrationStatus,
    required this.pressFanIntegrationStatus,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BuildingAccessories.fromJson(Map<String, dynamic> json) {
    return BuildingAccessories(
      id: json['id'],
      siteId: json['site_id'],
      fireAlarmPanelStatus: json['fire_alarm_panel_status'],
      repeaterPanelStatus: json['repeater_panel_status'],
      batteryStatus: json['battery_status'],
      liftIntegrationRelayStatus: json['lift_integration_relay_status'],
      accessIntegrationStatus: json['access_integration_status'],
      pressFanIntegrationStatus: json['press_fan_integration_status'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'site_id': siteId,
      'fire_alarm_panel_status': fireAlarmPanelStatus,
      'repeater_panel_status': repeaterPanelStatus,
      'battery_status': batteryStatus,
      'lift_integration_relay_status': liftIntegrationRelayStatus,
      'access_integration_status': accessIntegrationStatus,
      'press_fan_integration_status': pressFanIntegrationStatus,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
