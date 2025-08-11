import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../models/section.dart';
import '../models/subsection.dart';
import '../models/subsection_product.dart';
import '../models/section_product.dart';
import '../models/premise_product.dart';
import '../services/supabase_service.dart';

// Helper method to fetch sections with their subsections and products
Future<List<Map<String, dynamic>>> _fetchSectionsWithDetails(
  List<Section> sections,
  SupabaseService supabaseService,
) async {
  final List<Map<String, dynamic>> sectionsData = [];
  
  for (final section in sections) {
    // Fetch section products
    final sectionProducts = await supabaseService.getSectionProducts(section.id);
    
    // Fetch subsections
    final subsections = await supabaseService.getSubsections(section.id);
    final subsectionsData = <Map<String, dynamic>>[];
    
    for (final subsection in subsections) {
      // Fetch subsection products
      final subsectionProducts = await supabaseService.getSubsectionProducts(subsection.id);
      
      subsectionsData.add({
        ...subsection.toJson(),
        'products': subsectionProducts.map((product) => product.toJson()).toList(),
      });
    }
    
    sectionsData.add({
      ...section.toJson(),
      'products': sectionProducts.map((product) => product.toJson()).toList(),
      'subsections': subsectionsData,
    });
  }
  
  return sectionsData;
}

Future<String> generateAndUploadQrImage(
  String premiseId, {
  String? premiseName,
}) async {
  try {
    print('Starting QR code generation for premise: $premiseId');
    
    // Initialize Supabase service
    final supabaseService = SupabaseService();
    
    // Fetch all premise details
    final premiseDetails = await supabaseService.getPremiseDetails(premiseId);
    
    // Fetch sections
    final sections = await supabaseService.getSections(premiseId);
    final sectionsData = await _fetchSectionsWithDetails(sections, supabaseService);
    
    // Fetch premise products
    final premiseProducts = await supabaseService.getPremiseProduct(premiseId);
    
    // Create a comprehensive data object that includes all premise details
    final Map<String, dynamic> qrData = {
      'id': premiseId,
      'name': premiseName ?? premiseDetails['data']['name'] ?? 'Unknown Premise',
      'data': premiseDetails['data'],
      'sections': sectionsData,
      'products': premiseProducts.map((product) => product.toJson()).toList(),
    };

    // Convert to JSON string for QR code
    final String qrDataString = jsonEncode(qrData);

    print('QR data: $qrDataString');

    final qrValidationResult = QrValidator.validate(
      data: qrDataString,
      version: QrVersions.auto,
      errorCorrectionLevel:
          QrErrorCorrectLevel
              .M, // Medium error correction for better readability
    );

    if (qrValidationResult.status != QrValidationStatus.valid) {
      throw Exception("Invalid QR data for premise: $premiseId");
    }

    final qrCode = qrValidationResult.qrCode!;
    final painter = QrPainter.withQr(
      qr: qrCode,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
      gapless: true,
    );

    print('Generating QR image...');
    final image = await painter.toImage(300);
    final ByteData? byteData = await image.toByteData(
      format: ImageByteFormat.png,
    );
    if (byteData == null)
      throw Exception(
        'Failed to generate QR code image for premise: $premiseId',
      );
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final fileName = 'public/$premiseId.png';
    print('Uploading QR code to Supabase storage: $fileName');
    await Supabase.instance.client.storage
        .from('qr-codes')
        .uploadBinary(
          fileName,
          pngBytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );

    print('Upload completed successfully');
    final qrurl = Supabase.instance.client.storage
        .from('qr-codes')
        .getPublicUrl(fileName);
    print('Generated QR code URL: $qrurl');

    return qrurl;
  } catch (e) {
    print('Error in generateAndUploadQrImage for premise $premiseId: $e');
    rethrow; // Rethrow to ensure the error is caught in createPremise
  }
}
