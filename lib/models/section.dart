class Section {
  final String id;
  final String name;
  final Map<String, dynamic>? additionalData;

  Section({
    required this.id,
    required this.name,
    this.additionalData,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] as String,
      name: json['data']['name'] as String,
      additionalData: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
    );
  }
}