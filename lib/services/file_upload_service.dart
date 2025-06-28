import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class FileUploadService {
  final _supabase = Supabase.instance.client;
  final String _bucketName = 'freelancer-resumes';
  final String _profilePhotoBucket = 'profile-photos';

  Future<String> uploadResume(dynamic file, String id) async {
    try {
      print('DEBUG: Starting uploadResume');
      final fileName = 'resume_$id.pdf';

      if (kIsWeb) {
        print('DEBUG: Running on web platform');
        // Web platform handling
        Uint8List? fileBytes;

        if (file is File) {
          // This won't work on web, but handle it for consistency
          try {
            final response = await http.get(Uri.parse(file.path));
            fileBytes = response.bodyBytes;
          } catch (e) {
            print('DEBUG: Error reading file as File on web: $e');
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

        print('DEBUG: Uploading bytes to Supabase storage');
        await _supabase.storage.from(_bucketName).uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );
      } else {
        print('DEBUG: Running on non-web platform');
        // Mobile/Desktop platform
        if (file is! File) {
          throw Exception('File must be a File object on non-web platforms');
        }

        print('DEBUG: Uploading file to Supabase storage');
        await _supabase.storage.from(_bucketName).upload(
          fileName,
          file,
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );
      }

      // Get public URL
      print('DEBUG: Getting public URL');
      final String publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(fileName);

      print('DEBUG: Resume uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('DEBUG: Error in uploadResume: $e');
      throw Exception('Error uploading resume: $e');
    }
  }

  Future<String> uploadProfilePhoto(dynamic file, String id) async {
    try {
      print('DEBUG: Starting uploadProfilePhoto');
      final fileName = 'profile_$id.jpg';

      if (kIsWeb) {
        print('DEBUG: Running on web platform');
        // Web platform handling
        Uint8List? fileBytes;

        if (file is File) {
          // This won't work on web, but handle it for consistency
          try {
            final response = await http.get(Uri.parse(file.path));
            fileBytes = response.bodyBytes;
          } catch (e) {
            print('DEBUG: Error reading file as File on web: $e');
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

        print('DEBUG: Uploading bytes to Supabase storage');
        await _supabase.storage.from(_profilePhotoBucket).uploadBinary(
          fileName,
          fileBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      } else {
        print('DEBUG: Running on non-web platform');
        // Mobile/Desktop platform
        if (file is! File) {
          throw Exception('File must be a File object on non-web platforms');
        }

        print('DEBUG: Uploading file to Supabase storage');
        await _supabase.storage.from(_profilePhotoBucket).upload(
          fileName,
          file,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
      }

      // Get public URL
      print('DEBUG: Getting public URL');
      final String publicUrl = _supabase.storage
          .from(_profilePhotoBucket)
          .getPublicUrl(fileName);

      print('DEBUG: Profile photo uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('DEBUG: Error in uploadProfilePhoto: $e');
      throw Exception('Error uploading profile photo: $e');
    }
  }

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
}