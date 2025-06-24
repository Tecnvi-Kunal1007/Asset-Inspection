class Freelancer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String skill;
  final String? specialization;
  final int? experienceYears;
  final String? resumeUrl;
  final String? profilePhotoUrl;
  final String role;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? contractorId;

  Freelancer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.skill,
    this.specialization,
    this.experienceYears,
    this.resumeUrl,
    this.profilePhotoUrl,
    required this.role,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.contractorId,
  });

  factory Freelancer.fromJson(Map<String, dynamic> json) {
    return Freelancer(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      skill: json['skill'] as String? ?? '',
      specialization: json['specialization'] as String?,
      experienceYears: json['experience_years'] as int?,
      resumeUrl: json['resume_url'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      role: json['role'] as String? ?? 'freelancer',
      status: json['status'] as String? ?? 'active',
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
      contractorId: json['contractor_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'skill': skill,
      'specialization': specialization,
      'experience_years': experienceYears,
      'resume_url': resumeUrl,
      'profile_photo_url': profilePhotoUrl,
      'role': role,
      'status': status,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'contractor_id': contractorId,
    };
  }
} 