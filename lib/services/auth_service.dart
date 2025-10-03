import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/email_service.dart'; // Assuming EmailService is in this path

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final EmailService _emailService = EmailService(); // Instantiate here

  // Stream for auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Send custom OTP for signup verification (via Resend SMTP)
  Future<void> sendRegistrationOTP(String email) async {
    try {
      await _emailService.sendOTPEmail(email);
      log('✅ Signup OTP sent to $email via Resend');
    } catch (e) {
      log('❌ Failed to send signup OTP: $e');
      throw Exception('Failed to send verification OTP: $e');
    }
  }

  // Verify OTP and complete registration
  Future<AuthResponse> verifyAndRegister({
    required String email,
    required String otp,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      // Verify custom OTP
      final isValid = await _emailService.verifyOTP(email, otp);
      if (!isValid) {
        throw Exception('Invalid OTP');
      }

      // Now complete signup with password
      final signUpResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (signUpResponse.user == null) {
        throw Exception('Failed to create user');
      }

      final userId = signUpResponse.user!.id;
      await createUserRecord(
        userId: userId,
        email: email,
        name: name,
        role: role,
        loginProvider: 'email',
      );

      log('✅ User registered and verified: $userId with role $role');
      return signUpResponse;
    } catch (e) {
      log('❌ Registration failed: $e');
      throw Exception('Registration failed: $e');
    }
  }

  // Login
  Future<AuthResponse> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.session == null) {
        throw Exception('Login failed');
      }
      log('✅ User logged in: ${response.user?.id}');
      return response;
    } catch (e) {
      log('❌ Login failed: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>?> getCurrentContractorInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final data =
      await _supabase
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

  // Google Sign-In
  Future<bool> signInWithGoogle({String? redirectTo}) async {
    try {
      final response = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo ?? 'https://crvztrqgmqfixzatlkgz.supabase.co/auth/v1/callback',
      );
      log('✅ Google OAuth initiated: $response');
      return response;
    } catch (e) {
      log('❌ Google Sign-In failed: $e');
      throw e;
    }
  }

  // Complete Google Sign-In with role
  Future<void> completeGoogleSignIn(String role) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No user authenticated');
      }
      final userId = user.id;
      final email = user.email ?? '';
      final name = user.userMetadata?['full_name'] ?? '';

      await createUserRecord(
        userId: userId,
        email: email,
        name: name,
        role: role,
        loginProvider: 'google',
      );
      log('✅ Google Sign-In completed for $userId with role $role');
    } catch (e) {
      log('❌ Google Sign-In completion failed: $e');
      throw e;
    }
  }

  // Check if user has role
  Future<bool> userHasRole(String userId) async {
    try {
      final contractorCount = await _supabase
          .from('contractor')
          .select('id')
          .eq('id', userId)
          .count(CountOption.exact);
      if (contractorCount.count > 0) return true;

      final employeeCount = await _supabase
          .from('freelancer_employee')
          .select('id')
          .eq('id', userId)
          .count(CountOption.exact);
      return employeeCount.count > 0;
    } catch (e) {
      log('❌ Error checking user role: $e');
      return false;
    }
  }

  // Get user role
  Future<String?> getUserRole(String userId) async {
    try {
      final contractorData = await _supabase
          .from('contractor')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (contractorData != null) return 'Contractor';

      final employeeData = await _supabase
          .from('freelancer_employee')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (employeeData != null) return 'Freelancer-Employee';

      return null;
    } catch (e) {
      log('❌ Error getting user role: $e');
      return null;
    }
  }

  // Forgot password
  Future<void> forgotPassword(String email) async {
    try {
      // Use your custom OTP system instead of Supabase's built-in reset
      await _emailService.sendOTPEmail(email);
      log('✅ Reset OTP sent to $email via Resend');
    } catch (e) {
      log('❌ Failed to send reset OTP: $e');
      throw Exception('Failed to send reset email: $e');
    }
  }

  // Verify OTP and update password
  // Updated to work with your custom OTP system
  // Simplified: Verify OTP and update password in one step
  Future<bool> verifyResetAndUpdatePassword(String email, String otp, String newPassword) async {
    try {
      // First verify the custom OTP
      final otpValid = await _emailService.verifyOTP(email, otp);
      if (!otpValid) {
        print('Invalid OTP');
        return false;
      }
  
      // Debug: Log the email being sent
      print('🔍 Attempting password reset for email: "$email"');
      print('🔍 Email length: ${email.length}');
      print('🔍 Email trimmed: "${email.trim()}"');
      
      // Now actually update the password using the edge function
      final response = await _supabase.functions.invoke(
        'update-user-password',
        body: {
          'email': email.trim().toLowerCase(), // Ensure lowercase and trimmed
          'newPassword': newPassword,
        },
      );
      
      print('🔍 Function response: ${response.data}');
      
      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to update password');
      }
      
      log('✅ Password updated successfully');
      return true;
    } catch (e) {
      print('Error in verifyResetAndUpdatePassword: $e');
      return false;
    }
  }

  // Add these missing methods:
  
  // Verify reset OTP only (separate from password update)
  Future<void> verifyResetOTP({
    required String email,
    required String otp,
  }) async {
    try {
      // Use your custom OTP verification
      final isValid = await _emailService.verifyOTP(email, otp);
      if (!isValid) {
        throw Exception('Invalid reset OTP');
      }
      log('✅ Reset OTP verified successfully');
    } catch (e) {
      log('❌ OTP verification failed: $e');
      throw e;
    }
  }

  // Update password after OTP verification
  // In updatePasswordAfterOTP method around line 270
  Future<void> updatePasswordAfterOTP({
    required String email,
    required String newPassword,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'update-user-password',
        body: {
          'email': email.trim().toLowerCase(), // ✅ Add normalization
          'newPassword': newPassword,
        },
      );
      
      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to update password');
      }
      
      log('✅ Password updated successfully');
    } catch (e) {
      log('❌ Password update failed: $e');
      throw e;
    }
  }

  // Create user record
  Future<void> createUserRecord({
    required String userId,
    required String email,
    required String role,
    required String loginProvider,
    String name = '',
  }) async {
    try {
      final table = role == 'Contractor' ? 'contractor' : 'freelancer_employee';
      final otherTable = role == 'Contractor' ? 'freelancer_employee' : 'contractor';
      await _supabase.from(otherTable).delete().eq('id', userId);
      await _supabase.from(table).upsert({
        'id': userId,
        'email': email,
        'name': name,
        'login_provider': loginProvider,
      }, onConflict: 'id');
      log('✅ User record created/updated for $userId in $table');
    } catch (e) {
      log('❌ Failed to create user record: $e');
      throw e;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      log('✅ User logged out');
    } catch (e) {
      log('❌ Logout failed: $e');
      throw e;
    }
  }

  // Current user/session
  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;

}