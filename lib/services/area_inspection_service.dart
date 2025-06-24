import 'package:supabase_flutter/supabase_flutter.dart';

class AreaInspectionService {
  final _supabase = Supabase.instance.client;

  // Get areas assigned to a specific freelancer
  Future<List<Map<String, dynamic>>> getAssignedAreas(
    String freelancerEmail,
  ) async {
    try {
      // First, get the freelancer ID and contractor ID using their email
      final freelancerResponse =
          await _supabase
              .from('freelancers')
              .select('id, contractor_id')
              .eq('email', freelancerEmail)
              .maybeSingle();

      if (freelancerResponse == null) {
        throw Exception('Freelancer not found');
      }

      final freelancerId = freelancerResponse['id'];
      final contractorId = freelancerResponse['contractor_id'];

      // Get all areas assigned to this freelancer with their inspection status
      // that belong to the freelancer's contractor
      final response = await _supabase
          .from('area_assignments')
          .select('''
            *,
            areas (
              id,
              name,
              description,
              site_location,
              created_at,
              updated_at,
              contractor_id
            )
          ''')
          .eq('assigned_to_id', freelancerId)
          .eq('assigned_to_type', 'freelancer')
          .eq('status', 'active')
          .eq('areas.contractor_id', contractorId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting assigned areas: $e');
      return [];
    }
  }

  // Mark an area inspection as completed for a specific section
  Future<bool> markInspectionComplete(
    String areaId,
    String freelancerId,
    String sectionType,
  ) async {
    try {
      // First verify the area belongs to the freelancer's contractor
      final freelancerResponse =
          await _supabase
              .from('freelancers')
              .select('contractor_id')
              .eq('id', freelancerId)
              .maybeSingle();

      if (freelancerResponse == null) {
        throw Exception('Freelancer not found');
      }

      final contractorId = freelancerResponse['contractor_id'];

      // Verify area belongs to contractor
      final areaResponse =
          await _supabase
              .from('areas')
              .select('id')
              .eq('id', areaId)
              .eq('contractor_id', contractorId)
              .maybeSingle();

      if (areaResponse == null) {
        throw Exception(
          'Area not found or not assigned to freelancer\'s contractor',
        );
      }

      // Update the inspection status
      final updateData = {
        'inspection_status': 'completed',
        'inspection_completed_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('area_assignments')
          .update(updateData)
          .eq('area_id', areaId)
          .eq('assigned_to_id', freelancerId)
          .eq('status', 'active')
          .eq('assignment_type', sectionType);

      return true;
    } catch (e) {
      print('Error marking inspection complete: $e');
      return false;
    }
  }

  // Get all areas with their inspection status for a contractor
  Future<List<Map<String, dynamic>>> getAreasWithInspectionStatus(
    String contractorId,
  ) async {
    try {
      print('Getting areas for contractor: $contractorId'); // Debug print

      // First get all areas for this contractor
      final areasResponse = await _supabase
          .from('areas')
          .select('*')
          .eq('contractor_id', contractorId);

      if (areasResponse == null || areasResponse.isEmpty) {
        print('No areas found for contractor');
        return [];
      }

      final areas = List<Map<String, dynamic>>.from(areasResponse);
      final areaIds = areas.map((area) => area['id'] as String).toList();

      // Get all active assignments for these areas
      final assignmentsResponse = await _supabase
          .from('area_assignments')
          .select('*')
          .filter('area_id', 'in', areaIds)
          .eq('status', 'active');

      // Get all freelancer IDs from assignments
      final freelancerIds =
          (assignmentsResponse as List)
              .map((assignment) => assignment['assigned_to_id'] as String)
              .toSet()
              .toList();

      // Get freelancer details
      final freelancersResponse = await _supabase
          .from('freelancers')
          .select('id, name, email')
          .filter('id', 'in', freelancerIds);

      // Create a map of freelancer ID to freelancer details
      final freelancersMap = {
        for (var freelancer in freelancersResponse)
          freelancer['id'] as String: freelancer,
      };

      // Combine the data
      final processedAreas =
          areas.map((area) {
            final areaId = area['id'] as String;
            final assignments =
                (assignmentsResponse as List)
                    .where((assignment) => assignment['area_id'] == areaId)
                    .map((assignment) {
                      final freelancerId =
                          assignment['assigned_to_id'] as String;
                      return {
                        ...assignment,
                        'freelancers': freelancersMap[freelancerId],
                      };
                    })
                    .toList();

            return {...area, 'area_assignments': assignments};
          }).toList();

      print(
        'Found ${processedAreas.length} areas with assignments',
      ); // Debug print
      return processedAreas;
    } catch (e) {
      print('Error getting areas with inspection status: $e');
      return [];
    }
  }
}
