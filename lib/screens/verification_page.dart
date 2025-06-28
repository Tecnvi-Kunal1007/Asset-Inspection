// verification_page.dart
import 'dart:developer';

import '../screens/contractor_dashboard_screen.dart';
import '../screens/site_manager_dashboard.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import 'dart:math' as math;

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

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  final List<FocusNode> focusNodes = List.generate(6, (index) => FocusNode());

  bool isLoading = false;
  final AuthService _authService = AuthService();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    _animationController.dispose();
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
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: ThemeHelper.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.backgroundLight,
      body: Stack(
        children: [
          // Background decorations
          Positioned(
            top: -50,
            right: -30,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animationController.value * 2 * math.pi,
                  child: ThemeHelper.floatingElement(
                    size: 180,
                    color: ThemeHelper.indigo,
                    opacity: 0.05,
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 100,
            left: -20,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: -_animationController.value * 2 * math.pi,
                  child: ThemeHelper.floatingElement(
                    size: 150,
                    color: ThemeHelper.purple,
                    opacity: 0.04,
                  ),
                );
              },
            ),
          ),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: ResponsiveHelper.getPadding(context),
                child: ResponsiveHelper.responsiveWidget(
                  context: context,
                  mobile: _buildMobileLayout(),
                  tablet: _buildTabletLayout(),
                  desktop: _buildDesktopLayout(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMobileLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAnimationSection(),
        const SizedBox(height: 20),
        _buildHeaderSection(),
        const SizedBox(height: 40),
        _buildOtpSection(),
        const SizedBox(height: 40),
        _buildVerifyButton(),
        const SizedBox(height: 24),
        _buildResendSection(),
      ],
    );
  }
  
  Widget _buildTabletLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAnimationSection(),
        const SizedBox(height: 30),
        _buildHeaderSection(),
        const SizedBox(height: 50),
        _buildOtpSection(),
        const SizedBox(height: 50),
        _buildVerifyButton(),
        const SizedBox(height: 30),
        _buildResendSection(),
      ],
    );
  }
  
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAnimationSection(height: 300),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeaderSection(),
                const SizedBox(height: 50),
                _buildOtpSection(),
                const SizedBox(height: 50),
                _buildVerifyButton(),
                const SizedBox(height: 30),
                _buildResendSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAnimationSection({double? height}) {
    return Lottie.asset(
      'assets/animations/verification.json',
      width: height ?? 180,
      height: height ?? 180,
      fit: BoxFit.contain,
    );
  }
  
  Widget _buildHeaderSection() {
    return Column(
      children: [
        Text(
          "Verification!",
          style: ThemeHelper.headingStyle(context, color: ThemeHelper.indigo).copyWith(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveHelper.getFontSize(context, 40),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "We've sent a verification code to ${maskEmail(widget.email)}",
          textAlign: TextAlign.center,
          style: ThemeHelper.bodyStyle(context, color: ThemeHelper.textSecondary).copyWith(
            fontSize: ResponsiveHelper.getFontSize(context, 16),
          ),
        ),
      ],
    );
  }
  
  Widget _buildOtpSection() {
    double fieldWidth = ResponsiveHelper.isMobile(context) ? 50 : 60;
    double fieldHeight = ResponsiveHelper.isMobile(context) ? 60 : 70;
    double fontSize = ResponsiveHelper.isMobile(context) ? 24 : 28;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        6,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: fieldWidth,
          height: fieldHeight,
          child: _buildOtpField(index, fontSize),
        ),
      ),
    );
  }
  
  Widget _buildVerifyButton() {
    return SizedBox(
      width: ResponsiveHelper.isMobile(context) ? 200 : 250,
      height: ResponsiveHelper.isMobile(context) ? 50 : 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : _verifyOtp,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: ThemeHelper.indigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(48),
          ),
          elevation: 8,
          shadowColor: ThemeHelper.indigo.withOpacity(0.5),
        ),
        child: isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Verify',
                style: TextStyle(
                  fontSize: ResponsiveHelper.getFontSize(context, 25),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
  
  Widget _buildResendSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Didn't receive the code?",
          style: ThemeHelper.bodyStyle(context),
        ),
        TextButton(
          onPressed: isLoading ? null : _resendOtp,
          style: TextButton.styleFrom(
            foregroundColor: ThemeHelper.indigo,
          ),
          child: Text(
            "Resend",
            style: ThemeHelper.bodyStyle(context, color: ThemeHelper.indigo).copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpField(int index, double fontSize) {
    return Material(
      elevation: 8,
      shadowColor: ThemeHelper.indigo.withOpacity(0.3),
      borderRadius: BorderRadius.circular(16),
      child: TextField(
        controller: otpControllers[index],
        focusNode: focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: ThemeHelper.textPrimary,
        ),
        maxLength: 1,
        decoration: InputDecoration(
          counter: const SizedBox.shrink(),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: ThemeHelper.indigo, width: 2),
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
    );
  }
}
