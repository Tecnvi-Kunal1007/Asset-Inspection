import 'package:flutter/material.dart';
import 'package:pump_management_system/screens/signup_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/contractor_dashboard_screen.dart';
import '../screens/site_manager_dashboard.dart';
import '../services/auth_service.dart';
import 'forgot_password_page.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:developer' as dev;

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool _obscureText = true;

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
    _checkSession();
    _listenAuthChanges();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _checkSession() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _navigateToDashboard(session.user.id);
    }
  }

  Future<void> _navigateToDashboard(String userId) async {
    final role = await _authService.getUserRole(userId);
    if (!mounted) return;

    if (role == 'Contractor') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ContractorDashboardScreen(),
        ),
      );
    } else if (role == 'Freelancer-Employee') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const SiteManagerDashboard(),
        ),
      );
    } else {
      _showError('Unknown user role. Please contact admin.');
    }
  }

  void _listenAuthChanges() {
    _authService.authStateChanges.listen((data) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session != null && mounted) {
        final userId = session.user.id;
        dev.log('🔍 Auth state changed: User signed in - $userId');

        // Check if user has a role assigned
        final hasRole = await _authService.userHasRole(userId);

        if (hasRole) {
          // User already has a role, navigate to dashboard
          dev.log('✅ User has existing role, navigating to dashboard');
          _navigateToDashboard(userId);
        } else {
          // New user without role, prompt for role selection
          dev.log('🆕 New user signed in, prompting for role selection');
          final selectedRole = await _showRoleSelectionDialog();

          if (selectedRole != null && mounted) {
            try {
              setState(() {
                isLoading = true;
              });

              // Create user record with selected role
              await _authService.completeGoogleSignIn(selectedRole);

              // Navigate to appropriate dashboard
              _navigateToDashboard(userId);
            } catch (e) {
              _showError('Error completing sign-in: $e');
              await _authService.logout();
            } finally {
              if (mounted) {
                setState(() {
                  isLoading = false;
                });
              }
            }
          } else if (mounted) {
            // User canceled role selection
            await _authService.logout();
            _showError('Role selection canceled. Please try again.');
          }
        }
      }
    });
  }

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

    if (email.isEmpty || password.isEmpty) {
      _showError("Please fill all fields");
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final response = await _authService.loginUser(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final userId = response.user!.id;
        final role = await _authService.getUserRole(userId);
        if (!mounted) return;

        dev.log('🔍 Logged-in user role: $role');

        if (role == null) {
          // New user, prompt for role selection
          final selectedRole = await _showRoleSelectionDialog();
          if (selectedRole != null && mounted) {
            try {
              await _authService.createUserRecord(
                userId: userId,
                email: email,
                role: selectedRole,
                loginProvider: 'email',
              );
              _navigateToDashboard(userId);
            } catch (e) {
              _showError('Error creating user record: $e');
            }
          } else {
            await _authService.logout();
            _showError('Role selection canceled. Please try again.');
          }
        } else {
          // Existing user, redirect based on role
          _navigateToDashboard(userId);
        }
      } else {
        _showError('Login failed. User not found.');
      }
    } catch (e) {
      _showError('Login failed: ${e.toString()}');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      isLoading = true;
    });

    try {
      dev.log('🔄 Starting Google Sign-In...');

      // Start Google OAuth sign-in process
      final success = await _authService.signInWithGoogle();

      if (!success) {
        throw Exception('Google Sign-In initiation failed');
      }

      dev.log('✅ Google Sign-In initiated successfully');
      // The auth state listener will handle the rest when sign-in completes

    } on AuthException catch (e) {
      if (e.message.contains('cancelled') && mounted) {
        _showError('Google Sign-In was canceled.');
      } else if (mounted) {
        _showError('Google Sign-In error: ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Unexpected error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery
        .of(context)
        .size
        .width;
    final screenHeight = MediaQuery
        .of(context)
        .size
        .height;

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
            _buildParticleBackground(),
            _buildFloatingShapes(screenWidth, screenHeight),
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildModernLoginCard(screenWidth, screenHeight),
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

  Widget _buildModernLoginCard(double screenWidth, double screenHeight) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: screenWidth > 600 ? 450 : screenWidth * 0.9,
        maxHeight: screenHeight * 0.9,
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
                  _buildModernHeader(),
                  const SizedBox(height: 30),
                  _buildModernInputFields(),
                  const SizedBox(height: 20),
                  _buildModernLoginButton(),
                  const SizedBox(height: 16),
                  _buildModernDivider(),
                  const SizedBox(height: 16),
                  _buildModernGoogleButton(),
                  const SizedBox(height: 12),
                  _buildModernSignUpLink(),
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
            Icons.engineering,
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
          shaderCallback: (bounds) =>
              const LinearGradient(
                colors: [Colors.white, Color(0xFFE0E7FF)],
              ).createShader(bounds),
          child: Text(
            'Welcome Back',
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
          'Sign in to continue your journey',
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
        _buildModernTextField(
          controller: emailController,
          label: 'Email',
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 600.ms)
            .slideX(begin: -0.2, end: 0),
        const SizedBox(height: 20),
        _buildModernTextField(
          controller: passwordController,
          label: 'Password',
          hint: 'Enter your password',
          icon: Icons.lock_outline,
          isPassword: true,
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 700.ms)
            .slideX(begin: -0.2, end: 0),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () async {
              try {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPasswordPage(),
                  ),
                );
              } catch (e) {
                print('Navigation error: $e');
              }
            },
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 800.ms),
      ],
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
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
        obscureText: isPassword ? _obscureText : false,
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
            onPressed: togglePasswordVisibility,
            icon: Icon(
              _obscureText ? Icons.visibility_off : Icons.visibility,
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

  Widget _buildModernLoginButton() {
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
        onPressed: isLoading ? null : _login,
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
            const Icon(Icons.login, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              'Sign In',
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
        .fadeIn(duration: 600.ms, delay: 900.ms)
        .slideY(begin: 0.3, end: 0)
        .shimmer(duration: 2000.ms, delay: 1500.ms);
  }

  Widget _buildModernDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 600.ms, delay: 1000.ms);
  }

  Future<String?> _showRoleSelectionDialog() async {
    String? selectedRole;

    return showDialog<String>(
      context: context,
      barrierDismissible: false, // User must select a role or cancel
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Select Your Role',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  fontSize: 20,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Choose your role to continue',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedRole == 'Contractor'
                            ? const Color(0xFF667eea)
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        'Contractor',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Manage projects and teams',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      leading: Radio<String>(
                        value: 'Contractor',
                        groupValue: selectedRole,
                        activeColor: const Color(0xFF667eea),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedRole = value;
                          });
                        },
                      ),
                      onTap: () {
                        setDialogState(() {
                          selectedRole = 'Contractor';
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedRole == 'Freelancer-Employee'
                            ? const Color(0xFF667eea)
                            : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        'Freelancer Employee',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Manage site operations',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      leading: Radio<String>(
                        value: 'Freelancer-Employee',
                        groupValue: selectedRole,
                        activeColor: const Color(0xFF667eea),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedRole = value;
                          });
                        },
                      ),
                      onTap: () {
                        setDialogState(() {
                          selectedRole = 'Freelancer-Employee';
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(null);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedRole != null
                      ? () {
                    Navigator.of(dialogContext).pop(selectedRole);
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF667eea),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModernGoogleButton() {
    return Container(
      width: double.infinity,
      height: 56,
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
      ),
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : _handleGoogleSignIn,
        icon: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF4285F4), Color(0xFFEA4335)],
            ),
          ),
          child: const Center(
            child: Text(
              'G',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        label: Text(
          'Continue with Google',
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
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 1100.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildModernSignUpLink() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SignUpPage()),
        );
      },
      child: Text(
        "Don't have an account? Sign Up",
        style: GoogleFonts.poppins(
          color: Colors.white.withValues(alpha: 0.9),
          decoration: TextDecoration.underline,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ).animate().fadeIn(duration: 600.ms, delay: 1200.ms);
  }
}