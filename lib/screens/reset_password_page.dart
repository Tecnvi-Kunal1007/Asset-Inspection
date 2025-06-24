// reset_password_page.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;

  const ResetPasswordPage({Key? key, required this.email}) : super(key: key);

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;
  bool _obscureText = true;

  final _supabase = Supabase.instance.client;

  void togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  Future<void> _resetPassword() async {
    setState(() {
      isLoading = true;
    });

    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    // Validation
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError("Please fill all fields");
      setState(() {
        isLoading = false;
      });
      return;
    }

    if (newPassword != confirmPassword) {
      _showError("Passwords don't match");
      setState(() {
        isLoading = false;
      });
      return;
    }

    if (newPassword.length < 6) {
      _showError("Password must be at least 6 characters");
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Update password in Supabase Auth
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));

      _showMessage("Password reset successful");

      // Navigate back to login page after short delay
      if (!mounted) return;

      Future.delayed(const Duration(seconds: 2), () {
        // Navigate back to login screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      });

      // Log out the user
    } on AuthApiException catch (e) {
      _showError("Failed to reset password: ${e.message}");
    } catch (e) {
      _showError("Failed to reset password: ${e.toString()}");
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(message, style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(message, style: TextStyle(color: Colors.white)),
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
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                const Text(
                  "Set New Password",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),
                _buildInputField(newPasswordController, "New Password", true),
                const SizedBox(height: 20),
                Material(
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    obscureText: _obscureText,
                    controller: confirmPasswordController,
                    decoration: InputDecoration(
                      hintText: "Confirm Password",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),

                      suffixIcon: IconButton(
                        onPressed: togglePasswordVisibility,
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
                    onPressed: isLoading ? null : _resetPassword,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color.fromARGB(255, 49, 69, 106),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(48),
                      ),
                    ),
                    child:
                        isLoading
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
