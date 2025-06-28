import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../screens/verification_page.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<StatefulWidget> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with TickerProviderStateMixin {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final List<String> _roles = ['Contractor', 'Freelancer-Employee'];
  String selectedRole = '';
  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  void toggleConfirmPasswordVisibility() {
    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
  }

  Future<void> _signUp() async {
    setState(() => isLoading = true);

    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError("Please fill all fields!");
      setState(() => isLoading = false);
      return;
    }
    if (password != confirmPassword) {
      _showError("Passwords don't match!");
      setState(() => isLoading = false);
      return;
    }
    if (selectedRole.isEmpty) {
      _showError("Please select a role!");
      setState(() => isLoading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // Check if email already exists in either role table
      final contractorData = await supabase.from('contractor').select().eq('email', email).maybeSingle();
      final freelancerData = await supabase.from('freelancer_employee').select().eq('email', email).maybeSingle();

      log("hey");

      if (contractorData != null || freelancerData != null) {
        _showError("User already registered!");
        setState(() => isLoading = false);
        return;
      }

      // Send OTP
      log("⏳ Sending OTP to $email");
      await _authService.sendRegistrationOTP(email);
      log("✅ OTP sent successfully");

      if (!mounted) return;

      // Navigate to verification page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            role: selectedRole,
            email: email,
            name: name,
            password: password,
          ),
        ),
      );
    } catch (e) {
      log("❌ Error sending verification email: $e");
      _showError("Error sending verification email: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 48 : 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Account',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    _buildInputField(nameController, 'Full Name', Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildInputField(emailController, 'Email Address', Icons.email_outlined),
                    const SizedBox(height: 16),
                    _buildPasswordField(passwordController, 'Password', _obscurePassword, togglePasswordVisibility),
                    const SizedBox(height: 16),
                    _buildPasswordField(confirmPasswordController, 'Confirm Password', _obscureConfirmPassword, toggleConfirmPasswordVisibility),
                    const SizedBox(height: 16),
                    _buildRoleDropdown(),
                    const SizedBox(height: 24),
                    _buildSignUpButton(),
                    const SizedBox(height: 20),
                    _buildLoginLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label, bool obscureText, VoidCallback toggle) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedRole.isEmpty ? null : selectedRole,
      items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
      onChanged: (value) => setState(() => selectedRole = value!),
      decoration: InputDecoration(
        labelText: 'Select Role',
        prefixIcon: const Icon(Icons.work_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return ElevatedButton(
      onPressed: isLoading ? null : _signUp,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF667eea),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account?"),
        TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
          child: const Text("Sign In", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
