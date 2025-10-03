class Section {
  final String id;
  final String name;
  final String premiseId;
  final Map<String, dynamic>? data;
  final String? sectionQrUrl; // Only keep the new field

  Section({
    required this.id,
    required this.name,
    required this.premiseId,
    this.data,
    this.sectionQrUrl,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return Section(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      premiseId: json['premise_id'] as String,
      data: data.isNotEmpty ? Map<String, dynamic>.from(data) : null,
      sectionQrUrl: json['section_qr_url'] as String?,
    );
  }
  
  factory Section.fromMap(Map<String, dynamic> map) {
    return Section.fromJson(map);
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'premise_id': premiseId,
      'data': data ?? {},
      'section_qr_url': sectionQrUrl,
    };
  }

  // Check if section has a valid QR code
  bool get hasQrCode =>
      sectionQrUrl != null &&
      sectionQrUrl!.isNotEmpty &&
      sectionQrUrl != 'pending' &&
      Uri.tryParse(sectionQrUrl!)?.hasScheme == true;

  // Keep this for backward compatibility if needed
  String? get qrUrl => sectionQrUrl;
}
