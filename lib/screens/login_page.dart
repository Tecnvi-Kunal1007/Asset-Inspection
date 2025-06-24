// login_page.dart
import '../screens/contractor_dashboard_screen.dart';
import '../screens/site_manager_dashboard.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/signup_page.dart';
import '../screens/forgot_password_page.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  bool _obscureText = true;

  final AuthService _authService = AuthService();

  void togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  Future<void> _login() async {
    setState(() {
      isLoading = true;
    });

    final email = emailController.text.trim();
    final password = passwordController.text;

    // Validation
    if (email.isEmpty || password.isEmpty) {
      _showError("Please fill all fields");
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final response = await _authService.loginUser(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Determine user role and navigate to appropriate screen
        final role = await _authService.getUserRole();

        if (!mounted) return;

        // Navigate to the appropriate home screen based on role
        // You'll need to create these screens or replace with your actual navigation
        if (role == 'Contractor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const ContractorDashboardScreen(),
            ),
          );
        } else if (role == 'SiteManager') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const SiteManagerDashboard(),
            ),
          );
        } else {
          _showError('Unknown user role');
        }
      }
    } on AuthException catch (e) {
      _showError('Login failed: ${e.message.toString()}');
    } catch (e) {
      _showError('$e');
    }

    setState(() {
      isLoading = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
                Image.asset(
                  'assets/images/logo.jpeg',
                  width: 175,
                  height: 175,
                  fit: BoxFit.contain,
                ),
                const Text(
                  "Tecnvi-Ninja",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 20),
                _buildInputField(emailController, "Email", false),
                const SizedBox(height: 20),
                Material(
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    obscureText: _obscureText,
                    controller: passwordController,
                    decoration: InputDecoration(
                      hintText: "Password",
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
                const SizedBox(height: 10),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordPage(),
                        ),
                      );
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),

                const SizedBox(height: 10),
                SizedBox(
                  width: 200,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _login,
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
                              'Login',
                              style: TextStyle(
                                fontSize: 25,
                                color: Colors.white,
                              ),
                            ),
                  ),
                ),

                const SizedBox(height: 20),

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

                const SizedBox(height: 20),

                // Login with Google
                ElevatedButton(
                  onPressed: () {
                    // Your button action
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/google_icon.jpeg',
                    width: 35,
                    height: 35,
                  ),
                ),

                const SizedBox(height: 20),

                // Sign up option
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SignUpPage(),
                          ),
                        );
                      },
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 240, 244, 247),
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
