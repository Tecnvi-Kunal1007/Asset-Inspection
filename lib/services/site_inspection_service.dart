import 'package:supabase_flutter/supabase_flutter.dart';

class SiteInspectionService {
  final _supabase = Supabase.instance.client;

  // Get sites assigned to a specific site manager
  Future<List<Map<String, dynamic>>> getAssignedSites(
    String freelancerEmail,
  ) async {
    try {
      // First, get the freelancer ID and contractor ID using their email
      final freelancerResponse =
          await _supabase
              .from('freelancers')
              .select('id, contractor_id')
              .eq('email', freelancerEmail)
              .single();

      final freelancerId = freelancerResponse['id'];
      final contractorId = freelancerResponse['contractor_id'];

      // Get all sites assigned to this freelancer with their inspection status
      // that belong to the freelancer's contractor
      final response = await _supabase
          .from('site_assignments')
          .select('''
            *,
            sites (
              id,
              site_name,
              site_location,
              site_description,
              created_at,
              updated_at,
              contractor_id
            )
          ''')
          .eq('freelancer_id', freelancerId)
          .eq('sites.contractor_id', contractorId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting assigned sites: $e');
      return [];
    }
  }

  // Mark a site inspection as completed
  Future<bool> markInspectionComplete(
    String siteId,
    String freelancerId,
  ) async {
    try {
      // First verify the site belongs to the freelancer's contractor
      final freelancerResponse =
          await _supabase
              .from('freelancers')
              .select('contractor_id')
              .eq('id', freelancerId)
              .single();

      if (freelancerResponse == null) {
        throw Exception('Freelancer not found');
      }

      final contractorId = freelancerResponse['contractor_id'];

      // Verify site belongs to contractor
      final siteResponse =
          await _supabase
              .from('sites')
              .select('id')
              .eq('id', siteId)
              .eq('contractor_id', contractorId)
              .single();

      if (siteResponse == null) {
        throw Exception(
          'Site not found or not assigned to freelancer\'s contractor',
        );
      }

      await _supabase
          .from('site_assignments')
          .update({
            'inspection_status': 'completed',
            'inspection_completed_at': DateTime.now().toIso8601String(),
          })
          .eq('site_id', siteId)
          .eq('freelancer_id', freelancerId);
      return true;
    } catch (e) {
      print('Error marking inspection complete: $e');
      return false;
    }
  }

  // Get all sites with their inspection status for a contractor
  Future<List<Map<String, dynamic>>> getSitesWithInspectionStatus(
    String contractorId,
  ) async {
    try {
      final response = await _supabase
          .from('sites')
          .select('''
            *,
            site_assignments (
              freelancer_id,
              inspection_status,
              inspection_completed_at,
              freelancers (
                name,
                email
              )
            )
          ''')
          .eq('contractor_id', contractorId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting sites with inspection status: $e');
      return [];
    }
  }
}
