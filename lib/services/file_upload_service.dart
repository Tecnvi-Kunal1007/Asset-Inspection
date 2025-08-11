import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class FileUploadService {
  final _supabase = Supabase.instance.client;

  // Existing buckets
  final String _bucketName = 'freelancer-resumes';
  final String _profilePhotoBucket = 'profile-photos';

  // 🆕 Buckets for products
  final String _premisePhotosBucket = 'premises-photos';
  final String _sectionPhotosBucket = 'section-photos';
  final String _subsectionPhotosBucket = 'subsection-photos';

  // ------------------------------
  // Resume upload (unchanged)
  // ------------------------------
  Future<String> uploadResume(dynamic file, String id) async {
    try {
      print('DEBUG: Starting uploadResume');
      final fileName = 'resume_$id.pdf';

      if (kIsWeb) {
        print('DEBUG: Running on web platform');
        Uint8List? fileBytes;

        if (file is File) {
          try {
            final response = await http.get(Uri.parse(file.path));
            fileBytes = response.bodyBytes;
          } catch (e) {
            throw Exception('Cannot read file on web platform');
          }
        } else if (file is PlatformFile) {
          fileBytes = file.bytes;
        } else if (file is Uint8List) {
          fileBytes = file;
        } else if (file is List<int>) {
          fileBytes = Uint8List.fromList(file);
        } else {
          throw Exception('Unsupported file type for web upload');
        }

        if (fileBytes == null) {
          throw Exception('Could not read file bytes');
        }

        await _supabase.storage.from(_bucketName).uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );
      } else {
        if (file is! File) {
          throw Exception('File must be a File object on non-web platforms');
        }
        await _supabase.storage.from(_bucketName).upload(
          fileName,
          file,
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );
      }

      final String publicUrl =
          _supabase.storage.from(_bucketName).getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Error uploading resume: $e');
    }
  }

  // ------------------------------
  // Profile photo upload (unchanged except compression)
  // ------------------------------
  Future<String> uploadProfilePhoto(dynamic file, String id) async {
    try {
      print('DEBUG: Starting uploadProfilePhoto');
      final fileName = 'profile_$id.jpg';

      if (kIsWeb) {
        Uint8List? fileBytes;

        if (file is File) {
          try {
            final response = await http.get(Uri.parse(file.path));
            fileBytes = response.bodyBytes;
          } catch (e) {
            throw Exception('Cannot read file on web platform');
          }
        } else if (file is PlatformFile) {
          fileBytes = file.bytes;
        } else if (file is Uint8List) {
          fileBytes = file;
        } else if (file is List<int>) {
          fileBytes = Uint8List.fromList(file);
        } else {
          throw Exception('Unsupported file type for web upload');
        }

        if (fileBytes == null) throw Exception('Could not read file bytes');

        // 🆕 Compression for web profile photos
        fileBytes = await FlutterImageCompress.compressWithList(
          fileBytes,
          quality: 85,
          format: CompressFormat.jpeg,
        );

        await _supabase.storage.from(_profilePhotoBucket).uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      } else {
        if (file is! File) {
          throw Exception('File must be a File object on non-web platforms');
        }

        // 🆕 Compression for mobile profile photos
        final compressedFile = await _compressFile(file);

        await _supabase.storage.from(_profilePhotoBucket).upload(
          fileName,
          compressedFile ?? file,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      }

      return _supabase.storage
          .from(_profilePhotoBucket)
          .getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Error uploading profile photo: $e');
    }
  }

  // ------------------------------
  // Product photo upload (modified)
  // ------------------------------
  Future<String> uploadProductPhoto(
      dynamic file, String productType, String productId) async {
    try {
      print('DEBUG: Starting uploadProductPhoto');
      final uuid = const Uuid().v4();
      final fileName = '${productType}_${productId}_$uuid.jpg';

      // 🆕 Select bucket based on productType
      String targetBucket;
      switch (productType.toLowerCase()) {
        case 'premises':
        case 'premise':
          targetBucket = _premisePhotosBucket;
          break;
        case 'section':
          targetBucket = _sectionPhotosBucket;
          break;
        case 'subsection':
          targetBucket = _subsectionPhotosBucket;
          break;
        default:
          throw Exception('Invalid product type: $productType');
      }

      if (kIsWeb) {
        Uint8List? fileBytes;

        if (file is File) {
          try {
            final response = await http.get(Uri.parse(file.path));
            fileBytes = response.bodyBytes;
          } catch (e) {
            throw Exception('Cannot read file on web platform');
          }
        } else if (file is PlatformFile) {
          fileBytes = file.bytes;
        } else if (file is Uint8List) {
          fileBytes = file;
        } else if (file is List<int>) {
          fileBytes = Uint8List.fromList(file);
        } else {
          throw Exception('Unsupported file type for web upload');
        }

        if (fileBytes == null) throw Exception('Could not read file bytes');

        // 🆕 Compress image bytes for web
        try {
          print('DEBUG: Attempting to compress image on web');
          final compressedBytes = await FlutterImageCompress.compressWithList(
            fileBytes,
            minHeight: 800,
            minWidth: 800,
            quality: 85,
            format: CompressFormat.jpeg,
          );
          
          if (compressedBytes != null && compressedBytes.isNotEmpty) {
            fileBytes = compressedBytes;
            print('DEBUG: Successfully compressed image on web');
          } else {
            print('DEBUG: Compression returned empty result, using original image');
          }
        } catch (e) {
          print('DEBUG: Error compressing image on web: $e');
          // Continue with uncompressed image if compression fails
        }

        // Ensure fileBytes is not null before uploading
        if (fileBytes != null) {
          await _supabase.storage.from(targetBucket).uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
        } else {
          throw Exception('Could not process image: fileBytes is null');
        }
      } else {
        if (file is! File) {
          throw Exception('File must be a File object on non-web platforms');
        }

        // 🆕 Compress the file for mobile
        File? compressedFile;
        try {
          print('DEBUG: Attempting to compress file for mobile/desktop: ${file.path}');
          compressedFile = await _compressFile(file);
          
          if (compressedFile != null) {
            print('DEBUG: Successfully compressed file to: ${compressedFile.path}');
          } else {
            print('DEBUG: Compression returned null, will use original file');
          }
        } catch (e) {
          print('DEBUG: Error during compression for mobile: $e');
          // Will continue with original file if compression fails
        }

        await _supabase.storage.from(targetBucket).upload(
          fileName,
          compressedFile ?? file,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      }

      return _supabase.storage.from(targetBucket).getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Error uploading product photo: $e');
    }
  }

  // ------------------------------
  // Delete functions (unchanged)
  // ------------------------------
  Future<void> deleteResume(String resumeUrl) async {
    try {
      final fileName = path.basename(resumeUrl);
      await _supabase.storage.from(_bucketName).remove([fileName]);
    } catch (e) {
      throw Exception('Error deleting resume: $e');
    }
  }

  Future<void> deleteProfilePhoto(String photoUrl) async {
    try {
      final fileName = path.basename(photoUrl);
      await _supabase.storage.from(_profilePhotoBucket).remove([fileName]);
    } catch (e) {
      throw Exception('Error deleting profile photo: $e');
    }
  }

  Future<void> deleteProductPhoto(
      String photoUrl, String productType) async {
    try {
      String targetBucket;
      switch (productType.toLowerCase()) {
        case 'premise':
        case 'premises':
          targetBucket = _premisePhotosBucket;
          break;
        case 'section':
          targetBucket = _sectionPhotosBucket;
          break;
        case 'subsection':
          targetBucket = _subsectionPhotosBucket;
          break;
        default:
          throw Exception('Invalid product type: $productType');
      }

      final fileName = path.basename(photoUrl);
      await _supabase.storage.from(targetBucket).remove([fileName]);
    } catch (e) {
      throw Exception('Error deleting product photo: $e');
    }
  }

  // ------------------------------
  // 🆕 Helper: compress file for mobile/desktop
  // ------------------------------
  Future<File?> _compressFile(File file) async {
    try {
      // Check if file exists and is readable
      if (!file.existsSync()) {
        print('DEBUG: File does not exist: ${file.path}');
        return null;
      }
      
      // Check file size
      final fileSize = await file.length();
      print('DEBUG: Original file size: ${fileSize / 1024} KB');
      
      // If file is already small, return it as is
      if (fileSize < 100 * 1024) { // Less than 100KB
        print('DEBUG: File is already small, skipping compression');
        return file;
      }
      
      final dir = path.dirname(file.path);
      final name = path.basenameWithoutExtension(file.path);
      final ext = path.extension(file.path);
      final targetPath = path.join(dir, '${name}_compressed$ext');
      
      print('DEBUG: Compressing file from ${file.path} to $targetPath');
      
      // Check if target directory is writable
      final targetDir = Directory(dir);
      if (!targetDir.existsSync()) {
        print('DEBUG: Creating target directory: $dir');
        targetDir.createSync(recursive: true);
      }
      
      // Check if we can write to the target directory
      try {
        final testFile = File(path.join(dir, 'test_write_${DateTime.now().millisecondsSinceEpoch}.tmp'));
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        print('DEBUG: Cannot write to directory $dir: $e');
        return file; // Return original file if we can't write to the directory
      }
      
      print('DEBUG: Calling FlutterImageCompress.compressAndGetFile');
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        minHeight: 800,
        minWidth: 800,
        quality: 85,
        format: CompressFormat.jpeg,
      );
      
      if (result == null) {
        print('DEBUG: Compression returned null result');
        return file; // Return original file if compression fails
      }
      
      // Check compressed file size
      final compressedSize = await File(result.path).length();
      print('DEBUG: Compressed file size: ${compressedSize / 1024} KB (${(compressedSize / fileSize * 100).toStringAsFixed(1)}% of original)');
      
      print('DEBUG: Successfully compressed image to ${result.path}');
      return File(result.path);
    } catch (e) {
      print('DEBUG: Error compressing image file: $e');
      if (e.toString().contains('Unimplemented')) {
        print('DEBUG: FlutterImageCompress may not be properly implemented for this platform');
      } else if (e.toString().contains('Permission')) {
        print('DEBUG: Permission error when compressing file');
      }
      return file; // Return original file if compression fails
    }
  }
}
