import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/freelancer.dart';
import 'auth_service.dart';

class FreelancerService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // Get current logged in contractor ID
  Future<String?> getCurrentContractorId() async {
    try {
      final contractorInfo = await _authService.getCurrentContractorInfo();
      return contractorInfo != null ? contractorInfo['id'] as String : null;
    } catch (e) {
      print('Error getting contractor ID: $e');
      return null;
    }
  }

  // Get all freelancers associated with the current contractor
  Future<List<Freelancer>> getFreelancersForCurrentContractor() async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) return [];

      final response = await _supabase
          .from('freelancers')
          .select()
          .eq('contractor_id', contractorId)
          .eq('status', 'active')
          .neq('role', 'employee')
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => Freelancer.fromJson(data))
          .toList();
    } catch (e) {
      print('Error getting freelancers: $e');
      return [];
    }
  }

  // Get all employees associated with the current contractor
  Future<List<Freelancer>> getEmployeesForCurrentContractor() async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) return [];

      final response = await _supabase
          .from('freelancers')
          .select()
          .eq('contractor_id', contractorId)
          .eq('role', 'employee')
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => Freelancer.fromJson(data))
          .toList();
    } catch (e) {
      print('Error getting employees: $e');
      return [];
    }
  }

  // Add a new freelancer with the current contractor ID
  Future<Freelancer?> addFreelancer(Map<String, dynamic> freelancerData) async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) {
        throw Exception('No contractor ID found');
      }

      // Add contractor_id to the freelancer data
      freelancerData['contractor_id'] = contractorId;

      final response = await _supabase
          .from('freelancers')
          .insert(freelancerData)
          .select()
          .single();

      return Freelancer.fromJson(response);
    } catch (e) {
      print('Error adding freelancer: $e');
      return null;
    }
  }

  // Update an existing freelancer
  Future<bool> updateFreelancer(String id, Map<String, dynamic> freelancerData) async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) {
        throw Exception('No contractor ID found');
      }

      // Ensure the freelancer belongs to this contractor
      final existingFreelancer = await _supabase
          .from('freelancers')
          .select()
          .eq('id', id)
          .eq('contractor_id', contractorId)
          .maybeSingle();
      
      if (existingFreelancer == null) {
        throw Exception('Freelancer not found or does not belong to this contractor');
      }

      await _supabase
          .from('freelancers')
          .update(freelancerData)
          .eq('id', id);

      return true;
    } catch (e) {
      print('Error updating freelancer: $e');
      return false;
    }
  }

  // Get a single freelancer by ID
  Future<Freelancer?> getFreelancerById(String id) async {
    try {
      final contractorId = await getCurrentContractorId();
      if (contractorId == null) return null;

      final response = await _supabase
          .from('freelancers')
          .select()
          .eq('id', id)
          .eq('contractor_id', contractorId)
          .maybeSingle();

      return response != null ? Freelancer.fromJson(response) : null;
    } catch (e) {
      print('Error getting freelancer: $e');
      return null;
    }
  }
} 