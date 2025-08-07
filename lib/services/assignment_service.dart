import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/assignment.dart';
import '../models/freelancer.dart';
import '../models/premise.dart';
import 'auth_service.dart';

class AssignmentService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Get current contractor ID
  Future<String?> getCurrentContractorId() async {
    try {
      final contractorInfo = await _authService.getCurrentContractorInfo();
      return contractorInfo != null ? contractorInfo['id'] as String : null;
    } catch (e) {
      print('Error getting contractor ID: $e');
      return null;
    }
  }

  // Assign freelancer to premise
  Future<bool> assignFreelancerToPremise({
    required String premiseId,
    required String freelancerId,
    required String freelancerName,
    required List<String> tasks,
    String? role,
    String? email,
    String? phone,
  }) async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) return false;

      // Get current assignments
      final response = await _supabase
          .from('premises')
          .select('assignments')
          .eq('id', premiseId)
          .eq('contractor_id', contractorId)
          .single();

      Map<String, dynamic> currentAssignments = 
          Map<String, dynamic>.from(response['assignments'] ?? {});

      // Create new assignment
      final assignment = Assignment(
        freelancerId: freelancerId,
        freelancerName: freelancerName,
        tasks: tasks,
        assignedDate: DateTime.now(),
        role: role,
        email: email,
        phone: phone,
      );

      // Add assignment
      currentAssignments[freelancerId] = assignment.toJson();

      // Update premise
      await _supabase
          .from('premises')
          .update({'assignments': currentAssignments})
          .eq('id', premiseId)
          .eq('contractor_id', contractorId);

      return true;
    } catch (e) {
      print('Error assigning freelancer to premise: $e');
      return false;
    }
  }

  // Remove assignment
  Future<bool> removeAssignment({
    required String premiseId,
    required String freelancerId,
  }) async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) return false;

      // Get current assignments
      final response = await _supabase
          .from('premises')
          .select('assignments')
          .eq('id', premiseId)
          .eq('contractor_id', contractorId)
          .single();

      Map<String, dynamic> currentAssignments = 
          Map<String, dynamic>.from(response['assignments'] ?? {});

      // Remove assignment
      currentAssignments.remove(freelancerId);

      // Update premise
      await _supabase
          .from('premises')
          .update({'assignments': currentAssignments})
          .eq('id', premiseId)
          .eq('contractor_id', contractorId);

      return true;
    } catch (e) {
      print('Error removing assignment: $e');
      return false;
    }
  }

  // Get assignments for a premise
  Future<PremiseAssignment?> getPremiseAssignments(String premiseId) async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) return null;

      final response = await _supabase
          .from('premises')
          .select('id, name, assignments')
          .eq('id', premiseId)
          .eq('contractor_id', contractorId)
          .single();

      return PremiseAssignment.fromJson({
        'premise_id': response['id'],
        'premise_name': response['name'],
        'assignments': response['assignments'] ?? {},
      });
    } catch (e) {
      print('Error getting premise assignments: $e');
      return null;
    }
  }

  // Get all assignments for current contractor
  Future<AssignmentOverview?> getContractorAssignments() async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) return null;

      // Get all premises with assignments
      final response = await _supabase
          .from('premises')
          .select('id, name, assignments')
          .eq('contractor_id', contractorId)
          .order('created_at', ascending: false);

      final totalPremises = response.length;
      final premiseAssignments = <PremiseAssignment>[];

      for (final premise in response) {
        final assignments = premise['assignments'] as Map<String, dynamic>? ?? {};
        if (assignments.isNotEmpty) {
          premiseAssignments.add(PremiseAssignment.fromJson({
            'premise_id': premise['id'],
            'premise_name': premise['name'],
            'assignments': assignments,
          }));
        }
      }

      return AssignmentOverview.fromPremiseAssignments(
        contractorId,
        premiseAssignments,
        totalPremises,
      );
    } catch (e) {
      print('Error getting contractor assignments: $e');
      return null;
    }
  }

  // Get available freelancers for assignment
  Future<List<Freelancer>> getAvailableFreelancers() async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) return [];

      final response = await _supabase
          .from('freelancers')
          .select()
          .eq('contractor_id', contractorId)
          .eq('status', 'active')
          .order('name', ascending: true);

      return response.map((data) => Freelancer.fromJson(data)).toList();
    } catch (e) {
      print('Error getting available freelancers: $e');
      return [];
    }
  }

  // Update assignment tasks
  Future<bool> updateAssignmentTasks({
    required String premiseId,
    required String freelancerId,
    required List<String> newTasks,
  }) async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) return false;

      // Get current assignments
      final response = await _supabase
          .from('premises')
          .select('assignments')
          .eq('id', premiseId)
          .eq('contractor_id', contractorId)
          .single();

      Map<String, dynamic> currentAssignments = 
          Map<String, dynamic>.from(response['assignments'] ?? {});

      // Update tasks if assignment exists
      if (currentAssignments.containsKey(freelancerId)) {
        final assignmentData = Map<String, dynamic>.from(currentAssignments[freelancerId]);
        assignmentData['tasks'] = newTasks;
        assignmentData['assigned_date'] = DateTime.now().toIso8601String();
        currentAssignments[freelancerId] = assignmentData;

        // Update premise
        await _supabase
            .from('premises')
            .update({'assignments': currentAssignments})
            .eq('id', premiseId)
            .eq('contractor_id', contractorId);

        return true;
      }

      return false;
    } catch (e) {
      print('Error updating assignment tasks: $e');
      return false;
    }
  }

  // Get assignments by freelancer
  Future<List<PremiseAssignment>> getAssignmentsByFreelancer(String freelancerId) async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) return [];

      final response = await _supabase
          .from('premises')
          .select('id, name, assignments')
          .eq('contractor_id', contractorId);

      final assignments = <PremiseAssignment>[];

      for (final premise in response) {
        final assignmentsData = premise['assignments'] as Map<String, dynamic>? ?? {};
        if (assignmentsData.containsKey(freelancerId)) {
          assignments.add(PremiseAssignment.fromJson({
            'premise_id': premise['id'],
            'premise_name': premise['name'],
            'assignments': assignmentsData,
          }));
        }
      }

      return assignments;
    } catch (e) {
      print('Error getting assignments by freelancer: $e');
      return [];
    }
  }

  // Bulk assign freelancer to multiple premises
  Future<Map<String, bool>> bulkAssignFreelancer({
    required List<String> premiseIds,
    required String freelancerId,
    required String freelancerName,
    required List<String> tasks,
    String? role,
    String? email,
    String? phone,
  }) async {
    final results = <String, bool>{};

    for (final premiseId in premiseIds) {
      final success = await assignFreelancerToPremise(
        premiseId: premiseId,
        freelancerId: freelancerId,
        freelancerName: freelancerName,
        tasks: tasks,
        role: role,
        email: email,
        phone: phone,
      );
      results[premiseId] = success;
    }

    return results;
  }

  // Get assignment statistics
  Future<Map<String, dynamic>> getAssignmentStatistics() async {
    try {
      final overview = await getContractorAssignments();
      if (overview == null) return {};

      return {
        'total_premises': overview.totalPremises,
        'assigned_premises': overview.assignedPremises,
        'total_assignments': overview.totalAssignments,
        'assignment_percentage': overview.assignmentPercentage,
        'most_common_tasks': overview.mostCommonTasks,
        'freelancer_workload': overview.freelancerWorkload,
        'task_type_count': overview.taskTypeCount,
      };
    } catch (e) {
      print('Error getting assignment statistics: $e');
      return {};
    }
  }
}
