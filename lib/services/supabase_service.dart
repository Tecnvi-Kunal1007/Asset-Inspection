import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'qr_generator.dart';
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

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  // Product Operations by Subsection
  Future<List<Product>> getProductsBySubsectionId(String subsectionId) async {
    final response = await _supabase
        .from('subsections_products')
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

    await _supabase.storage.from('qr-codes').upload(fileName, qrCodeFile);  // Changed from 'qr_codes' to 'qr-codes'

    return _supabase.storage.from('qr-codes').getPublicUrl(fileName);  // Changed from 'qr_codes' to 'qr-codes'
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
        String? premiseName, required sectionName,
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
      // Premise QR generation
      await Supabase.instance.client.storage
          .from('qr-codes')  // ← This bucket name
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
          premiseName: data['name'], sectionName: null,
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


  // Add this new method to get a subsection by its ID
  Future<Subsection?> getSubsectionById(String subsectionId) async {
    try {
      final response = await _supabase
          .from('subsections')
          .select()
          .eq('id', subsectionId)
          .single();
      return Subsection.fromJson(response);
    } catch (e) {
      print('Error getting subsection by ID $subsectionId: $e');
      return null;
    }
  }

  // Future<void> createSection(String premiseId, Map<String, dynamic> data) async {
  //   final name = data['name'] as String?;
  //   final dataMap = data['data'] as Map<String, dynamic>? ?? {};
  //
  //   await Supabase.instance.client
  //       .from('sections')
  //       .insert({
  //     'premise_id': premiseId,
  //     'name': name,
  //     'data': dataMap
  //   });
  // }


  Future<Section> createSection(
      String premiseId,
      Map<String, dynamic> data, {
        required String name,
        required Map additionalData,
      }) async {
    try {
      print('Creating section for premise: $premiseId');
      // Insert the section with placeholder for new column
      final response = await _supabase
          .from('sections')
          .insert({
        'premise_id': premiseId,
        'name': data['name'],
        'data': data,
        'section_qr_url': 'pending', // Only use new column
      })
          .select('id, premise_id, data, premise(name)') // Remove qr_url reference
          .single();

      final sectionId = response['id'] as String;
      print('Section created with ID: $sectionId');

      // Generate and upload QR code to new bucket
      String sectionQrUrl;
      try {
        print(
          'Generating and uploading QR code for section: $sectionId with name: ${data['name']}',
        );
        sectionQrUrl = await generateAndUploadSectionQrImage(
          sectionId,
          premiseId: premiseId,
          sectionName: data['name'],
        );
        print('Successfully generated section QR URL: $sectionQrUrl');
      } catch (e) {
        print(
          'Error generating or uploading section QR code for section $sectionId: $e',
        );
        sectionQrUrl = 'pending'; // Fallback value
      }

      // Update the section with the new QR URL
      print('Updating section $sectionId with section_qr_url: $sectionQrUrl');
      final updateResponse = await _supabase
          .from('sections')
          .update({'section_qr_url': sectionQrUrl})
          .eq('id', sectionId)
          .select('id, section_qr_url'); // Only select new column
      print('Update response: $updateResponse');

      // Fetch the updated section with new column only
      final updatedResponse = await _supabase
          .from('sections')
          .select('id, premise_id, data, section_qr_url, premise(name)') // Remove qr_url
          .eq('id', sectionId)
          .single();

      final premise =
          updatedResponse['premises'] as Map<String, dynamic>? ??
              {'name': 'Unknown'};
      final section = Section.fromMap({
        ...updatedResponse,
        'premise_name': premise['name'],
      });

      print('Section retrieved with section QR URL: ${section.sectionQrUrl}'); // Use new field
      return section;
    } catch (e) {
      print('Error in createSection: $e');
      throw Exception('Failed to create section: $e');
    }
  }

  Future<List<Section>> getSections(String premiseId) async {
    try {
      final response = await _supabase
          .from('sections')
          .select('id, premise_id, name, data, section_qr_url, premises(name)') // Added 'name' field
          .eq('premise_id', premiseId)
          .order('created_at', ascending: false);
      return response.map((map) {
        final premise =
            map['premises'] as Map<String, dynamic>? ?? {'name': 'Unknown'};
        return Section.fromMap({...map, 'premise_name': premise['name']});
      }).toList();
    } catch (e) {
      throw Exception('Error fetching sections: $e');
    }
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
          .select('id, section_id, name, data, subsection_qr_url') // Added subsection_qr_url field
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

  // Create section with QR code - Updated to use section_qr_url
  Future<Section> createSectionWithQr(
      String premiseId,
      Map<String, dynamic> data,
      ) async {
    try {
      print('Creating section for premise: $premiseId');
      // Insert the section with a placeholder section_qr_url
      final response = await _supabase
          .from('sections')
          .insert({
        'premise_id': premiseId,
        'name': data['name'],
        'data': data,
        'section_qr_url': 'pending', // Use new column
      })
          .select('id, premise_id, name, data')
          .single();

      final sectionId = response['id'] as String;
      print('Section created with ID: $sectionId');

      // Generate and upload QR code
      String sectionQrUrl;
      try {
        print(
          'Generating and uploading QR code for section: $sectionId with name: ${data['name']}',
        );
        sectionQrUrl = await generateAndUploadSectionQrImage(
          sectionId,
          premiseId: premiseId,
          sectionName: data['name'],
        );
        print('Successfully generated section QR URL: $sectionQrUrl');
      } catch (e) {
        print(
          'Error generating or uploading QR code for section $sectionId: $e',
        );
        sectionQrUrl = 'pending'; // Fallback value
      }

      // Update the section with the QR URL
      print('Updating section $sectionId with section_qr_url: $sectionQrUrl');
      final updateResponse = await _supabase
          .from('sections')
          .update({'section_qr_url': sectionQrUrl})
          .eq('id', sectionId)
          .select('id, section_qr_url'); // Select new column
      print('Update response: $updateResponse');

      // Fetch the updated section with new column
      final updatedResponse = await _supabase
          .from('sections')
          .select('id, premise_id, name, data, section_qr_url, created_at')
          .eq('id', sectionId)
          .single();

      final section = Section.fromJson(updatedResponse);
      print('Section retrieved with section QR URL: ${section.sectionQrUrl}');
      return section;
    } catch (e) {
      print('Error in createSectionWithQr: $e');
      throw Exception('Failed to create section with QR: $e');
    }
  }

  // Create subsection with QR code - Updated to match createPremise pattern
  Future<Subsection> createSubsectionWithQr(
      String sectionId,
      Map<String, dynamic> data,
      ) async {
    try {
      print('Creating subsection for section: $sectionId');

      // Extract name from the nested data structure
      final dataMap = data['data'] as Map<String, dynamic>? ?? {};
      final subsectionName = dataMap['name'] as String? ?? '';

      if (subsectionName.isEmpty) {
        throw Exception('Subsection name is required');
      }

      // Insert the subsection with a placeholder subsection_qr_url
      final response = await _supabase
          .from('subsections')
          .insert({
        'section_id': sectionId,
        'name': subsectionName, // Use extracted name
        'data': dataMap, // Use the inner data map
        'subsection_qr_url': 'pending',
      })
          .select('id, section_id, name, data')
          .single();

      final subsectionId = response['id'] as String;
      print('Subsection created with ID: $subsectionId');

      // Generate and upload QR code
      String qrUrl;
      try {
        print(
          'Generating and uploading QR code for subsection: $subsectionId with name: $subsectionName',
        );
        qrUrl = await generateAndUploadSubsectionQrImage(
          subsectionId,
          subsectionName: subsectionName, // Use extracted name
        );
        print('Successfully generated QR URL: $qrUrl');
      } catch (e) {
        print(
          'Error generating or uploading QR code for subsection $subsectionId: $e',
        );
        qrUrl = 'pending'; // Fallback value
      }

      // Update the subsection with the QR URL
      print('Updating subsection $subsectionId with subsection_qr_url: $qrUrl');
      final updateResponse = await _supabase
          .from('subsections')
          .update({'subsection_qr_url': qrUrl})
          .eq('id', subsectionId)
          .select('id, subsection_qr_url');
      print('Update response: $updateResponse');

      // Fetch the updated subsection
      final updatedResponse = await _supabase
          .from('subsections')
          .select('id, section_id, name, data, subsection_qr_url, created_at')
          .eq('id', subsectionId)
          .single();

      final subsection = Subsection.fromJson(updatedResponse);
      print('Subsection retrieved with QR URL: ${subsection.qrUrl}');
      return subsection;
    } catch (e) {
      print('Error in createSubsectionWithQr: $e');
      throw Exception('Failed to create subsection with QR: $e');
    }
  }



  // Simple QR test method - FIXED
  Future<void> simpleQrTest() async {
    try {
      print('=== Simple QR Test Start ===');

      // Test 1: Check authentication
      final user = Supabase.instance.client.auth.currentUser;
      print('Current user: ${user?.id ?? "Not authenticated"}');

      // Test 2: Check bucket access
      print('Testing bucket access...');
      final buckets = await Supabase.instance.client.storage.listBuckets();
      final qrBucket = buckets.where((b) => b.name == 'qr-codes').toList();
      print('QR bucket found: ${qrBucket.isNotEmpty}');

      if (qrBucket.isEmpty) {
        print('ERROR: qr-codes bucket does not exist!');
        return;
      }

      // Test 3: Try to upload a simple test file
      print('Testing file upload...');
      final testContent = 'test-${DateTime.now().millisecondsSinceEpoch}';
      final testBytes = Uint8List.fromList(testContent.codeUnits);

      try {
        await Supabase.instance.client.storage
            .from('qr-codes')
            .uploadBinary(
          'test/simple-test.txt',
          testBytes,
          fileOptions: const FileOptions(
            contentType: 'text/plain',
            upsert: true,
          ),
        );
        print('✓ File upload successful');

        // Get public URL
        final url = Supabase.instance.client.storage
            .from('qr-codes')
            .getPublicUrl('test/simple-test.txt');
        print('✓ Public URL: $url');

        // Clean up
        await Supabase.instance.client.storage
            .from('qr-codes')
            .remove(['test/simple-test.txt']);
        print('✓ Cleanup successful');

      } catch (uploadError) {
        print('✗ Upload failed: $uploadError');
      }

      // Test 4: Check existing sections
      print('Checking recent sections...');
      final sections = await Supabase.instance.client
          .from('sections')
          .select('id, name, qr_url')
          .order('created_at', ascending: false)
          .limit(3);

      for (final section in sections) {
        print('Section: ${section['name']} - QR: ${section['qr_url']}');
      }

      print('=== Simple QR Test End ===');

    } catch (e) {
      print('Test error: $e');
    }
  }

  // In your existing SupabaseService class, make sure you have these methods:



  // Your existing method (keeping as is)
  Future<Map<String, dynamic>> fetchPremiseData(String premiseId) async {
    final response = await _supabase
        .from('premises')
        .select('''
          id,
          name,
          created_at,
          data,
          premise_products (
            id,
            name,
            data:details
          ),
          sections (
            id,
            name,
            data,
            section_products (
              id,
              name,
              data
            ),
            subsections (
                id,
                name,
                data,
                subsections_products (
                  id,
                  name,
                  data
                )
              )
          )
        ''')
        .eq('id', premiseId)
        .single();

    return response;
  }

  // ADD THIS NEW METHOD - Public method for AI formatting
  Future<String> getPremiseDataForAI(String premiseId) async {
    try {
      final data = await fetchPremiseData(premiseId);
      return formatPremiseDataForAI(data); // Make the format method public
    } catch (e) {
      throw Exception('Failed to prepare data for AI analysis: ${e.toString()}');
    }
  }

  // ADD THIS METHOD - Make this public (remove the underscore)
  String formatPremiseDataForAI(Map<String, dynamic> premiseData) {
    StringBuffer buffer = StringBuffer();

    buffer.writeln("=== COMPREHENSIVE PREMISE INSPECTION REPORT ===\n");

    // Basic premise information
    buffer.writeln("PREMISE INFORMATION:");
    buffer.writeln("• Name: ${premiseData['name'] ?? 'Unknown'}");
    buffer.writeln("• ID: ${premiseData['id'] ?? 'Unknown'}");
    buffer.writeln("• Created: ${premiseData['created_at'] ?? 'Unknown'}");

    // Parse premise data
    if (premiseData['data'] != null) {
      buffer.writeln("• Additional Details: ${parseDataField(premiseData['data'])}");
    }
    buffer.writeln("");

    // Premise-level products
    if (premiseData['premise_products'] != null) {
      final products = premiseData['premise_products'] as List;
      if (products.isNotEmpty) {
        buffer.writeln("PREMISE-LEVEL PRODUCTS (${products.length} items):");
        for (var product in products) {
          buffer.writeln("• Product: ${product['name'] ?? 'Unnamed'}");
          if (product['data'] != null || product['details'] != null) {
            final productData = product['data'] ?? product['details'];
            buffer.writeln("  Specifications: ${parseDataField(productData)}");
          }
        }
        buffer.writeln("");
      }
    }

    // Sections analysis
    if (premiseData['sections'] != null) {
      final sections = premiseData['sections'] as List;
      if (sections.isNotEmpty) {
        buffer.writeln("DETAILED SECTIONS ANALYSIS (${sections.length} sections):");

        for (int i = 0; i < sections.length; i++) {
          var section = sections[i];
          buffer.writeln("\n--- SECTION ${i + 1}: ${section['name'] ?? 'Unnamed'} ---");

          // Section data
          if (section['data'] != null) {
            buffer.writeln("Section Configuration: ${parseDataField(section['data'])}");
          }

          // Section products
          if (section['section_products'] != null) {
            final sectionProducts = section['section_products'] as List;
            if (sectionProducts.isNotEmpty) {
              buffer.writeln("Section Products (${sectionProducts.length}):");
              for (var product in sectionProducts) {
                buffer.writeln("  • ${product['name'] ?? 'Unnamed'}");
                if (product['data'] != null) {
                  buffer.writeln("    Details: ${parseDataField(product['data'])}");
                }
              }
            }
          }

          // Subsections
          if (section['subsections'] != null) {
            final subsections = section['subsections'] as List;
            if (subsections.isNotEmpty) {
              buffer.writeln("Subsections in this section (${subsections.length}):");

              for (int j = 0; j < subsections.length; j++) {
                var subsection = subsections[j];
                buffer.writeln("  >> Subsection ${j + 1}: ${subsection['name'] ?? 'Unnamed'}");

                if (subsection['data'] != null) {
                  buffer.writeln("     Configuration: ${parseDataField(subsection['data'])}");
                }

                // Subsection products - check both possible field names
                final subProducts = subsection['subsection_products'];
                if (subProducts != null) {
                  final subProductsList = subProducts as List;
                  if (subProductsList.isNotEmpty) {
                    buffer.writeln("     Products in subsection (${subProductsList.length}):");
                    for (var product in subProductsList) {
                      buffer.writeln("       • ${product['name'] ?? 'Unnamed'}");
                      if (product['data'] != null) {
                        buffer.writeln("         Specs: ${parseDataField(product['data'])}");
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    // Add summary statistics
    buffer.writeln("\n=== SUMMARY STATISTICS ===");
    final sections = premiseData['sections'] as List? ?? [];
    final premiseProducts = premiseData['premise_products'] as List? ?? [];

    int totalSubsections = 0;
    int totalSectionProducts = 0;
    int totalSubsectionProducts = 0;

    for (var section in sections) {
      final subsections = section['subsections'] as List? ?? [];
      totalSubsections += subsections.length;

      final sectionProducts = section['section_products'] as List? ?? [];
      totalSectionProducts += sectionProducts.length;

      for (var subsection in subsections) {
        final subProducts = subsection['subsection_products'] as List? ?? [];
        totalSubsectionProducts += subProducts.length;
      }
    }

    buffer.writeln("• Total Sections: ${sections.length}");
    buffer.writeln("• Total Subsections: $totalSubsections");
    buffer.writeln("• Premise Products: ${premiseProducts.length}");
    buffer.writeln("• Section Products: $totalSectionProducts");
    buffer.writeln("• Subsection Products: $totalSubsectionProducts");
    buffer.writeln("• Total Products: ${premiseProducts.length + totalSectionProducts + totalSubsectionProducts}");

    return buffer.toString();
  }

  // ADD THIS METHOD - Make this public too (remove the underscore)
  String parseDataField(dynamic data) {
    if (data == null) return 'No data';

    if (data is Map) {
      return data.entries.map((e) => "${e.key}: ${e.value}").join(", ");
    }

    if (data is String) {
      // Try to clean up the string representation
      String cleanData = data.toString().trim();

      // If it looks like a map string, try to parse it
      if (cleanData.startsWith('{') && cleanData.endsWith('}')) {
        try {
          // Remove the outer braces
          cleanData = cleanData.substring(1, cleanData.length - 1);
          // Split by commas and format nicely
          return cleanData.split(',').map((pair) => pair.trim()).join(", ");
        } catch (e) {
          return cleanData;
        }
      }
      return cleanData;
    }

    return data.toString();
  }

  // Agora token generation

  // Future<String?> fetchAgoraToken(String channelName, {int? uid}) async {
  //   try {
  //     // Check if user is authenticated
  //     final session = Supabase.instance.client.auth.currentSession;
  //     if (session == null) {
  //       print("User not authenticated");
  //       return null;
  //     }
  //
  //     const projectRef = 'crvztrqgmqfixzatlkgz';
  //
  //     final response = await http.post(
  //       Uri.parse("https://$projectRef.functions.supabase.co/agora-token"),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer ${session.accessToken}',
  //       },
  //       body: jsonEncode({
  //         'channelName': channelName,
  //         'uid': uid ?? 0,
  //       }),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       return data["token"];
  //     } else {
  //       print("Error fetching token: ${response.statusCode} - ${response.body}");
  //       return null;
  //     }
  //   } catch (e) {
  //     print("Exception fetching Agora token: $e");
  //     return null;
  //   }
  // }



}




