import 'dart:typed_data';
import 'dart:ui';
import 'dart:convert';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/premise.dart';
import '../models/premise_product.dart';
import '../models/section_product.dart';
import '../models/subsection_product.dart';
import '../models/section.dart';
import '../models/subsection.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Product Operations by Subsection
  Future<List<Product>> getProductsBySubsectionId(String subsectionId) async {
    final response = await _supabase
        .from('subsection_products')
        .select()
        .eq('subsection_id', subsectionId);

    return response.map((json) => Product.fromJson(json)).toList();
  }

  // Premise Operations
  Future<Map<String, dynamic>> getPremiseDetails(String premiseId) async {
    final response =
        await _supabase.from('premises').select().eq('id', premiseId).single();
    return response;
  }

  Future<void> updatePremise(
    String premiseId,
    Map<String, dynamic> premiseData,
  ) async {
    await _supabase.from('premises').update(premiseData).eq('id', premiseId);
  }

  Future<void> deletePremise(String premiseId) async {
    await _supabase.from('premises').delete().eq('id', premiseId);
  }

  // QR Code Storage
  Future<String> uploadQrCode(String pumpId, File qrCodeFile) async {
    final fileExt = qrCodeFile.path.split('.').last;
    final fileName = '$pumpId.$fileExt';

    await _supabase.storage.from('qr_codes').upload(fileName, qrCodeFile);

    return _supabase.storage.from('qr_codes').getPublicUrl(fileName);
  }

  Future<String> uploadPremiseReport(
    String premiseId,
    File reportFile, {
    String? reportName,
  }) async {
    final fileExt = reportFile.path.split('.').last;
    final fileName =
        '$premiseId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _supabase.storage.from('premisereports').upload(fileName, reportFile);
    final publicUrl = _supabase.storage
        .from('premisereports')
        .getPublicUrl(fileName);

    await _supabase.from('premise_reports').insert({
      'premise_id': premiseId,
      'file_name': reportName ?? fileName,
      'url': publicUrl,
      'uploaded_at': DateTime.now().toIso8601String(),
    });

    return publicUrl;
  }

  // Add this new method to get all reports for a premise
  Future<List<Map<String, dynamic>>> getPremiseReports(String premiseId) async {
    final response = await _supabase
        .from('premise_reports')
        .select()
        .eq('premise_id', premiseId)
        .order('uploaded_at', ascending: false);

    return response;
  }

  // File Operations
  Future<void> uploadFile(String bucket, String fileName, File file) async {
    await _supabase.storage.from(bucket).upload(fileName, file);
  }

  String getFileUrl(String bucket, String fileName) {
    return _supabase.storage.from(bucket).getPublicUrl(fileName);
  }

  // Operational Tests
  Future<List<Map<String, dynamic>>> getOperationalTests(
    String premiseId,
  ) async {
    try {
      final response = await _supabase
          .from('operational_tests')
          .select()
          .eq('premise_id', premiseId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting operational tests: $e');
      rethrow;
    }
  }

  // QR Code Generation and Upload

  // Premise Operations
  Future<List<Map<String, dynamic>>> getContractors() async {
    final response = await _supabase.from('contractor').select('id, name');
    return response as List<Map<String, dynamic>>;
  }

 
  // Add these new methods for engine inspections
 

 



 
  uploadBytes(String s, String fileName, Uint8List uint8list) {}

  // qr scanning for the dyanamic premise creation

  Future<String> generateAndUploadQrImage(
    String premiseId, {
    String? premiseName,
  }) async {
    try {
      // Create a data object that includes both the ID and name
      final Map<String, dynamic> qrData = {
        'id': premiseId,
        'name': premiseName ?? 'Unknown Premise',
      };

      // Convert to JSON string for QR code
      final String qrDataString = jsonEncode(qrData);

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

      // Generate QR code image
      final image = await painter.toImage(300);
      final ByteData? byteData = await image.toByteData(
        format: ImageByteFormat.png,
      );
      if (byteData == null) throw Exception('Failed to generate QR code image');
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Upload to Supabase Storage
      final fileName = 'public/$premiseId.png';

      // First try to remove any existing file to avoid duplicate errors
      try {
        await Supabase.instance.client.storage.from('qr-codes').remove([
          fileName,
        ]);
        print('Removed existing QR code file');
      } catch (e) {
        // It's okay if the file doesn't exist yet
        print('No existing QR code file to remove or error removing: $e');
      }

      // Now upload the new file
      await Supabase.instance.client.storage
          .from('qr-codes')
          .uploadBinary(
            fileName,
            pngBytes,
            fileOptions: const FileOptions(contentType: 'image/png'),
          );

      // Return public URL
      final publicUrl = Supabase.instance.client.storage
          .from('qr-codes')
          .getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print('Error generating or uploading QR code: $e');
      throw Exception('Failed to generate or upload QR code: $e');
    }
  }

  final SupabaseClient _client = Supabase.instance.client;

  Future<Premise> createPremise(
    String contractorId,
    Map<String, dynamic> data, {
    required String name,
    required Map additionalData,
  }) async {
    try {
      print('Creating premise for contractor: $contractorId');
      // Insert the premise with a placeholder qr_url to satisfy NOT NULL
      final response =
          await _supabase
              .from('premises')
              .insert({
                'contractor_id': contractorId,
                'name': data['name'],
                'data': data,
                'qr_url': 'pending', // Placeholder to satisfy NOT NULL
              })
              .select('id, contractor_id, data, contractor(name)')
              .single();

      final premiseId = response['id'] as String;
      print('Premise created with ID: $premiseId');

      // Generate and upload QR code
      String qrUrl;
      try {
        print(
          'Generating and uploading QR code for premise: $premiseId with name: ${data['name']}',
        );
        qrUrl = await generateAndUploadQrImage(
          premiseId,
          premiseName: data['name'],
        );
        print('Successfully generated QR URL: $qrUrl');
      } catch (e) {
        print(
          'Error generating or uploading QR code for premise $premiseId: $e',
        );
        qrUrl = 'pending'; // Fallback value
      }

      // Update the premise with the QR URL
      print('Updating premise $premiseId with qr_url: $qrUrl');
      final updateResponse = await _supabase
          .from('premises')
          .update({'qr_url': qrUrl})
          .eq('id', premiseId)
          .select('id, qr_url'); // Select to verify update
      print('Update response: $updateResponse');

      // Fetch the updated premise
      final updatedResponse =
          await _supabase
              .from('premises')
              .select('id, contractor_id, data, qr_url, contractor(name)')
              .eq('id', premiseId)
              .single();

      final contractor =
          updatedResponse['contractor'] as Map<String, dynamic>? ??
          {'name': 'Unknown'};
      final premise = Premise.fromMap({
        ...updatedResponse,
        'contractor_name': contractor['name'],
      });

      print('Premise retrieved with QR URL: ${premise.qr_Url}');
      return premise;
    } catch (e) {
      print('Error in createPremise: $e');
      throw Exception('Failed to create premise: $e');
    }
  }

  Future<List<Premise>> getPremises() async {
    try {
      final response = await _supabase
          .from('premises')
          .select('id, contractor_id, data, contractor(name)')
          .order('created_at', ascending: false);
      return response.map((map) {
        final contractor =
            map['contractor'] as Map<String, dynamic>? ?? {'name': 'Unknown'};
        return Premise.fromMap({...map, 'contractor_name': contractor['name']});
      }).toList();
    } catch (e) {
      throw Exception('Error fetching premises: $e');
    }
  }

  Future<List<Section>> getSections(String premiseId) async {
    final response = await Supabase.instance.client
        .from('sections')
        .select()
        .eq('premise_id', premiseId);
    return response.map((data) => Section.fromJson(data)).toList();
  }

  // Additional method to regenerate QR code if needed
  Future<String> regenerateQrCode(String premiseId) async {
    try {
      // First, get the premise details to include the name in the QR code
      final premiseResponse =
          await _client
              .from('premises')
              .select('id, data')
              .eq('id', premiseId)
              .single();

      final premiseData = premiseResponse['data'] as Map<String, dynamic>;
      final premiseName = premiseData['name'] as String? ?? 'Unknown Premise';

      // Generate QR code with premise name included
      final qrUrl = await generateAndUploadQrImage(
        premiseId,
        premiseName: premiseName,
      );

      // Update the premise with the new QR URL
      await _client
          .from('premises')
          .update({'qr_url': qrUrl})
          .eq('id', premiseId);

      return qrUrl;
    } catch (e) {
      print('Error in regenerateQrCode: $e');
      throw Exception('Failed to regenerate QR code: $e');
    }
  }

  // Future<List<Section>> getSections(String premiseId) async {
  //   final response = await Supabase.instance.client
  //       .from('sections')
  //       .select()
  //       .eq('premise_id', premiseId);
  //   return response.map((data) => Section.fromJson(data)).toList();
  // }

  Future<void> createSection(
    String premiseId,
    Map<String, dynamic> data,
  ) async {
    await Supabase.instance.client.from('sections').insert({
      'premise_id': premiseId,
      'name': data['name'],
      'data': data,
    });
  }

  Future<void> updateSection(
    String sectionId,
    Map<String, dynamic> data,
  ) async {
    await Supabase.instance.client
        .from('sections')
        .update({'data': data})
        .eq('id', sectionId);
  }

  // Subsections
  Future<List<Subsection>> getSubsections(String sectionId) async {
    try {
      final response = await _supabase
          .from('subsections')
          .select('id, section_id, name, data')
          .eq('section_id', sectionId)
          .order('created_at', ascending: false);

      return response.map((map) => Subsection.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Error fetching subsections: $e');
    }
  }

  Future<Subsection> createSubsection(
    String sectionId,
    Map<String, dynamic> data,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response =
          await _supabase
              .from('subsections')
              .insert({
                'section_id': sectionId,
                'name': data['name'],
                'data': data,
              })
              .select('id, section_id, name, data')
              .single();

      return Subsection.fromMap(response);
    } catch (e) {
      throw Exception('Error creating subsection: $e');
    }
  }

  // Products
  Future<List<Product>> getProducts(String subsectionId) async {
    try {
      final response = await _supabase
          .from('subsections_products')
          .select('id, subsection_id, name, data, created_at')
          .eq('subsection_id', subsectionId)
          .order('created_at', ascending: false);

      return response.map((map) => Product.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Error fetching products: $e');
    }
  }

  Future<List<SectionProduct>> getSectionProducts(String sectionId) async {
    final response = await _supabase
        .from('section_products')
        .select()
        .eq('section_id', sectionId)
        .order('created_at', ascending: false);

    if (response != null && response is List) {
      return response
          .map((map) => SectionProduct.fromMap(map as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<void> createSectionProduct(SectionProduct product) async {
    final response = await Supabase.instance.client
        .from(
          'section_products',
        ) // Make sure this matches your Supabase table name
        .insert({
          'id':
              product
                  .id, // You can use `uuid` from Dart if you generate manually
          'section_id': product.sectionId,
          'name': product.name,
          'quantity': product.quantity,
          'data': product.details,
          'created_at':
              product.createdAt
                  .toIso8601String(), // Optional, Supabase can auto-generate this
        });

    if (response != null && response.error != null) {
      throw Exception(
        'Failed to create section product: ${response.error!.message}',
      );
    }
  }

  Future<Product> createProduct(
    String subsectionId,
    Map<String, dynamic> data,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response =
          await _supabase
              .from('subsections_products')
              .insert({
                'subsection_id': subsectionId,
                'name': data['name'],
                'data': data,
              })
              .select('id, subsection_id, name, data, created_at')
              .single();

      return Product.fromMap(response);
    } catch (e) {
      throw Exception('Error creating product: $e');
    }
  }

  getProductsBySection(String id) {}

  Future<void> createPremiseProduct(
    String premiseId,
    Map<String, dynamic> data,
  ) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('premise_products').insert({
      'contractor_id': user.id,
      'premise_id': premiseId,
      'name': data['name'],
      'quantity': data['quantity'],
      'details': data['details'], // JSON type: can contain any key-values
    });
  }

  Future<List<PremiseProduct>> getProductsByPremise(String premiseId) async {
    final response = await _supabase
        .from('premise_products')
        .select()
        .eq('premise_id', premiseId)
        .order('created_at', ascending: false);

    final data = response as List;
    return data.map((json) => PremiseProduct.fromJson(json)).toList();
  }

  fetchProductsByPremise(String id) {}
}
