class Premise {
  final String id;
  final String contractorId;
  final String name;
  final Map<String, dynamic> additionalData;
  final String contractorName;
  final String? qr_Url; // Added QR URL field
  final List<dynamic>? sections; // Sections with subsections and products
  final List<dynamic>? products; // Premise-level products
  final DateTime createdAt; // Added to match Supabase schema

  Premise({
    required this.id,
    required this.contractorId,
    required this.name,
    required this.additionalData,
    required this.contractorName,
    this.qr_Url, // Made optional since it might be null initially
    this.sections,
    this.products,
    required this.createdAt,
  });

  factory Premise.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as Map<String, dynamic>? ?? {};
    return Premise(
      id: map['id']?.toString() ?? '',
      contractorId: map['contractor_id']?.toString() ?? '',
      name: map['name'] as String? ?? data['name'] as String? ?? '',
      additionalData: Map<String, dynamic>.from(data)..remove('name'),
      contractorName: map['contractor_name'] as String? ?? map['contractor']?['name'] as String? ?? 'Unknown',
      qr_Url: map['qr_url'] != null
          ? map['qr_url'] as String
          : (map['qrUrl'] != null ? map['qrUrl'] as String : null), // Extract QR URL with improved null handling
      sections: map['sections'] as List<dynamic>?,
      products: map['products'] as List<dynamic>?,
      createdAt: DateTime.parse(map['created_at'] as String), // Parse created_at timestamp
    );
  }

  // Convert Premise to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contractor_id': contractorId,
      'data': {'name': name, ...additionalData},
      'contractor_name': contractorName,
      'qr_url': qr_Url,
      'sections': sections,
      'products': products,
      'created_at': createdAt.toIso8601String(), // Include created_at for updates
    };
  }

  // Create a copy of the premise with updated fields
  Premise copyWith({
    String? id,
    String? contractorId,
    String? name,
    Map<String, dynamic>? additionalData,
    String? contractorName,
    String? qrUrl,
    DateTime? createdAt,
  }) {
    return Premise(
      id: id ?? this.id,
      contractorId: contractorId ?? this.contractorId,
      name: name ?? this.name,
      additionalData: additionalData ?? this.additionalData,
      contractorName: contractorName ?? this.contractorName,
      qr_Url: qrUrl ?? this.qr_Url,
      sections: sections,
      products: products,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Convenience getter for location (commonly used additional data)
  String? get location => additionalData['location'] as String?;

  // Check if premise has a valid QR code
  bool get hasQrCode =>
      qr_Url != null &&
          qr_Url!.isNotEmpty &&
          Uri.tryParse(qr_Url!)?.hasScheme == true;

  @override
  String toString() {
    return 'Premises{id: $id, name: $name, contractorName: $contractorName, location: $location, hasQrCode: $hasQrCode, createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Premise && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}