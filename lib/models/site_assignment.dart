class SiteAssignment {
  final String id;
  final String siteId;
  final String assignedToId;
  final String assignedToType; // 'freelancer' or 'employee'
  final String assignedById;
  final DateTime assignedAt;
  final DateTime? unassignedAt;
  final String status; // 'active' or 'inactive'
  final String? notes;

  SiteAssignment({
    required this.id,
    required this.siteId,
    required this.assignedToId,
    required this.assignedToType,
    required this.assignedById,
    required this.assignedAt,
    this.unassignedAt,
    required this.status,
    this.notes,
  });

  factory SiteAssignment.fromJson(Map<String, dynamic> json) {
    return SiteAssignment(
      id: json['id'] as String,
      siteId: json['site_id'] as String,
      assignedToId: json['assigned_to_id'] as String,
      assignedToType: json['assigned_to_type'] as String,
      assignedById: json['assigned_by_id'] as String,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      unassignedAt:
          json['unassigned_at'] != null
              ? DateTime.parse(json['unassigned_at'] as String)
              : null,
      status: json['status'] as String,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'site_id': siteId,
      'assigned_to_id': assignedToId,
      'assigned_to_type': assignedToType,
      'assigned_by_id': assignedById,
      'assigned_at': assignedAt.toIso8601String(),
      'unassigned_at': unassignedAt?.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }
}
