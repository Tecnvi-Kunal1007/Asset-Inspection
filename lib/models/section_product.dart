import 'package:uuid/uuid.dart';

class SectionProduct {
  final String id;
  final String sectionId;
  final String name;
  final int quantity;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final String? photoUrl;

  SectionProduct({
    required this.id,
    required this.sectionId,
    required this.name,
    required this.quantity,
    required this.details,
    required this.createdAt,
    this.photoUrl,
  });

  factory SectionProduct.fromMap(Map<String, dynamic> map) {
    return SectionProduct(
      id: map['id'] ?? '',
      sectionId: map['section_id'] ?? '',
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
      details: Map<String, dynamic>.from(map['data'] ?? {}),
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      photoUrl: map['photo_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'section_id': sectionId,
      'name': name,
      'quantity': quantity,
      'data': details,
      'created_at': createdAt.toIso8601String(),
      'photo_url': photoUrl,
    };
  }

  /// Helper factory to create from form data
  factory SectionProduct.fromForm({
    required String sectionId,
    required String name,
    required int quantity,
    required Map<String, dynamic> details,
    String? photoUrl,
  }) {
    return SectionProduct(
      id: const Uuid().v4(),
      photoUrl: photoUrl,
      sectionId: sectionId,
      name: name,
      quantity: quantity,
      details: details,
      createdAt: DateTime.now(),
    );
  }
}
