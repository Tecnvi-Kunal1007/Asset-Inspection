// email_service.dart
import 'dart:math';
import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ✅ Generate a random 6-digit OTP
  String _generateOTP() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  // ✅ Save OTP to Supabase
  Future<String> saveOTP(String email) async {
    try {
      final otp = _generateOTP();

      await _supabase.from('email_otp').insert({
        'email': email,
        'otp': otp,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
        'is_used': false,
      });

      return otp;
    } catch (e) {
      throw Exception('❌ Failed to save OTP: $e');
    }
  }

  // ✅ Send OTP via Supabase Edge Function
  Future<void> sendOTPEmail(String email) async {
    try {
      final otp = await saveOTP(email);

      final response = await _supabase.functions.invoke(
        'clever-function', // ✅ NO `.ts`
        body: {'email': email, 'otp': otp},
      );

      if (response.status != 200) {
        throw Exception('OTP send failed: ${response.data}');
      }
    } catch (e) {
      throw Exception('❌ OTP email send failed: $e');
    }
  }

  // ✅ Verify OTP
  Future<bool> verifyOTP(String email, String otp) async {
    try {
      final response = await _supabase
          .from('email_otp')
          .select()
          .eq('email', email)
          .eq('otp', otp)
          .eq('is_used', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return false;

      await _supabase.from('email_otp').update({'is_used': true}).eq('id', response['id']);

      return true;
    } catch (e) {
      throw Exception('❌ OTP verification failed: $e');
    }
  }

  // ✅ For dev/test only
  Future<String?> getLatestOTP(String email) async {
    try {
      final response = await _supabase
          .from('email_otp')
          .select('otp')
          .eq('email', email)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response?['otp'];
    } catch (_) {
      return null;
    }
  }
}
