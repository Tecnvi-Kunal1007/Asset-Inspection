import 'package:postgrest/src/types.dart';

class Subsection {
  final String id;
  final String sectionId;
  final String name;
  final Map<String, dynamic>? additionalData;
  final String contractorName;

  Subsection({
    required this.id,
    required this.sectionId,
    required this.name,
    this.additionalData,
    required this.contractorName,
  });

  factory Subsection.fromMap(Map<String, dynamic> map) {
    final contractorMap = map['contractors'] as Map<String, dynamic>?;
    final contractorName = contractorMap != null
        ? contractorMap['name'] as String? ?? 'Unknown'
        : 'Unknown';

    return Subsection(
      id: map['id'] as String,
      sectionId: map['section_id'] as String,
      name: map['name'] as String,
      additionalData: map['data'] != null
          ? Map<String, dynamic>.from(map['data'])
          : null,
      contractorName: contractorName,
    );
  }


}
