import 'package:supabase_flutter/supabase_flutter.dart';

class AreaAssignmentService {
  final _supabase = Supabase.instance.client;

  // Get available areas for assignment
  Future<List<Map<String, dynamic>>> getAvailableAreasForAssignment(
    String contractorId,
    String assignedToId,
  ) async {
    try {
      // First get all areas for this contractor
      final areasResponse = await _supabase
          .from('areas')
          .select()
          .eq('contractor_id', contractorId);

      if (areasResponse == null) return [];

      final areas = List<Map<String, dynamic>>.from(areasResponse);

      // Get all active assignments
      final assignmentsResponse = await _supabase
          .from('area_assignments')
          .select('area_id, assignment_type')
          .eq('status', 'active');

      if (assignmentsResponse == null) return areas;

      // Create a map of area_id to set of assignment_types for quick lookup
      final Map<String, Set<String>> areaAssignments = {};
      for (var assignment in assignmentsResponse) {
        final areaId = assignment['area_id'] as String;
        final assignmentType = assignment['assignment_type'] as String;
        areaAssignments.putIfAbsent(areaId, () => {}).add(assignmentType);
      }

      // Get all areas assigned to this user
      final userAssignmentsResponse = await _supabase
          .from('area_assignments')
          .select('area_id, assignment_type')
          .eq('assigned_to_id', assignedToId)
          .eq('status', 'active');

      final Map<String, Set<String>> userAreaAssignments = {};
      for (var assignment in userAssignmentsResponse) {
        final areaId = assignment['area_id'] as String;
        final assignmentType = assignment['assignment_type'] as String;
        userAreaAssignments.putIfAbsent(areaId, () => {}).add(assignmentType);
      }

      // Filter out areas that have both sections assigned to someone else
      final availableAreas =
          areas.where((area) {
            final areaId = area['id'] as String;
            final assignedSections = areaAssignments[areaId] ?? {};
            final userAssignedSections = userAreaAssignments[areaId] ?? {};

            // Include areas that:
            // 1. Have no assignments
            // 2. Have only one section assigned (to anyone)
            // 3. Are assigned to the current user (for unassignment)
            return assignedSections.isEmpty ||
                assignedSections.length < 2 ||
                userAssignedSections.isNotEmpty;
          }).toList();

      return availableAreas;
    } catch (e) {
      print('Error getting available areas: $e');
      return [];
    }
  }

  // Helper method to check if an area is assigned to a specific user
  Future<bool> _isAssignedToUser(String areaId, String userId) async {
    try {
      final response =
          await _supabase
              .from('area_assignments')
              .select()
              .eq('area_id', areaId)
              .eq('assigned_to_id', userId)
              .eq('status', 'active')
              .single();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // Assign an area
  Future<void> assignArea({
    required String areaId,
    required String assignedToId,
    required String assignedToType,
    required String assignedById,
    required String assignmentType,
    String? notes,
  }) async {
    try {
      // First, check if there's an existing active assignment for the same section type
      final existingAssignment =
          await _supabase
              .from('area_assignments')
              .select()
              .eq('area_id', areaId)
              .eq('assignment_type', assignmentType)
              .eq('status', 'active')
              .maybeSingle();

      if (existingAssignment != null) {
        // If there's an existing assignment for the same section type, mark it as inactive
        await _supabase
            .from('area_assignments')
            .update({
              'status': 'inactive',
              'unassigned_at': DateTime.now().toIso8601String(),
            })
            .eq('area_id', areaId)
            .eq('assignment_type', assignmentType)
            .eq('status', 'active');
      }

      // Create new assignment
      await _supabase.from('area_assignments').insert({
        'area_id': areaId,
        'assigned_to_id': assignedToId,
        'assigned_to_type': assignedToType,
        'assigned_by_id': assignedById,
        'assignment_type': assignmentType,
        'notes': notes,
        'status': 'active',
        'inspection_status': 'pending',
        'inspection_completed_at': null,
        'assigned_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error assigning area: $e');
      rethrow;
    }
  }

  // Unassign an area
  Future<void> unassignArea(String areaId, String assignedToId) async {
    try {
      await _supabase
          .from('area_assignments')
          .update({
            'status': 'inactive',
            'unassigned_at': DateTime.now().toIso8601String(),
          })
          .eq('area_id', areaId)
          .eq('assigned_to_id', assignedToId)
          .eq('status', 'active');
    } catch (e) {
      print('Error unassigning area: $e');
      rethrow;
    }
  }

  // Get assignment history for an area
  Future<List<Map<String, dynamic>>> getAreaAssignmentHistory(
    String areaId,
  ) async {
    try {
      final response = await _supabase
          .from('area_assignment_history')
          .select()
          .eq('area_id', areaId)
          .order('assigned_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting area assignment history: $e');
      return [];
    }
  }

  // Get all assignments for a user
  Future<List<Map<String, dynamic>>> getAssignmentsByUser(
    String userId,
    String userType,
  ) async {
    try {
      final response = await _supabase
          .from('area_assignments')
          .select('''
            *,
            areas (
              id,
              name,
              description,
              site_location
            )
          ''')
          .eq('assigned_to_id', userId)
          .eq('assigned_to_type', userType)
          .eq('status', 'active')
          .order('assigned_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting user assignments: $e');
      return [];
    }
  }

  // Mark area inspection as completed
  Future<void> markInspectionComplete(
    String areaId,
    String assignedToId,
  ) async {
    try {
      await _supabase
          .from('area_assignments')
          .update({
            'inspection_status': 'completed',
            'inspection_completed_at': DateTime.now().toIso8601String(),
          })
          .eq('area_id', areaId)
          .eq('assigned_to_id', assignedToId)
          .eq('status', 'active');
    } catch (e) {
      print('Error marking inspection complete: $e');
      rethrow;
    }
  }
}
