class Product {
  final String id;
  final String premiseId; // Maps from 'subsection_id' in Supabase
  final String name;
  final int quantity;
  final Map<String, dynamic> details; // Maps from 'data' in Supabase
  final DateTime createdAt;
  final String? photoUrl;

  Product({
    required this.id,
    required this.premiseId,
    required this.name,
    required this.quantity,
    required this.details,
    required this.createdAt,
    this.photoUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      premiseId: json['subsection_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      details: Map<String, dynamic>.from(json['data'] ?? {}),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      photoUrl: json['photo_url'],
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      premiseId: map['subsection_id'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      details: Map<String, dynamic>.from(map['data'] ?? {}),
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      photoUrl: map['photo_url'],
    );
  }

  // Fixed: data getter should return details, not null
  Map<String, dynamic> get data => details;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subsection_id': premiseId,
      'name': name,
      'quantity': quantity,
      'data': details,
      'created_at': createdAt.toIso8601String(),
      'photo_url': photoUrl,
    };
  }
}
