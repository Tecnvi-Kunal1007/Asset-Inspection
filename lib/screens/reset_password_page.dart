import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../services/auth_service.dart'; // Import AuthService

class ResetPasswordPage extends StatefulWidget {
  final String email;

  const ResetPasswordPage({Key? key, required this.email}) : super(key: key);

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with TickerProviderStateMixin {
  final otpController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isOtpVerified = false; // New state to toggle steps

  final AuthService _authService = AuthService(); // Use AuthService instance
  final _supabase = Supabase.instance.client;

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
    otpController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void toggleNewPasswordVisibility() {
    setState(() => _obscureNewPassword = !_obscureNewPassword);
  }

  void toggleConfirmPasswordVisibility() {
    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
  }

  Future<void> _verifyOTP() async {
    setState(() => isLoading = true);

    final otp = otpController.text;

    if (otp.isEmpty) {
      _showError("Please enter the OTP");
      setState(() => isLoading = false);
      return;
    }

    try {
      await _authService.verifyResetOTP(
        email: widget.email,
        otp: otp,
      );
      setState(() {
        _isOtpVerified = true;
        isLoading = false;
      });
      _showMessage("OTP verified! Set your new password.");
    } catch (e) {
      _showError("Failed to verify OTP: ${e.toString()}");
      setState(() => isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    setState(() => isLoading = true);

    final newPassword = newPasswordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError("Please fill all fields");
      setState(() => isLoading = false);
      return;
    }

    if (newPassword != confirmPassword) {
      _showError("Passwords don't match");
      setState(() => isLoading = false);
      return;
    }

    if (newPassword.length < 6) {
      _showError("Password must be at least 6 characters");
      setState(() => isLoading = false);
      return;
    }

    try {
      await _authService.updatePasswordAfterOTP(
        email: widget.email,
        newPassword: newPassword,
      );
      _showMessage("Password reset successful! Redirecting to login...");
      if (!mounted) return;
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    } catch (e) {
      _showError("Failed to reset password: ${e.toString()}");
    }

    setState(() => isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
              Color(0xFF533483),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
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
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms).scale(duration: 600.ms, curve: Curves.elasticOut),
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
                          child: _buildResetPasswordCard(screenWidth, screenHeight),
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
                    color: Colors.cyan.withValues(alpha: 0.4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withValues(alpha: 0.3),
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
                  Colors.purple.withValues(alpha: 0.2),
                  Colors.pink.withValues(alpha: 0.1),
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
                    Colors.blue.withValues(alpha: 0.15),
                    Colors.teal.withValues(alpha: 0.08),
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

  Widget _buildResetPasswordCard(double screenWidth, double screenHeight) {
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
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildPasswordStrengthIndicator(),
                  const SizedBox(height: 20),
                  _buildInputFields(),
                  const SizedBox(height: 30),
                  _buildResetButton(),
                  const SizedBox(height: 20),
                  _buildSecurityTip(),
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
            Icons.security,
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
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Colors.white, Color(0xFFE0E7FF)],
          ).createShader(bounds),
          child: Text(
            'Set New Password',
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
          "Create a strong password for ${widget.email}",
          textAlign: TextAlign.center,
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

  Widget _buildPasswordStrengthIndicator() {
    final password = newPasswordController.text;
    final strength = _calculatePasswordStrength(password);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.1),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Strength',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: strength / 4,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: LinearGradient(
                          colors: _getStrengthColors(strength),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getStrengthText(strength),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _getStrengthColors(strength)[0],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 500.ms);
  }

  Widget _buildInputFields() {
    return Column(
      children: [
        _buildModernTextField(
          controller: otpController,
          label: 'Verification Code',
          hint: 'Enter the OTP from your email',
          icon: Icons.verified_user,
        ).animate().fadeIn(duration: 600.ms, delay: 600.ms).slideX(begin: -0.2, end: 0),
        const SizedBox(height: 20),
        if (_isOtpVerified) ...[
          _buildModernTextField(
            controller: newPasswordController,
            label: 'New Password',
            hint: 'Enter your new password',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscureNewPassword,
            onToggleVisibility: toggleNewPasswordVisibility,
            onChanged: (value) => setState(() {}),
          ).animate().fadeIn(duration: 600.ms, delay: 700.ms).slideX(begin: -0.2, end: 0),
          const SizedBox(height: 20),
          _buildModernTextField(
            controller: confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Confirm your new password',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscureConfirmPassword,
            onToggleVisibility: toggleConfirmPasswordVisibility,
          ).animate().fadeIn(duration: 600.ms, delay: 800.ms).slideX(begin: -0.2, end: 0),
        ],
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
    Function(String)? onChanged,
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
        obscureText: obscureText,
        onChanged: onChanged,
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
          suffixIcon: isPassword
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF45A049), Color(0xFF4CAF50)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
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
        onPressed: isLoading ? null : (_isOtpVerified ? _resetPassword : _verifyOTP),
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
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              _isOtpVerified ? 'Reset Password' : 'Verify OTP',
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

  Widget _buildSecurityTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.1),
            Colors.blue.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.blue.withValues(alpha: 0.8),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Use a mix of letters, numbers, and symbols for a strong password',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 900.ms);
  }

  int _calculatePasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 6) strength++;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#\$%^&*~]').hasMatch(password)) strength++;
    return strength > 4 ? 4 : strength;
  }

  List<Color> _getStrengthColors(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)];
      case 2:
        return [const Color(0xFFFFD93D), const Color(0xFFFFA726)];
      case 3:
        return [const Color(0xFF6BCF7F), const Color(0xFF4CAF50)];
      case 4:
        return [const Color(0xFF4CAF50), const Color(0xFF45A049)];
      default:
        return [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)];
    }
  }

  String _getStrengthText(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return 'Weak';
    }
  }
}