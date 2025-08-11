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
import '../models/assignment.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'dart:convert';

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
          .select('id, contractor_id, data, qr_url, contractor(name)')
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

  // Future<List<Section>> getSections(String premiseId) async {
  //   final response = await Supabase.instance.client
  //       .from('sections')
  //       .select()
  //       .eq('premise_id', premiseId);
  //   return response.map((data) => Section.fromJson(data)).toList();
  // }

  Future<void> createSection(String premiseId, Map<String, dynamic> data) async {
    final name = data['name'] as String?;
    final dataMap = data['data'] as Map<String, dynamic>? ?? {};

    await Supabase.instance.client
        .from('sections')
        .insert({
      'premise_id': premiseId,
      'name': name,
      'data': dataMap
    });
  }

  Future<dynamic> updateSection(String sectionId, Map<String, dynamic> data) async {
    final name = data['name'] as String?;
    final dataMap = data['data'] as Map<String, dynamic>? ?? {};

    final updatePayload = {
      'name': name,
      'data': dataMap.isNotEmpty ? dataMap : null, // JSONB column for key-value pairs
    };

    print('updateSection: Updating section $sectionId with payload: $updatePayload');

    try {
      final response = await Supabase.instance.client
          .from('sections')
          .update(updatePayload)
          .eq('id', sectionId)
          .select()
          .single();
      print('updateSection: Response: $response');
      return response;
    } catch (e) {
      print('updateSection: Error - $e');
      throw e;
    }
  }


  // Subsections
  Future<List<Subsection>> getSubsections(String sectionId) async {
    try {
      final response = await _supabase
          .from('subsections')
          .select('id, section_id, name, data') // Include name column
          .eq('section_id', sectionId);

      if (response == null || response.isEmpty) return [];

      // Ensure we're working with a List<Map<String, dynamic>>
      final List<Map<String, dynamic>> subsectionsList = List<Map<String, dynamic>>.from(response);

      return subsectionsList.map((map) => Subsection.fromJson(map)).toList();
    } catch (e) {
      print('Error in getSubsections: $e');
      throw Exception('Failed to get subsections: $e');
    }
  }


  Future<void> createSubsection(String sectionId, Map<String, dynamic> data) async {
    try {
      final subsectionData = data['data'] as Map<String, dynamic>? ?? {};
      final name = subsectionData['name'] as String? ?? '';
      if (name.isEmpty) {
        throw Exception('Subsection name is required');
      }

      // Create a copy of the data to avoid modifying the original
      final Map<String, dynamic> dataToInsert = Map<String, dynamic>.from(subsectionData);

      // Remove name from the data map since it's stored in a separate column
      dataToInsert.remove('name');

      await _supabase.from('subsections').insert({
        'section_id': sectionId,
        'name': name, // Store name in its own column
        'data': dataToInsert.isNotEmpty ? dataToInsert : null, // Store other properties in data
      });
    } catch (e) {
      print('Error creating subsection: $e');
      if (e.toString().contains('duplicate key value violates unique constraint')) {
        throw Exception('A subsection with this name already exists in the section.');
      }
      throw Exception('Failed to create subsection: $e');
    }
  }

  Future<Subsection> updateSubsection(String subsectionId, Map<String, dynamic> data) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Extract name from data
      final String name = data['name'] as String? ?? '';
      if (name.isEmpty) {
        throw Exception('Subsection name is required');
      }

      // Create a copy of the data to avoid modifying the original
      final Map<String, dynamic> dataToUpdate = Map<String, dynamic>.from(data);

      // Remove name from the data map since it's stored in a separate column
      dataToUpdate.remove('name');

      final updatePayload = {
        'name': name, // Store name in its own column
        'data': dataToUpdate.isNotEmpty ? dataToUpdate : null, // Store other properties in data
      };

      print('updateSubsection: Updating subsection $subsectionId with payload: $updatePayload');

      final response = await _supabase
          .from('subsections')
          .update(updatePayload)
          .eq('id', subsectionId)
          .select('id, section_id, name, data')
          .single();

      print('updateSubsection: Response: $response');
      return Subsection.fromJson(response);
    } catch (e) {
      print('updateSubsection: Error - $e');
      throw Exception('Error updating subsection: $e');
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
  
  // Alias for getProducts to match naming convention in QR generator
  Future<List<Product>> getSubsectionProducts(String subsectionId) async {
    return getProducts(subsectionId);
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
        .from('section_products') // Make sure this matches your Supabase table name
        .insert({
      'id': product.id, // You can use `uuid` from Dart if you generate manually
      'section_id': product.sectionId,
      'name': product.name,
      'quantity': product.quantity,
      'data': product.details,
      'created_at': product.createdAt.toIso8601String(), // Optional, Supabase can auto-generate this
    });

    if (response != null && response.error != null) {
      throw Exception('Failed to create section product: ${response.error!.message}');
    }
  }

  Future<dynamic> updateSectionProduct(String sectionId, Map<String, dynamic> data) async {
    final name = data['name'] as String?;
    final dataMap = data['data'] as Map<String, dynamic>? ?? {};

    final updatePayload = {
      'name': name,
      'data': dataMap.isNotEmpty ? dataMap : null, // JSONB column for key-value pairs
    };

    print('updateSectionProduct: Updating section Product $sectionId with payload: $updatePayload');

    try {
      final response = await Supabase.instance.client
          .from('SectionProduct')
          .update(updatePayload)
          .eq('id', sectionId)
          .select()
          .single();
      print('updateSectionProduct: Response: $response');
      return response;
    } catch (e) {
      print('updateSectionProduct: Error - $e');
      throw e;
    }
  }


  Future<Product> createProduct(String subsectionId, Map<String, dynamic> data) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.from('subsections_products').insert({
        'subsection_id': subsectionId,
        'name': data['name'],
        'data': data,
      }).select('id, subsection_id, name, data, created_at').single();

      return Product.fromMap(response);
    } catch (e) {
      throw Exception('Error creating product: $e');
    }
  }

  Future<Product?> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.from('subsections_products').update({
        'name': data['name'],
        'data': data,
      }).eq('id', productId).select('id, subsection_id, name, data, created_at').single();

      return Product.fromMap(response);
    } catch (e) {
      print('Error updating product: $e');
      return null;
    }
  }


  getProductsBySection(String id) {}

  Future<void> createPremiseProduct(String premiseId, Map<String, dynamic> data) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    await _supabase.from('premise_products').insert({
      'contractor_id': user.id,
      'premise_id': premiseId,
      'name': data['name'],
      'quantity': data['quantity'],
      'details': data['details'],  // JSON type: can contain any key-values
    });
  }
