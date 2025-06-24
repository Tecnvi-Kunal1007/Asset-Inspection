import 'dart:developer';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  final supabase = Supabase.instance.client;
  bool isLoading = false;

  final AuthService _authService = AuthService();

  Future<void> _sendResetLink() async {
    setState(() {
      isLoading = true;
    });

    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showError("Please enter your email");
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final contractorData =
          await supabase
              .from('contractor')
              .select()
              .eq('email', email)
              .maybeSingle();

      // Check if the user is a site manager
      final siteManagerData =
          await supabase
              .from('freelancer_employee')
              .select()
              .eq('email', email)
              .maybeSingle();

      if (siteManagerData == null && contractorData == null) {
        _showError("User not found!");
        setState(() {
          isLoading = false;
        });
        return;
      }

      await _authService.forgotPassword(email);
      _showSuccess("Password reset link sent to your email");

      // Navigate back to login page after short delay
      if (!mounted) return;
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pop();
      });
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("Failed to send reset link: ${e.toString()}");
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "Reset Password",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                "Enter your email to receive a password reset link",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),

              const SizedBox(height: 30),
              _buildInputField(emailController, "Email", false),

              const SizedBox(height: 30),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _sendResetLink,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: const Color.fromARGB(255, 49, 69, 106),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(48),
                    ),
                  ),
                  child:
                      isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            'Send Reset Link',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildInputField(
  TextEditingController controller,
  String hintText,
  bool isPassword, {
  bool enabled = true,
}) {
  return Material(
    elevation: 8,
    shadowColor: Colors.black.withOpacity(0.8),
    borderRadius: BorderRadius.circular(12),
    child: TextField(
      obscureText: isPassword,
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}
