// email_service.dart
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Generate a random 6-digit OTP
  String _generateOTP() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  // Save OTP to Supabase
  Future<String> saveOTP(String email) async {
    try {
      // Generate OTP
      final otp = _generateOTP();

      // Store OTP in the database with expiration
      await _supabase.from('email_otp').insert({
        'email': email,
        'otp': otp,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at':
            DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
        'is_used': false,
      });

      return otp;
    } catch (e) {
      throw Exception('Failed to generate OTP: $e');
    }
  }

  // Send OTP via email
  Future<void> sendOTPEmail(String email) async {
    try {
      final otp = await saveOTP(email);

      // For a full implementation, you would use a server-side function to send actual emails
      // This is a simplified version that just saves the OTP to the database

      // You can use Supabase Edge Functions or a service like SendGrid, Mailjet, etc.
      // For now, we'll use Supabase's built-in email functionality via an Edge Function
      await _supabase.functions.invoke(
        'send-otp',
        body: {'email': email, 'otp': otp},
      );
    } catch (e) {
      throw Exception('Failed to send OTP email: $e');
    }
  }

  // Verify OTP
  Future<bool> verifyOTP(String email, String otp) async {
    try {
      final response =
          await _supabase
              .from('email_otp')
              .select()
              .eq('email', email)
              .eq('otp', otp)
              .eq('is_used', false)
              .gt('expires_at', DateTime.now().toIso8601String())
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

      if (response == null) {
        return false;
      }

      // Mark OTP as used
      await _supabase
          .from('email_otp')
          .update({'is_used': true})
          .eq('id', response['id']);

      return true;
    } on AuthApiException catch (e) {
      throw AuthApiException(e.message);
    } catch (e) {
      throw Exception('Something went wrong!');
    }
  }

  // For development purposes - get the latest OTP for an email (remove in production)
  Future<String?> getLatestOTP(String email) async {
    try {
      final response =
          await _supabase
              .from('email_otp')
              .select('otp')
              .eq('email', email)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

      return response?['otp'];
    } catch (e) {
      return null;
    }
  }
}
