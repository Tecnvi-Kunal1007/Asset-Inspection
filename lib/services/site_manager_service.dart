import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site.dart';

class SiteManagerService {
  final _supabase = Supabase.instance.client;

  // Get the freelancer ID for the logged-in site manager
  Future<String?> getFreelancerId(String email) async {
    try {
      final response =
          await _supabase
              .from('freelancers')
              .select('id, contractor_id')
              .eq('email', email)
              .single();

      return response['id'] as String;
    } catch (e) {
      print('Error getting freelancer ID: $e');
      return null;
    }
  }

  // Get all sites assigned to the site manager
  Future<List<Site>> getAssignedSites(String freelancerId) async {
    try {
      // First get the freelancer's contractor ID
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

      // Get site IDs assigned to this freelancer
      final assignments = await _supabase
          .from('site_assignments')
          .select('site_id')
          .eq('freelancer_id', freelancerId);

      if (assignments.isEmpty) {
        return [];
      }

      // Extract site IDs
      final siteIds =
          (assignments as List)
              .map((assignment) => assignment['site_id'] as String)
              .toList();

      // Get site details for all assigned sites that belong to the freelancer's contractor
      final sites = await _supabase
          .from('sites')
          .select()
          .inFilter('id', siteIds)
          .eq('contractor_id', contractorId);

      return (sites as List).map((json) => Site.fromJson(json)).toList();
    } catch (e) {
      print('Error getting assigned sites: $e');
      return [];
    }
  }
}
