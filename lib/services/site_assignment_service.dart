import 'package:supabase_flutter/supabase_flutter.dart';

class SiteAssignmentService {
  final _supabase = Supabase.instance.client;

  // Get available sites for assignment (unassigned sites + sites assigned to the given freelancer)
  Future<List<Map<String, dynamic>>> getAvailableSitesForAssignment(
    String contractorId,
    String freelancerId,
  ) async {
    try {
      // Get all sites for this contractor
      final sitesResponse = await _supabase
          .from('sites')
          .select()
          .eq('contractor_id', contractorId);
      final sites = List<Map<String, dynamic>>.from(sitesResponse);

      // Get all site assignments
      final assignmentsResponse = await _supabase
          .from('site_assignments')
          .select('site_id, freelancer_id');
      final assignments = List<Map<String, dynamic>>.from(assignmentsResponse);

      // Create a map of site_id to freelancer_id for quick lookup
      final siteAssignments = {
        for (var assignment in assignments)
          assignment['site_id'] as String:
              assignment['freelancer_id'] as String,
      };

      // Filter sites to only include unassigned ones or ones assigned to this freelancer
      return sites.where((site) {
        final assignedFreelancerId = siteAssignments[site['id']];
        return assignedFreelancerId == null || // unassigned
            assignedFreelancerId == freelancerId; // assigned to this freelancer
      }).toList();
    } catch (e) {
      print('Error getting available sites: $e');
      return [];
    }
  }

  // Assign a site to a freelancer
  Future<void> assignSite({
    required String siteId,
    required String assignedToId,
    String? notes,
  }) async {
    try {
      // Create new assignment in site_assignments table
      await _supabase.from('site_assignments').insert({
        'site_id': siteId,
        'freelancer_id': assignedToId,
        'inspection_status': 'pending',
        'inspection_completed_at': null,
      });
    } catch (e) {
      print('Error assigning site: $e');
      rethrow;
    }
  }

  // Get current assignments for a site
  Future<Map<String, dynamic>?> getCurrentAssignment(String siteId) async {
    final response =
        await _supabase
            .from('site_assignment_history')
            .select()
            .eq('site_id', siteId)
            .eq('status', 'active')
            .single();

    return response as Map<String, dynamic>?;
  }

  // Get assignment history for a site
  Future<List<Map<String, dynamic>>> getSiteAssignmentHistory(
    String siteId,
  ) async {
    try {
      // Get the site first to verify it exists
      final site =
          await _supabase.from('sites').select().eq('id', siteId).single();

      if (site == null) {
        throw Exception('Site not found');
      }

      // Get assignment history for the site
      final response = await _supabase
          .from('site_assignment_history')
          .select()
          .eq('site_id', siteId)
          .order('assigned_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting site assignment history: $e');
      return [];
    }
  }

  // Get all assignments for a freelancer
  Future<List<Map<String, dynamic>>> getAssignmentsByUser(String userId) async {
    final response = await _supabase
        .from('site_assignment_history')
        .select()
        .eq('assigned_to_id', userId)
        .eq('assigned_to_type', 'freelancer')
        .order('assigned_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get all assignments made by a contractor
  Future<List<Map<String, dynamic>>> getAssignmentsByContractor(
    String contractorId,
  ) async {
    try {
      // Get all sites for this contractor
      final sitesResponse = await _supabase
          .from('sites')
          .select('id')
          .eq('contractor_id', contractorId);

      final siteIds =
          List<Map<String, dynamic>>.from(
            sitesResponse,
          ).map((site) => site['id'] as String).toList();

      if (siteIds.isEmpty) return [];

      // Get assignment history for all these sites
      final response = await _supabase
          .from('site_assignment_history')
          .select()
          .inFilter('site_id', siteIds)
          .order('assigned_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting contractor assignments: $e');
      return [];
    }
  }

  // Unassign a site
  Future<void> unassignSite(String siteId) async {
    // Delete from site_assignments table
    // The trigger will handle updating the history record
    await _supabase.from('site_assignments').delete().eq('site_id', siteId);
  }
}
