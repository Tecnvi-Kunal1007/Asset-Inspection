import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'dart:math' as math;
import 'dart:ui';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final otpController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final _authService = AuthService();
  bool isLoading = false;
  bool otpSent = false;

  late AnimationController _animationController;
  late AnimationController _cardAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _cardScaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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

    _cardScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _cardAnimationController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _cardAnimationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    emailController.dispose();
    otpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    setState(() => isLoading = true);

    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showError("Please enter your email");
      setState(() => isLoading = false);
      return;
    }

    try {
      // Check if user exists in auth or database
      bool userExists = false;
      try {
        await _authService.forgotPassword(email);
        userExists = true;
      } catch (e) {
        // Fallback: check database tables
        final contractorData = await Supabase.instance.client
            .from('contractor')
            .select()
            .eq('email', email)
            .maybeSingle();

        final siteManagerData = await Supabase.instance.client
            .from('freelancer_employee')
            .select()
            .eq('email', email)
            .maybeSingle();

        if (contractorData == null && siteManagerData == null) {
          _showError("User not found!");
          setState(() => isLoading = false);
          return;
        }
      }

      if (userExists) {
        setState(() => otpSent = true);
        _showSuccess("OTP sent to your email");
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError("Failed to send OTP: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _verifyAndResetPassword() async {
    setState(() => isLoading = true);

    final email = emailController.text.trim();
    final otp = otpController.text.trim();
    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (otp.isEmpty) {
      _showError("Please enter the OTP");
      setState(() => isLoading = false);
      return;
    }
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError("Please enter and confirm your new password");
      setState(() => isLoading = false);
      return;
    }
    if (newPassword != confirmPassword) {
      _showError("Passwords do not match");
      setState(() => isLoading = false);
      return;
    }

    try {
      // Fix: Use positional parameters instead of named parameters
      final success = await _authService.verifyResetAndUpdatePassword(
        email,
        otp,
        newPassword,
      );
      
      if (success && mounted) {
        _showSuccess("Password reset successful");
        Navigator.pop(context); // Return to login page
      } else {
        _showError("Failed to reset password. Please try again.");
      }
    } on AuthException catch (e) {
      _showError("Invalid OTP or error: ${e.message}");
    } catch (e) {
      _showError("Failed to reset password: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
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
              const Color(0xFF0F0C29),
              const Color(0xFF24243e),
              const Color(0xFF302B63),
              const Color(0xFF0F0C29),
            ],
            stops: [0.0, 0.4, 0.8, 1.0],
          ),
        ),
        child: Stack(
          children: [
            _buildParticleBackground(),
            _buildFloatingShapes(screenWidth, screenHeight),
            SafeArea(
              child: Positioned(
                top: 20,
                left: 20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.2),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).scale(
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: ScaleTransition(
                          scale: _cardScaleAnimation,
                          child: _buildForgotPasswordCard(screenWidth, screenHeight),
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
      children: List.generate(15, (index) {
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
                  width: 3 + (index % 3) * 2,
                  height: 3 + (index % 3) * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amber.withOpacity(0.4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
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
        Positioned(
          top: screenHeight * 0.15,
          right: -40,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.2),
                  Colors.red.withOpacity(0.1),
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
        Positioned(
          bottom: screenHeight * 0.25,
          left: -25,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withOpacity(0.15),
                    Colors.indigo.withOpacity(0.08),
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

  Widget _buildForgotPasswordCard(double screenWidth, double screenHeight) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: screenWidth > 600 ? 450 : screenWidth * 0.9,
        maxHeight: screenHeight * 0.85,
      ),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.25),
            Colors.white.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildInputFields(),
                  const SizedBox(height: 30),
                  _buildActionButton(),
                  if (otpSent) ...[
                    const SizedBox(height: 20),
                    _buildResendButton(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.lock_reset,
            size: 40,
            color: Colors.white,
          ),
        )
            .animate()
            .scale(duration: 800.ms, curve: Curves.elasticOut)
            .then()
            .shimmer(
          duration: 2000.ms,
          color: Colors.white.withOpacity(0.5),
        ),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFE0E7FF)],
          ).createShader(bounds),
          child: Text(
            'Reset Password',
            style: GoogleFonts.poppins(
              fontSize: 28,
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
          otpSent
              ? "Enter the verification code and new password"
              : "Enter your email to receive a verification code",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 400.ms)
            .slideY(begin: 0.3, end: 0),
      ],
    );
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        _buildModernTextField(
          controller: emailController,
          label: 'Email',
          hint: 'Enter your email address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !otpSent,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 600.ms)
            .slideX(begin: -0.2, end: 0),
        if (otpSent) ...[
          const SizedBox(height: 20),
          _buildModernTextField(
            controller: otpController,
            label: 'Verification Code',
            hint: 'Enter 6-digit code',
            icon: Icons.verified_user_outlined,
            keyboardType: TextInputType.number,
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 700.ms)
              .slideX(begin: -0.2, end: 0),
          const SizedBox(height: 20),
          _buildModernTextField(
            controller: newPasswordController,
            label: 'New Password',
            hint: 'Enter new password',
            icon: Icons.lock_outline,
            keyboardType: TextInputType.text,
            obscureText: true,
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 800.ms)
              .slideX(begin: -0.2, end: 0),
          const SizedBox(height: 20),
          _buildModernTextField(
            controller: confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Confirm new password',
            icon: Icons.lock_outline,
            keyboardType: TextInputType.text,
            obscureText: true,
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 900.ms)
              .slideX(begin: -0.2, end: 0),
        ],
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(enabled ? 0.2 : 0.1),
            Colors.white.withOpacity(enabled ? 0.1 : 0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(enabled ? 0.3 : 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        obscureText: obscureText,
        style: GoogleFonts.poppins(
          color: enabled ? Colors.white : Colors.white.withOpacity(0.7),
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: GoogleFonts.poppins(
            color: Colors.white.withOpacity(enabled ? 0.8 : 0.6),
            fontSize: 14,
          ),
          hintStyle: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withOpacity(enabled ? 0.8 : 0.6),
            size: 22,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
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
            color: const Color(0xFFFF6B6B).withOpacity(0.4),
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
        onPressed: isLoading ? null : (otpSent ? _verifyAndResetPassword : _sendOTP),
        child: isLoading
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
            Icon(
              otpSent ? Icons.verified : Icons.send,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              otpSent ? 'Reset Password' : 'Send Code',
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
        .fadeIn(duration: 600.ms, delay: 800.ms)
        .slideY(begin: 0.3, end: 0)
        .shimmer(duration: 2000.ms, delay: 1500.ms);
  }

  Widget _buildResendButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : _sendOTP,
        icon: const Icon(
          Icons.refresh,
          color: Colors.white,
          size: 18,
        ),
        label: Text(
          'Resend Code',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 900.ms);
  }
}