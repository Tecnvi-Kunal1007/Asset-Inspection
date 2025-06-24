// signup_page.dart
import 'dart:developer';

import '../services/auth_service.dart';
import '../screens/verification_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lottie/lottie.dart';

import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<StatefulWidget> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final List<String> _roles = ['Contractor', 'Freelancer-Employee'];

  String selectedRole = ''; // Default role
  bool isLoading = false;
  bool _obscureText = true;

  final AuthService _authService = AuthService();

  void togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  Future<void> _signUp() async {
    setState(() {
      isLoading = true;
    });

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    // Validation
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError("Please fill all fields!");
      setState(() {
        isLoading = false;
      });
      return;
    }

    if (password != confirmPassword) {
      _showError("Passwords don't match!");
      setState(() {
        isLoading = false;
      });
      return;
    }

    final supabase = Supabase.instance.client;

    final contractorData = await supabase
        .from('contractor')
        .select()
        .eq('email', email)
        .maybeSingle();

    if (contractorData != null) {
      _showError("User already registered!");
      setState(() {
        isLoading = false;
      });
      return;
    }

    // Check if the user is a site manager
    final siteManagerData = await supabase
        .from('freelancer_employee')
        .select()
        .eq('email', email)
        .maybeSingle();

    if (siteManagerData != null) {
      _showError("User already registered!");
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // Send OTP to email for verification
      await _authService.sendRegistrationOTP(email);

      // Navigate to verification page
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpScreen(
            role: selectedRole,
            email: email,
            name: name,
            password: password,
          ),
        ),
      );
    } catch (e) {
      _showError('Error sending verification email: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showError(String message) {
    log(message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Lottie.asset(
                  'assets/animations/Signup_animation.json',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    )
                ),

                const SizedBox(height: 20),
                _buildInputField(nameController, "Full Name", false),
                const SizedBox(height: 20),
                _buildInputField(emailController, "Email", false),
                const SizedBox(height: 20),
                _buildInputField(passwordController, "Password", true),
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
                            icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility)
                        )
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Material(
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),

                  child: DropdownButtonFormField<String>(
                    hint: Text("Select the Role"),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),

                    icon: Icon(Icons.keyboard_arrow_down),
                    dropdownColor: Color.fromARGB(240,244,247,255),

                    items: _roles.map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value!;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      backgroundColor: Color.fromARGB(255,49,69,106),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Register',
                      style: TextStyle(
                        fontSize: 25,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Divider
                Row(
                  children: const [
                    Expanded(child: Divider(thickness: 1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('OR'),
                    ),
                    Expanded(child: Divider(thickness: 1)),
                  ],
                ),

                const SizedBox(height: 10),

                // Login with Google
                ElevatedButton(
                  onPressed: () {
                    // button action
                  },

                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Image.asset(
                    'assets/images/google_icon.jpeg',
                    width: 35,
                    height: 35,
                  ),
                  //   child: Row(
                  //     mainAxisSize: MainAxisSize.max,
                  //     mainAxisAlignment: MainAxisAlignment.start,
                  //     children: [
                  //       Image.asset(
                  //         'assets/google_icon (2).png',
                  //         width: 25,
                  //         height: 25,
                  //       ),
                  //       Padding(
                  //         padding: EdgeInsets.only(left: 65),
                  //         child: Text(
                  //           'Login with Google',
                  //           style: TextStyle(
                  //               color: Colors.indigo,
                  //               fontSize: 20
                  //           ),
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                ),

                // Sign up option
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                      },
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Color.fromARGB(240,244,247,255),
    );
  }
}

Widget _buildInputField(TextEditingController controller, String hintText, bool isPassword) {
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