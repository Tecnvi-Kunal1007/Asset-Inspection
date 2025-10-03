import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../screens/verification_page.dart';
import 'login_page.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui';

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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
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
    if (!_roles.contains(selectedRole)) {
      _showError("Please select a valid role!");
      setState(() => isLoading = false);
      return;
    }

    try {
      await _authService.sendRegistrationOTP(email);
      if (!mounted) return;

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
      _showError("Error sending OTP: $e");
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
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
              const Color(0xFF667eea).withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated particle background
            _buildParticleBackground(),

            // Floating geometric shapes
            _buildFloatingShapes(screenWidth, screenHeight),

            // Main content with glassmorphism
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildModernSignUpCard(
                          screenWidth,
                          screenHeight,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticleBackground() {
    return Stack(
      children: List.generate(20, (index) {
        return Positioned(
          left: math.Random().nextDouble() * 400,
          top: math.Random().nextDouble() * 800,
          child: TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 3000 + (index * 200)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(
                  math.sin(value * 2 * math.pi) * 30,
                  math.cos(value * 2 * math.pi) * 20,
                ),
                child: Container(
                  width: 4 + (index % 3) * 2,
                  height: 4 + (index % 3) * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildFloatingShapes(double screenWidth, double screenHeight) {
    return Stack(
      children: [
        // Large floating circle
        Positioned(
          top: screenHeight * 0.1,
          right: -50,
          child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                duration: 4000.ms,
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.2, 1.2),
              )
              .then()
              .scale(
                duration: 4000.ms,
                begin: const Offset(1.2, 1.2),
                end: const Offset(0.8, 0.8),
              ),
        ),

        // Medium floating square
        Positioned(
          bottom: screenHeight * 0.2,
          left: -30,
          child: Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                      ],
                    ),
                  ),
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 8000.ms),
        ),
      ],
    );
  }

  Widget _buildModernSignUpCard(double screenWidth, double screenHeight) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: screenWidth > 600 ? 500 : screenWidth * 0.9,
        maxHeight: screenHeight * 0.95,
      ),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.25),
            Colors.white.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModernHeader(),
                  const SizedBox(height: 20),
                  _buildModernInputFields(),
                  const SizedBox(height: 16),
                  _buildModernRoleSelection(),
                  const SizedBox(height: 20),
                  _buildModernSignUpButton(),
                  const SizedBox(height: 12),
                  _buildModernLoginLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Column(
      children: [
        // Logo with glow effect
        Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.3),
                    Colors.white.withValues(alpha: 0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_add,
                size: 40,
                color: Colors.white,
              ),
            )
            .animate()
            .scale(duration: 800.ms, curve: Curves.elasticOut)
            .then()
            .shimmer(
              duration: 2000.ms,
              color: Colors.white.withValues(alpha: 0.5),
            ),

        const SizedBox(height: 24),

        // Welcome text with gradient
        ShaderMask(
              shaderCallback:
                  (bounds) => const LinearGradient(
                    colors: [Colors.white, Color(0xFFE0E7FF)],
                  ).createShader(bounds),
              child: Text(
                'Join Us Today',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms)
            .slideY(begin: 0.3, end: 0),

        const SizedBox(height: 8),

        Text(
              'Create your account to get started',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 400.ms)
            .slideY(begin: 0.3, end: 0),
      ],
    );
  }

  Widget _buildModernInputFields() {
    return Column(
      children: [
        // Name field
        _buildModernTextField(
              controller: nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              icon: Icons.person_outline,
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 600.ms)
            .slideX(begin: -0.2, end: 0),

        const SizedBox(height: 20),

        // Email field
        _buildModernTextField(
              controller: emailController,
              label: 'Email',
              hint: 'Enter your email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 700.ms)
            .slideX(begin: -0.2, end: 0),

        const SizedBox(height: 20),

        // Password field
        _buildModernTextField(
              controller: passwordController,
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              isPassword: true,
              obscureText: _obscurePassword,
              onToggleVisibility: togglePasswordVisibility,
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 800.ms)
            .slideX(begin: -0.2, end: 0),

        const SizedBox(height: 20),

        // Confirm Password field
        _buildModernTextField(
              controller: confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Confirm your password',
              icon: Icons.lock_outline,
              isPassword: true,
              obscureText: _obscureConfirmPassword,
              onToggleVisibility: toggleConfirmPasswordVisibility,
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 900.ms)
            .slideX(begin: -0.2, end: 0),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.2),
            Colors.white.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword ? obscureText : false,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
          hintStyle: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.8),
            size: 22,
          ),
          suffixIcon:
              isPassword
                  ? IconButton(
                    onPressed: onToggleVisibility,
                    icon: Icon(
                      obscureText ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 22,
                    ),
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildModernRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Role',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 1000.ms),

        const SizedBox(height: 16),

        Row(
              children:
                  _roles.map((role) {
                    final isSelected = selectedRole == role;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => selectedRole = role),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors:
                                  isSelected
                                      ? [
                                        const Color(
                                          0xFFFF6B6B,
                                        ).withValues(alpha: 0.3),
                                        const Color(
                                          0xFFFF8E53,
                                        ).withValues(alpha: 0.2),
                                      ]
                                      : [
                                        Colors.white.withValues(alpha: 0.1),
                                        Colors.white.withValues(alpha: 0.05),
                                      ],
                            ),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? const Color(
                                        0xFFFF6B6B,
                                      ).withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFFFF6B6B,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 15,
                                        spreadRadius: 0,
                                      ),
                                    ]
                                    : null,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                role == 'Contractor'
                                    ? Icons.engineering
                                    : Icons.work,
                                color:
                                    isSelected
                                        ? const Color(0xFFFF6B6B)
                                        : Colors.white.withValues(alpha: 0.8),
                                size: 32,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                role,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            )
            .animate()
            .fadeIn(duration: 600.ms, delay: 1100.ms)
            .slideY(begin: 0.3, end: 0),
      ],
    );
  }

  Widget _buildModernSignUpButton() {
    return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53), Color(0xFFFF6B6B)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: isLoading ? null : _signUp,
            child:
                isLoading
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_add,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Create Account',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
          ),
        )
        .animate()
        .fadeIn(duration: 600.ms, delay: 1200.ms)
        .slideY(begin: 0.3, end: 0)
        .shimmer(duration: 2000.ms, delay: 1500.ms);
  }

  Widget _buildModernLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              await Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            } catch (e) {
              print('Navigation error: $e');
            }
          },
          child: Text(
            'Sign In',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFF6B6B),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms, delay: 1300.ms);
  }
}
