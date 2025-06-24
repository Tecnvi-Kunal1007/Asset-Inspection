import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class ResetPasswordCallback extends StatefulWidget {
  const ResetPasswordCallback({Key? key}) : super(key: key);

  @override
  State<ResetPasswordCallback> createState() => _ResetPasswordCallbackState();
}

class _ResetPasswordCallbackState extends State<ResetPasswordCallback> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  final _authService = AuthService();

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  Future<void> _resetPassword() async {
    setState(() {
      _isLoading = true;
    });

    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError("Please fill all fields");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (newPassword != confirmPassword) {
      _showError("Passwords don't match");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (newPassword.length < 6) {
      _showError("Password must be at least 6 characters");
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      await _authService.resetPassword(newPassword);
      _showSuccess("Password reset successful");

      // Navigate to login page after short delay
      if (!mounted) return;
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      });
    } catch (e) {
      _showError("Failed to reset password: ${e.toString()}");
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                const Text(
                  "Set New Password",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),
                _buildInputField(_newPasswordController, "New Password", true),
                const SizedBox(height: 20),
                Material(
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    obscureText: _obscureText,
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      hintText: "Confirm Password",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        onPressed: _togglePasswordVisibility,
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color.fromARGB(255, 49, 69, 106),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(48),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text(
                              'Reset Password',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildInputField(
  TextEditingController controller,
  String hintText,
  bool isPassword,
) {
  return Material(
    elevation: 8,
    shadowColor: Colors.black.withOpacity(0.8),
    borderRadius: BorderRadius.circular(12),
    child: TextField(
      obscureText: isPassword,
      controller: controller,
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
