// auth_service.dart
import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_service.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final EmailService _emailService = EmailService();

  // Send OTP for registration
  Future<void> sendRegistrationOTP(String email) async {
    await _emailService.sendOTPEmail(email);
  }

  // Register user after OTP verification
  Future<AuthResponse> registerUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      // Register user with Supabase Auth
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Failed to create user');
      }

      // Add user details to the appropriate role table
      final tableName =
          role == 'Contractor' ? 'contractor' : 'freelancer_employee';

      await _supabase.from(tableName).insert({
        'id': response.user!.id,
        'name': name,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      });

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Failed to register user: $e');
    }
  }

  // Login user
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
      log("Failed to login");
      throw AuthException('${e.message}');
    }
  }

  // Get user role (contractor or site manager)
  Future<String?> getUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // Check if the user is a contractor
      final contractorData =
          await _supabase
              .from('contractor')
              .select()
              .eq('id', user.id)
              .maybeSingle();

      if (contractorData != null) {
        return 'Contractor';
      }

      // Check if the user is a site manager
      final siteManagerData =
          await _supabase
              .from('freelancer_employee')
              .select()
              .eq('id', user.id)
              .maybeSingle();

      if (siteManagerData != null) {
        return 'SiteManager';
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Get current user's contractor information
  Future<Map<String, dynamic>?> getCurrentContractorInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final contractorData =
          await _supabase
              .from('contractor')
              .select()
              .eq('id', user.id)
              .maybeSingle();

      return contractorData;
    } catch (e) {
      log("Error getting contractor info: $e");
      return null;
    }
  }

  // Forgot password
  Future<void> forgotPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.pumpmanagement://reset-callback/',
      );
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  // Reset password with new password
  Future<void> resetPassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  // Verify OTP
  Future<bool> verifyOTP(String email, String otp) async {
    return await _emailService.verifyOTP(email, otp);
  }

  // Logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
