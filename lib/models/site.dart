class Site {
  final String id;
  final String siteName;
  final String siteOwner;
  final String siteOwnerEmail;
  final String siteOwnerPhone;
  final String siteManager;
  final String siteManagerEmail;
  final String siteManagerPhone;
  final String siteInspectorName;
  final String siteInspectorEmail;
  final String siteInspectorPhone;
  final String siteInspectorPhoto;
  final String siteLocation;
  final String contractorEmail;
  final String contractorId;
  final String areaId;
  final DateTime createdAt;
  final String description; // Added as proper class field

  Site({
    required this.id,
    required this.siteName,
    required this.siteOwner,
    required this.siteOwnerEmail,
    required this.siteOwnerPhone,
    required this.siteManager,
    required this.siteManagerEmail,
    required this.siteManagerPhone,
    required this.siteInspectorName,
    required this.siteInspectorEmail,
    required this.siteInspectorPhone,
    required this.siteInspectorPhoto,
    required this.siteLocation,
    required this.contractorEmail,
    required this.contractorId,
    required this.areaId,
    required this.createdAt,
    required this.description,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    return Site(
      id: json['id'] as String,
      siteName: json['site_name'] as String,
      siteOwner: json['site_owner'] as String,
      siteOwnerEmail: json['site_owner_email'] as String,
      siteOwnerPhone: json['site_owner_phone'] as String,
      siteManager: json['site_manager'] as String,
      siteManagerEmail: json['site_manager_email'] as String,
      siteManagerPhone: json['site_manager_phone'] as String,
      siteInspectorName: json['site_inspector_name'] as String,
      siteInspectorEmail: json['site_inspector_email'] as String,
      siteInspectorPhone: json['site_inspector_phone'] as String,
      siteInspectorPhoto: json['site_inspector_photo'] as String,
      siteLocation: json['site_location'] as String,
      contractorEmail: json['contractor_email'] as String,
      contractorId: json['contractor_id'] as String,
      areaId: json['area_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'site_name': siteName,
      'site_owner': siteOwner,
      'site_owner_email': siteOwnerEmail,
      'site_owner_phone': siteOwnerPhone,
      'site_manager': siteManager,
      'site_manager_email': siteManagerEmail,
      'site_manager_phone': siteManagerPhone,
      'site_inspector_name': siteInspectorName,
      'site_inspector_email': siteInspectorEmail,
      'site_inspector_phone': siteInspectorPhone,
      'site_inspector_photo': siteInspectorPhoto,
      'site_location': siteLocation,
      'contractor_email': contractorEmail,
      'contractor_id': contractorId,
      'area_id': areaId,
      'created_at': createdAt.toIso8601String(),
      'description': description,
    };
  }
}
