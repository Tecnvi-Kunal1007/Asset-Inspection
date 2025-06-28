import 'package:flutter/material.dart';
import 'package:pump_management_system/screens/signup_page.dart';
import '../screens/contractor_dashboard_screen.dart';
import '../screens/site_manager_dashboard.dart';
import '../services/auth_service.dart';
import 'forgot_password_page.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  bool _isCardHovered = false;

  final AuthService _authService = AuthService();
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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _cardScaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _cardAnimationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cardAnimationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _onCardHover(bool isHovered) {
    setState(() {
      _isCardHovered = isHovered;
    });
    if (isHovered) {
      _cardAnimationController.forward();
    } else {
      _cardAnimationController.reverse();
    }
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

      final response = await _authService.loginUser(email: email, password: password);

      if (response.user != null) {
        final role = await _authService.getUserRole(response.user!.id);
        if (!mounted) return;

        print('🔍 Logged-in user role: $role');

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
      } else {
        _showError('Login failed. User not found.');
      }
    } catch (e) {
      _showError('Login failed: ${e.toString()}');
    }

    setState(() {
      isLoading = false;
    });
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF), // Pure white
              Color(0xFFF8FAFC), // Very light gray-blue
              Color(0xFFE2E8F0), // Light gray
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background decorations with construction theme
            _buildBackgroundDecorations(screenWidth, screenHeight),

            // Main content
            SafeArea(
              child: Center(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: isDesktop
                            ? _buildDesktopLayout(context, screenWidth, screenHeight)
                            : _buildMobileTabletLayout(context, screenWidth, screenHeight, isTablet),
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

  Widget _buildBackgroundDecorations(double screenWidth, double screenHeight) {
    return Stack(
      children: [
        // Construction-themed floating elements
        Positioned(
          top: screenHeight * 0.08,
          left: screenWidth * 0.05,
          child: _buildFloatingDecoration(
            size: 120,
            icon: Icons.construction,
            color: const Color(0xFFFF6B35).withOpacity(0.1),
            delay: 0,
          ),
        ),
        Positioned(
          bottom: screenHeight * 0.15,
          right: screenWidth * 0.08,
          child: _buildFloatingDecoration(
            size: 160,
            icon: Icons.engineering,
            color: const Color(0xFF1E3A8A).withOpacity(0.1),
            delay: 2000,
          ),
        ),

        Positioned(
          top: screenHeight * 0.35,
          right: screenWidth * 0.15,
          child: _buildFloatingDecoration(
            size: 100,
            icon: Icons.handyman,
            color: const Color(0xFFFF6B35).withOpacity(0.1),
            delay: 4000,
          ),
        ),


        Positioned(
          bottom: screenHeight * 0.45,
          left: screenWidth * 0.1,
          child: _buildFloatingDecoration(
            size: 80,
            icon: Icons.build_circle,
            color: const Color(0xFF1E3A8A).withOpacity(0.1),




            delay: 1000,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingDecoration({
    required double size,
    required IconData icon,
    required Color color,
    required int delay,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 3000 + delay),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (0.5 - (value * 2 - 1).abs())),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: Colors.black.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: size * 0.4,
              color: Colors.black.withOpacity(0.2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, double screenWidth, double screenHeight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
      child: Row(
        children: [
          // Left side - Branding and construction theme
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBrandingSection(screenWidth, true),
              ],
            ),
          ),

          // Right side - Login card
          Expanded(
            flex: 4,
            child: _buildLoginCard(screenWidth, screenHeight, true),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabletLayout(BuildContext context, double screenWidth, double screenHeight, bool isTablet) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Branding section
          Flexible(
            flex: 2,
            child: _buildBrandingSection(screenWidth, false),
          ),

          // Login card
          Flexible(
            flex: 3,
            child: _buildLoginCard(screenWidth, screenHeight, false),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingSection(double screenWidth, bool isDesktop) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Logo section
        Container(
          width: isDesktop ? 200 : screenWidth * 0.5,
          height: isDesktop ? 120 : screenWidth * 0.3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/tecnvi-logo.jpeg',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.construction,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Company name and tagline
        Text(
          "Mobilo Intelio",
          style: TextStyle(
            fontSize: isDesktop ? 42 : screenWidth * 0.08,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E3A8A),
            letterSpacing: 1.2,
          ),
        ).animate().fadeIn(duration: const Duration(milliseconds: 800), delay: const Duration(milliseconds: 300)),

        const SizedBox(height: 16),

        Text(
          "CONSTRUCTION BUSINESS",
          style: TextStyle(
            fontSize: isDesktop ? 16 : screenWidth * 0.035,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFFF6B35),
            letterSpacing: 2.0,
          ),
        ).animate().fadeIn(duration: const Duration(milliseconds: 800), delay: const Duration(milliseconds: 400)),

        const SizedBox(height: 12),

        Text(
          "We Build Something New\nAnd Consistent",
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 28 : screenWidth * 0.055,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF334155),
            height: 1.3,
          ),
        ).animate().fadeIn(duration: const Duration(milliseconds: 800), delay: const Duration(milliseconds: 500)),

        const SizedBox(height: 16),

        Text(
          "Professional automation solutions with precision engineering\nfor modern construction management",
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 16 : screenWidth * 0.035,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ).animate().fadeIn(duration: const Duration(milliseconds: 800), delay: const Duration(milliseconds: 600)),
      ],
    );
  }

  Widget _buildLoginCard(double screenWidth, double screenHeight, bool isDesktop) {
    return MouseRegion(
      onEnter: (_) => _onCardHover(true),
      onExit: (_) => _onCardHover(false),
      child: AnimatedBuilder(
        animation: _cardScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _cardScaleAnimation.value,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 450 : double.infinity,
                maxHeight: screenHeight * 0.7,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _isCardHovered
                        ? const Color(0xFF1E3A8A).withOpacity(0.2)
                        : Colors.black.withOpacity(0.1),
                    blurRadius: _isCardHovered ? 40 : 25,
                    spreadRadius: _isCardHovered ? 5 : 2,
                    offset: Offset(0, _isCardHovered ? 20 : 15),
                  ),
                ],
                border: Border.all(
                  color: _isCardHovered
                      ? const Color(0xFF1E3A8A).withOpacity(0.3)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? 40 : 32),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardHeader(screenWidth),
                      const SizedBox(height: 32),
                      _buildInputFields(screenWidth),
                      const SizedBox(height: 24),
                      _buildLoginButton(screenWidth),
                      const SizedBox(height: 20),
                      _buildDivider(screenWidth),
                      const SizedBox(height: 20),
                      _buildGoogleSignIn(screenWidth),
                      const SizedBox(height: 20),
                      _buildSignUpLink(screenWidth),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 1000), delay: const Duration(milliseconds: 800));
  }

  Widget _buildCardHeader(double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.engineering_outlined,
                color: Color(0xFF1E3A8A),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              "Welcome Back!",
              style: TextStyle(
                fontSize: screenWidth > 600 ? 28 : screenWidth * 0.065,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 56),
          child: Text(
            "Sign in to access your construction dashboard",
            style: TextStyle(
              fontSize: screenWidth > 600 ? 16 : screenWidth * 0.038,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputFields(double screenWidth) {
    return Column(
      children: [
        _buildTextField(
          controller: emailController,
          label: "Email Address",
          hintText: "Enter your email",
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          screenWidth: screenWidth,
        ).animate().fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 900))
            .slideX(begin: -0.1, end: 0),

        const SizedBox(height: 20),

        _buildTextField(
          controller: passwordController,
          label: "Password",
          hintText: "Enter your password",
          icon: Icons.lock_outline,
          isPassword: true,
          screenWidth: screenWidth,
        ).animate().fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1000))
            .slideX(begin: -0.1, end: 0),

        const SizedBox(height: 12),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage()));
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: const Color(0xFF1E3A8A),
                fontSize: screenWidth > 600 ? 14 : screenWidth * 0.035,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ).animate().fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1100)),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required double screenWidth,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: screenWidth > 600 ? 16 : screenWidth * 0.04,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: isPassword ? _obscureText : false,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: const Color(0xFF94A3B8)),
              prefixIcon: Icon(icon, color: const Color(0xFF1E3A8A), size: 22),
              suffixIcon: isPassword
                  ? IconButton(
                onPressed: togglePasswordVisibility,
                icon: Icon(
                  _obscureText ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFF64748B),
                  size: 22,
                ),
              )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(double screenWidth) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            const Icon(
              Icons.login,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Sign In',
              style: TextStyle(
                fontSize: screenWidth > 600 ? 18 : screenWidth * 0.045,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1200))
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildDivider(double screenWidth) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: const Color(0xFF94A3B8),
              fontSize: screenWidth > 600 ? 14 : screenWidth * 0.035,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE2E8F0), thickness: 1)),
      ],
    ).animate().fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1300));
  }

  Widget _buildGoogleSignIn(double screenWidth) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Image.asset(
          'assets/images/google_icon.jpeg',
          width: 24,
          height: 24,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
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
        ),
        label: Text(
          'Continue with Google',
          style: TextStyle(
            fontSize: screenWidth > 600 ? 16 : screenWidth * 0.04,
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1400))
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildSignUpLink(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(
            fontSize: screenWidth > 600 ? 16 : screenWidth * 0.038,
            color: const Color(0xFF64748B),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage()));
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: Text(
            'Sign Up',
            style: TextStyle(
              fontSize: screenWidth > 600 ? 16 : screenWidth * 0.038,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFFF6B35),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: const Duration(milliseconds: 600), delay: const Duration(milliseconds: 1500));
  }
}