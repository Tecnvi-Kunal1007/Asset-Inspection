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
    // Section QR generation
    await Supabase.instance.client.storage
        .from('qr-codes')  // ← This bucket name
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

// Add these functions to your existing qr_generator.dart file

// Generate QR code for Section using new bucket
Future<String> generateAndUploadSectionQrImage(
  String sectionId, {
  required String premiseId,
  String? sectionName,
}) async {
  try {
    print('Starting QR code generation for section: $sectionId');
    
    final supabaseService = SupabaseService();
    
    // Use getSections with premiseId to find the specific section
    final sections = await supabaseService.getSections(premiseId);
    final section = sections.firstWhere(
      (s) => s.id == sectionId,
      orElse: () => throw Exception('Section not found: $sectionId')
    );
    
    if (section == null) {
      throw Exception('Section not found: $sectionId');
    }
    
    // Fetch subsections with their products
    final subsections = await supabaseService.getSubsections(sectionId);
    final subsectionsData = <Map<String, dynamic>>[];
    
    for (final subsection in subsections) {
      final subsectionProducts = await supabaseService.getSubsectionProducts(subsection.id);
      subsectionsData.add({
        ...subsection.toJson(),
        'products': subsectionProducts.map((product) => product.toJson()).toList(),
      });
    }
    
    // Fetch section products
    final sectionProducts = await supabaseService.getSectionProducts(sectionId);
    
    final Map<String, dynamic> qrData = {
      'type': 'section',
      'id': sectionId,
      'name': sectionName ?? section.name,
      'data': section.toJson(),
      'subsections': subsectionsData,
      'products': sectionProducts.map((product) => product.toJson()).toList(),
    };

    final String qrDataString = jsonEncode(qrData);
    
    // Generate QR code image (same logic as premise)
    final qrValidationResult = QrValidator.validate(
      data: qrDataString,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );

    if (qrValidationResult.status != QrValidationStatus.valid) {
      throw Exception("Invalid QR data for section: $sectionId");
    }

    final qrCode = qrValidationResult.qrCode!;
    final painter = QrPainter.withQr(
      qr: qrCode,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
      gapless: true,
    );

    final image = await painter.toImage(300);
    final ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to generate QR code image for section: $sectionId');
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    // Upload to the new section_qr bucket
    final fileName = 'sections/$sectionId.png';
    
    // First try to remove any existing file
    try {
      await Supabase.instance.client.storage.from('section_qr').remove([
        fileName,
      ]);
      print('Removed existing section QR code file');
    } catch (e) {
      print('No existing section QR code file to remove or error removing: $e');
    }
    
    // Upload to new section_qr bucket
    await Supabase.instance.client.storage
        .from('section_qr')  // ← Use new bucket name
        .uploadBinary(
          fileName,
          pngBytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );

    // Get public URL from new bucket
    final qrUrl = Supabase.instance.client.storage
        .from('section_qr')  // ← Use new bucket name
        .getPublicUrl(fileName);
    
    return qrUrl;
  } catch (e) {
    print('Error in generateAndUploadSectionQrImage for section $sectionId: $e');
    rethrow;
  }
}

// Generate QR code for Subsection
Future<String> generateAndUploadSubsectionQrImage(
  String subsectionId, {
  String? subsectionName,
}) async {
  try {
    print('Starting QR code generation for subsection: $subsectionId');
    
    final supabaseService = SupabaseService();
    
    // Fetch subsection details
    final subsection = await supabaseService.getSubsectionById(subsectionId);
    
    if (subsection == null) {
      throw Exception('Subsection not found: $subsectionId');
    }
    
    // Fetch subsection products
    final subsectionProducts = await supabaseService.getSubsectionProducts(subsectionId);
    
    final Map<String, dynamic> qrData = {
      'type': 'subsection',
      'id': subsectionId,
      'name': subsectionName ?? subsection.name,
      'data': subsection.toJson(),
      'products': subsectionProducts.map((product) => product.toJson()).toList(),
    };

    final String qrDataString = jsonEncode(qrData);
    
    // Generate QR code image
    final qrValidationResult = QrValidator.validate(
      data: qrDataString,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );

    if (qrValidationResult.status != QrValidationStatus.valid) {
      throw Exception("Invalid QR data for subsection: $subsectionId");
    }

    final qrCode = qrValidationResult.qrCode!;
    final painter = QrPainter.withQr(
      qr: qrCode,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
      gapless: false,
    );

    final picData = await painter.toImageData(512, format: ImageByteFormat.png);
    final pngBytes = picData!.buffer.asUint8List();

    // Upload to subsection_qr bucket
    final fileName = 'subsections/$subsectionId.png';
    
    // Remove existing file if it exists
    try {
      await Supabase.instance.client.storage
          .from('subsection_qr')
          .remove([fileName]);
    } catch (e) {
      print('File $fileName does not exist or could not be removed: $e');
    }

    // Upload new file to subsection_qr bucket
    await Supabase.instance.client.storage
        .from('subsection_qr')
        .uploadBinary(
          fileName,
          pngBytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );

    // Get public URL from subsection_qr bucket
    final qrUrl = Supabase.instance.client.storage
        .from('subsection_qr')
        .getPublicUrl(fileName);
    
    return qrUrl;
  } catch (e) {
    print('Error in generateAndUploadSubsectionQrImage for subsection $subsectionId: $e');
    rethrow;
  }
}