// get products by premise
  Future<List<PremiseProduct>> getPremiseProduct(String premiseId) async {
    final response = await _supabase
        .from('premise_products')
        .select()
        .eq('premise_id', premiseId)
        .order('created_at', ascending: false);

    final data = response as List;
    return data.map((json) => PremiseProduct.fromJson(json)).toList();
  }

  // update product
  Future<Product?> updatePremiseProduct(String productId, Map<String, dynamic> data) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final response = await _supabase.from('premise_products').update({
        'name': data['name'],
        'data': data,
      }).eq('id', productId).select('id, premise_id, name, data, created_at').single();

      return Product.fromMap(response);
    } catch (e) {
      print('Error updating product: $e');
      return null;
    }
  }


  fetchProductsByPremise(String id) {}

  // Assignment Operations
  Future<bool> assignFreelancerToPremise({
    required String premiseId,
    required String freelancerId,
    required String freelancerName,
    required List<String> tasks,
  }) async {
    try {
      // Get current assignments
      final response =
          await _supabase
              .from('premises')
              .select('assignments')
              .eq('id', premiseId)
              .single();

      Map<String, dynamic> currentAssignments = Map<String, dynamic>.from(
        response['assignments'] ?? {},
      );

      // Create new assignment
      final assignment = {
        'freelancer_id': freelancerId,
        'freelancer_name': freelancerName,
        'tasks': tasks,
        'assigned_date': DateTime.now().toIso8601String(),
      };

      // Add assignment
      currentAssignments[freelancerId] = assignment;

      // Update premise
      await _supabase
          .from('premises')
          .update({'assignments': currentAssignments})
          .eq('id', premiseId);

      return true;
    } catch (e) {
      print('Error assigning freelancer to premise: $e');
      return false;
    }
  }

  Future<bool> removeAssignment({
    required String premiseId,
    required String freelancerId,
  }) async {
    try {
      // Get current assignments
      final response =
          await _supabase
              .from('premises')
              .select('assignments')
              .eq('id', premiseId)
              .single();

      Map<String, dynamic> currentAssignments = Map<String, dynamic>.from(
        response['assignments'] ?? {},
      );

      // Remove assignment
      currentAssignments.remove(freelancerId);

      // Update premise
      await _supabase
          .from('premises')
          .update({'assignments': currentAssignments})
          .eq('id', premiseId);

      return true;
    } catch (e) {
      print('Error removing assignment: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getPremiseAssignments(String premiseId) async {
    try {
      final response =
          await _supabase
              .from('premises')
              .select('id, name, assignments')
              .eq('id', premiseId)
              .single();

      return {
        'premise_id': response['id'],
        'premise_name': response['name'],
        'assignments': response['assignments'] ?? {},
      };
    } catch (e) {
      print('Error getting premise assignments: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllAssignments() async {
    try {
      final response = await _supabase
          .from('premises')
          .select('id, name, assignments, contractor_id')
          .neq('assignments', '{}')
          .order('created_at', ascending: false);

      return response.where((premise) {
        final assignments =
            premise['assignments'] as Map<String, dynamic>? ?? {};
        return assignments.isNotEmpty;
      }).toList();
    } catch (e) {
      print('Error getting all assignments: $e');
      return [];
    }
  }
}
