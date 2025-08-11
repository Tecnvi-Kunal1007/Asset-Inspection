class PremiseProduct {
  final String id;
  final String premiseId;
  final String name;
  final int quantity;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final String? photoUrl;

  PremiseProduct({
    required this.id,
    required this.premiseId,
    required this.name,
    required this.quantity,
    required this.details,
    required this.createdAt,
    this.photoUrl,
  });

  factory PremiseProduct.fromJson(Map<String, dynamic> json) {
    return PremiseProduct(
      id: json['id'] ?? '',
      premiseId: json['premise_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      details: Map<String, dynamic>.from(json['details'] ?? {}),
      createdAt: DateTime.parse(json['created_at']),
      photoUrl: json['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'premise_id': premiseId,
      'name': name,
      'quantity': quantity,
      'details': details,
      'created_at': createdAt.toIso8601String(),
      'photo_url': photoUrl,
    };
  }
}
