import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class FileUploadService {
  final _supabase = Supabase.instance.client;
  final String _bucketName = 'freelancer-resumes';
  final String _profilePhotoBucket = 'profile-photos';

  Future<String> uploadResume(File file, String id) async {
    try {
      // Get file extension
      final fileExtension = path.extension(file.path);
      final fileName = 'resume_$id$fileExtension';

      // Upload file to Supabase Storage
      final response = await _supabase.storage
          .from(_bucketName)
          .upload(fileName, file);

      // Get public URL
      final String publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Error uploading resume: $e');
    }
  }

  Future<String> uploadProfilePhoto(File file, String id) async {
    try {
      // Get file extension
      final fileExtension = path.extension(file.path);
      final fileName = 'profile_$id$fileExtension';

      // Upload file to Supabase Storage
      await _supabase.storage.from(_profilePhotoBucket).upload(fileName, file);

      // Get public URL
      final String publicUrl = _supabase.storage
          .from(_profilePhotoBucket)
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
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
