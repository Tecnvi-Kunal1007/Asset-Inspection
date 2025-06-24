// verification_page.dart
import 'dart:developer';

import '../screens/contractor_dashboard_screen.dart';
import '../screens/site_manager_dashboard.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String name;
  final String password;
  final String role;

  const OtpScreen({
    Key? key,
    required this.email,
    required this.name,
    required this.password,
    required this.role,
  }) : super(key: key);

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  final List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());

  bool isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void dispose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    setState(() {
      isLoading = true;
    });

    final otp = otpControllers.map((e) => e.text).join();

    if (otp.length != 6) {
      _showError("Please enter the complete verification code");
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Verify OTP
      final isValid = await _authService.verifyOTP(widget.email, otp);

      log(isValid.toString());

      if (isValid) {
        // Register user after verification
        await _authService.registerUser(
          email: widget.email,
          password: widget.password,
          name: widget.name,
          role: widget.role,
        );

        if (!mounted) return;

        // Show success message
        _showSuccess("Registration successful!");

        // Navigate to login page after short delay
        Future.delayed(const Duration(seconds: 1), () {
          // Navigate back to login screen
          if (widget.role == "Contractor")
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const ContractorDashboardScreen(),
              ),
            );
          else
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const SiteManagerDashboard(),
              ),
            );
        });
      } else {
        _showError("Invalid verification code");
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("Verification failed: ${e}");
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      isLoading = true;
    });

    try {
      await _authService.sendRegistrationOTP(widget.email);
      _showSuccess("Verification code resent");

      // Clear text fields
      for (var controller in otpControllers) {
        controller.clear();
      }

      // Focus on first field
      FocusScope.of(context).requestFocus(focusNodes[0]);
    } catch (e) {
      _showError("Failed to resend verification code: ${e.toString()}");
    }

    setState(() {
      isLoading = false;
    });
  }

  String maskEmail(String email) {
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    final visible = name.substring(0, 1);
    return '$visible${'*' * (name.length - 1)}@$domain';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.red)),
        backgroundColor: Colors.white,
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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Lottie.asset(
                  'assets/animations/verification.json',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 20),
                Text(
                  "Verification!",
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 40,
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  "We've sent a verification code to ${maskEmail(widget.email)}",
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge!.copyWith(color: Colors.black54),
                ),

                const SizedBox(height: 40),
                // OTP fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) => _buildOtpField(index)),
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: Color.fromARGB(255, 49, 69, 106),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(48),
                      ),
                    ),
                    child:
                        isLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Verify',
                              style: TextStyle(
                                fontSize: 25,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Didn't receive the code?"),
                    TextButton(
                      onPressed: isLoading ? null : _resendOtp,
                      child: const Text(
                        "Resend",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    return SizedBox(
      width: 50,
      height: 60,
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        child: TextField(
          controller: otpControllers[index],
          focusNode: focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          maxLength: 1,
          decoration: InputDecoration(
            counter: const SizedBox.shrink(),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            if (value.isNotEmpty) {
              // Move to next field
              if (index < 5) {
                FocusScope.of(context).requestFocus(focusNodes[index + 1]);
              } else {
                // Last field, hide keyboard
                FocusScope.of(context).unfocus();
              }
            } else if (value.isEmpty && index > 0) {
              // Move to previous field on backspace
              FocusScope.of(context).requestFocus(focusNodes[index - 1]);
            }
          },
        ),
      ),
    );
  }
}
