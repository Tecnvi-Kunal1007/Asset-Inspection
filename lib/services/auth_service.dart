import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final EmailService _emailService = EmailService();

  // ✅ Send OTP email before registration
  Future<void> sendRegistrationOTP(String email) async {
    await _emailService.sendOTPEmail(email);
  }

  // ✅ Register user safely with duplicate check
  Future<AuthResponse> registerUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      // Step 1: Sign up the user
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (response.user == null) {
        throw Exception('❌ Failed to create new user');
      }

      // Step 2: Wait for automatic login or sign in manually
      if (_supabase.auth.currentUser == null) {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('❌ User not authenticated after sign-up');
      }

      // Step 3: Insert into correct table only if not already inserted
      final tableName = role == 'Contractor' ? 'contractor' : 'freelancer_employee';

      final existing = await _supabase
          .from(tableName)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from(tableName).insert({
          'id': userId,
          'name': name,
          'email': email,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        log("⚠️ User already exists in $tableName table");
      }

      return response;
    } on AuthException catch (e) {
      log("🔒 Auth error: ${e.message}");
      throw AuthException(e.message);
    } catch (e) {
      log("❌ Registration failed: $e");
      throw Exception('Failed to register user: $e');
    }
  }

  // ✅ Login user
  Future<AuthResponse> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      log("❌ Login failed: ${e.message}");
      throw AuthException(e.message);
    }
  }

  // ✅ Determine user role
  Future<String?> getUserRole(String id) async {
    final contractor = await _supabase
        .from('contractor')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (contractor != null) return 'Contractor';

    final freelancer = await _supabase
        .from('freelancer_employee')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (freelancer != null) return 'Freelancer-Employee';

    return null;
  }

  // ✅ Get Contractor Info
  Future<Map<String, dynamic>?> getCurrentContractorInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final data = await _supabase
          .from('contractor')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      return data;
    } catch (e) {
      log("❌ Contractor info fetch error: $e");
      return null;
    }
  }

  // ✅ Forgot password
  Future<void> forgotPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw Exception('❌ Failed to send reset email: $e');
    }
  }

  // ✅ Reset password
  Future<void> resetPassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      log("❌ Reset failed: $e");
      throw Exception('Password reset failed');
    }
  }

  // ✅ Verify OTP (custom logic)
  Future<bool> verifyOTP(String email, String otp) async {
    return await _emailService.verifyOTP(email, otp);
  }

  // ✅ Logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
