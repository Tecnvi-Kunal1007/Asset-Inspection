class PremiseProduct {
  final String id;
  final String premiseId;
  final String name;
  final int quantity;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  PremiseProduct({
    required this.id,
    required this.premiseId,
    required this.name,
    required this.quantity,
    required this.details,
    required this.createdAt,
  });

  factory PremiseProduct.fromJson(Map<String, dynamic> json) {
    return PremiseProduct(
      id: json['id'] ?? '',
      premiseId: json['premise_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      details: Map<String, dynamic>.from(json['details'] ?? {}),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
