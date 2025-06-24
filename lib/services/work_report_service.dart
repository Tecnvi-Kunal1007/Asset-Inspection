import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/work_report.dart';

class WorkReportService {
  final _supabase = Supabase.instance.client;

  Future<String> uploadPhoto(
    File photo,
    String freelancerId,
    String type,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String bucketName;

    switch (type) {
      case 'work':
        bucketName = 'workphotos';
        break;
      case 'finished':
        bucketName = 'finishedphotos';
        break;
      case 'geotagged':
        bucketName = 'geotaggedphotos';
        break;
      default:
        bucketName = 'workphotos';
    }

    final filePath = '$freelancerId/${type}_$timestamp.jpg';

    await _supabase.storage.from(bucketName).upload(filePath, photo);
    return _supabase.storage.from(bucketName).getPublicUrl(filePath);
  }

  Future<void> createWorkReport({
    required String freelancerId,
    required String taskId,
    required String equipmentName,
    required String workDescription,
    required String replacedParts,
    required DateTime repairDate,
    required DateTime nextDueDate,
    String? workPhotoUrl,
    String? finishedPhotoUrl,
    String? geotaggedPhotoUrl,
    double? latitude,
    double? longitude,
    String? locationAddress,
    String? qrCodeData,
  }) async {
    await _supabase.from('work_reports').insert({
      'freelancer_id': freelancerId,
      'task_id': taskId,
      'equipment_name': equipmentName,
      'work_description': workDescription,
      'replaced_parts': replacedParts,
      'repair_date': repairDate.toIso8601String(),
      'next_due_date': nextDueDate.toIso8601String(),
      'work_photo_url': workPhotoUrl,
      'finished_photo_url': finishedPhotoUrl,
      'geotagged_photo_url': geotaggedPhotoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'location_address': locationAddress,
      'qr_code_data': qrCodeData,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<WorkReport>> getWorkReportsByFreelancer(
    String freelancerId,
  ) async {
    final response = await _supabase
        .from('work_reports')
        .select()
        .eq('freelancer_id', freelancerId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => WorkReport.fromJson(json)).toList();
  }

  Future<List<WorkReport>> getWorkReportsByContractor(
    String contractorId,
  ) async {
    final response = await _supabase
        .from('work_reports')
        .select('*, freelancers!inner(*)')
        .eq('freelancers.contractor_id', contractorId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => WorkReport.fromJson(json)).toList();
  }
}
