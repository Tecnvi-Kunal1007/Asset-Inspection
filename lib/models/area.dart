import 'package:supabase_flutter/supabase_flutter.dart';

class Area {
  final String id;
  final String name;
  final String description;
  final String contractorId;
  final String siteOwner;
  final String siteOwnerEmail;
  final String siteOwnerPhone;
  final String siteManager;
  final String siteManagerEmail;
  final String siteManagerPhone;
  final String siteLocation;
  final String contractorEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  Area({
    required this.id,
    required this.name,
    required this.description,
    required this.contractorId,
    required this.siteOwner,
    required this.siteOwnerEmail,
    required this.siteOwnerPhone,
    required this.siteManager,
    required this.siteManagerEmail,
    required this.siteManagerPhone,
    required this.siteLocation,
    required this.contractorEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Area.fromJson(Map<String, dynamic> json) {
    return Area(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      contractorId: json['contractor_id'],
      siteOwner: json['site_owner'],
      siteOwnerEmail: json['site_owner_email'],
      siteOwnerPhone: json['site_owner_phone'],
      siteManager: json['site_manager'],
      siteManagerEmail: json['site_manager_email'],
      siteManagerPhone: json['site_manager_phone'],
      siteLocation: json['site_location'],
      contractorEmail: json['contractor_email'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'contractor_id': contractorId,
      'site_owner': siteOwner,
      'site_owner_email': siteOwnerEmail,
      'site_owner_phone': siteOwnerPhone,
      'site_manager': siteManager,
      'site_manager_email': siteManagerEmail,
      'site_manager_phone': siteManagerPhone,
      'site_location': siteLocation,
      'contractor_email': contractorEmail,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
