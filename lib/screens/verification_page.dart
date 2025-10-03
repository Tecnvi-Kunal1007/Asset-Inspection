import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../screens/contractor_dashboard_screen.dart';
import '../screens/site_manager_dashboard.dart';

class OtpScreen extends StatefulWidget {
  final String role;
  final String email;
  final String name;
  final String password;

  const OtpScreen({
    super.key,
    required this.role,
    required this.email,
    required this.name,
    required this.password,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> otpControllers =
  List.generate(6, (index) => TextEditingController());
  final List<FocusNode> focusNodes =
  List.generate(6, (index) => FocusNode());
  final _authService = AuthService();

  bool isLoading = false;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  String get otpCode => otpControllers.map((c) => c.text).join();

  Future<void> _verifyOtp() async {
    if (otpCode.length != 6) {
      _showError('Please enter complete OTP');
      return;
    }

    setState(() => isLoading = true);
    HapticFeedback.lightImpact();

    try {
      final response = await _authService.verifyAndRegister(
        email: widget.email,
        otp: otpCode,
        password: widget.password,
        name: widget.name,
        role: widget.role,
      );

      if (response.user != null) {
        final userId = response.user!.id;
        final role = await _authService.getUserRole(userId);
        if (!mounted) return;

        HapticFeedback.mediumImpact();

        if (role == 'Contractor') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ContractorDashboardScreen()),
          );
        } else if (role == 'Freelancer-Employee') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SiteManagerDashboard()),
          );
        } else {
          _showError('Invalid role. Please contact support.');
        }
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      _showError('Invalid OTP. Please try again.');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      focusNodes[index - 1].requestFocus();
    }

    if (otpCode.length == 6) {
      _verifyOtp();
    }
  }

  void _clearOtp() {
    for (var controller in otpControllers) {
      controller.clear();
    }
    focusNodes[0].requestFocus();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE74C3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Clear',
          textColor: Colors.white,
          onPressed: _clearOtp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final maxWidth = isTablet ? 500.0 : screenSize.width * 0.9;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF1E293B),
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Verify OTP',
          style: GoogleFonts.poppins(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 40 : 24,
              vertical: 32,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // OTP Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF667EEA).withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.security,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),

                      SizedBox(height: isTablet ? 40 : 32),

                      // Title
                      Text(
                        'Verification Code',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 28 : 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1E293B),
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: isTablet ? 16 : 12),

                      // Subtitle
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 16 : 14,
                            color: const Color(0xFF64748B),
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(text: 'We sent a verification code to\n'),
                            TextSpan(
                              text: widget.email,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF667EEA),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 48 : 40),

                      // OTP Input Fields
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(6, (index) {
                                return Container(
                                  width: isTablet ? 55 : 45,
                                  height: isTablet ? 55 : 45,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: focusNodes[index].hasFocus
                                          ? const Color(0xFF667EEA)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: otpControllers[index],
                                    focusNode: focusNodes[index],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 24 : 20,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1E293B),
                                    ),
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (value) => _onOtpChanged(value, index),
                                  ),
                                );
                              }),
                            ),

                            const SizedBox(height: 24),

                            // Verify Button
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: (isLoading || otpCode.length != 6)
                                    ? null
                                    : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF667EEA),
                                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
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
                                    : Text(
                                  'Verify & Continue',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isTablet ? 32 : 24),

                      // Resend Code Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive the code? ",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          TextButton(
                            onPressed: isLoading ? null : () {
                              // Add resend OTP logic here
                              HapticFeedback.lightImpact();
                              _showError('Resend feature coming soon!');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            child: Text(
                              'Resend',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}