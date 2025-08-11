class Section {
  final String id;
  final String name;
  final String premiseId;
  final Map<String, dynamic>? data; // Changed to 'data' to match JSONB column

  Section({
    required this.id,
    required this.name,
    required this.premiseId, // premiseId is a separate field
    this.data, // JSONB data for key-value pairs, excluding name
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ??
        {}; // Extract data JSONB
    return Section(
      id: json['id'] as String,
      name: json['name'] as String? ?? '', // Separate name column
      premiseId: json['premise_id'] as String,
      data: data.isNotEmpty
          ? Map<String, dynamic>.from(data)
          : null, // Only key-value pairs
    );
  }
  
  // Convert Section to Map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'premise_id': premiseId,
      'data': data ?? {},
    };
  }
}
