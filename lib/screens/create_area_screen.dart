import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/area.dart';
import '../services/supabase_service.dart';

class CreateAreaScreen extends StatefulWidget {
  const CreateAreaScreen({super.key});

  @override
  State<CreateAreaScreen> createState() => _CreateAreaScreenState();
}

class _CreateAreaScreenState extends State<CreateAreaScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();
  final _uuid = const Uuid();
  final _pageController = PageController();

  // Animation controllers
  late AnimationController _slideAnimationController;
  late AnimationController _fadeAnimationController;
  late AnimationController _submitAnimationController;

  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _submitAnimation;

  int _currentStep = 0;
  bool _isSubmitting = false;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _siteOwnerController = TextEditingController();
  final _siteOwnerEmailController = TextEditingController();
  final _siteOwnerPhoneController = TextEditingController();
  final _siteManagerController = TextEditingController();
  final _siteManagerEmailController = TextEditingController();
  final _siteManagerPhoneController = TextEditingController();
  final _siteLocationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _submitAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _submitAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _submitAnimationController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _fadeAnimationController.forward();
    _slideAnimationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _siteOwnerController.dispose();
    _siteOwnerEmailController.dispose();
    _siteOwnerPhoneController.dispose();
    _siteManagerController.dispose();
    _siteManagerEmailController.dispose();
    _siteManagerPhoneController.dispose();
    _siteLocationController.dispose();
    _slideAnimationController.dispose();
    _fadeAnimationController.dispose();
    _submitAnimationController.dispose();
    super.dispose();
  }

  Future<void> _createArea() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    _submitAnimationController.forward();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final contractorData = await Supabase.instance.client
          .from('contractor')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final area = Area(
        id: _uuid.v4(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        contractorId: user.id,
        siteOwner: _siteOwnerController.text.trim(),
        siteOwnerEmail: _siteOwnerEmailController.text.trim(),
        siteOwnerPhone: _siteOwnerPhoneController.text.trim(),
        siteManager: _siteManagerController.text.trim(),
        siteManagerEmail: _siteManagerEmailController.text.trim(),
        siteManagerPhone: _siteManagerPhoneController.text.trim(),
        siteLocation: _siteLocationController.text.trim(),
        contractorEmail: contractorData?['email'] ?? '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabaseService.createArea(area);

      if (!mounted) return;

      _showSuccessSnackBar('Area created successfully!');

      // Delay to show success animation
      await Future.delayed(const Duration(milliseconds: 500));
      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        _submitAnimationController.reverse();
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[50]!,
            Colors.indigo[50]!,
            Colors.purple[50]!,
          ],
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[600]!,
            Colors.indigo[600]!,
            Colors.purple[600]!,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New Area',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Step ${_currentStep + 1} of 3',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isActive
                          ? Colors.blue[600]
                          : Colors.grey[300],
                    ),
                  ),
                ),
                if (index < 2) const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: keyboardType,
              maxLines: maxLines,
              validator: validator ?? (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter $label';
                }
                return null;
              },
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[800],
              ),
              decoration: InputDecoration(
                prefixIcon: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.blue[600],
                    size: 20,
                  ),
                ),
                hintText: 'Enter $label',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Area Information',
            'Basic details about the site',
            Icons.business_rounded,
          ),
          const SizedBox(height: 24),
          _buildModernTextField(
            controller: _nameController,
            label: 'Area Name',
            icon: Icons.business_rounded,
          ),
          _buildModernTextField(
            controller: _descriptionController,
            label: 'Description',
            icon: Icons.description_rounded,
            maxLines: 3,
          ),
          _buildModernTextField(
            controller: _siteLocationController,
            label: 'Location',
            icon: Icons.location_on_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Owner Information',
            'Contact details of the site owner',
            Icons.person_rounded,
          ),
          const SizedBox(height: 24),
          _buildModernTextField(
            controller: _siteOwnerController,
            label: 'Owner Name',
            icon: Icons.person_rounded,
          ),
          _buildModernTextField(
            controller: _siteOwnerEmailController,
            label: 'Owner Email',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter owner email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          _buildModernTextField(
            controller: _siteOwnerPhoneController,
            label: 'Owner Phone',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildManagerInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Manager Information',
            'Contact details of the site manager',
            Icons.manage_accounts_rounded,
          ),
          const SizedBox(height: 24),
          _buildModernTextField(
            controller: _siteManagerController,
            label: 'Manager Name',
            icon: Icons.manage_accounts_rounded,
          ),
          _buildModernTextField(
            controller: _siteManagerEmailController,
            label: 'Manager Email',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter manager email';
              }
              if (!value.contains('@')) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          _buildModernTextField(
            controller: _siteManagerPhoneController,
            label: 'Manager Phone',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentStep--;
                      });
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.grey[700],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.arrow_back_ios_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Previous',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Container(
                margin: EdgeInsets.only(left: _currentStep > 0 ? 10 : 0),
                child: AnimatedBuilder(
                  animation: _submitAnimation,
                  builder: (context, child) {
                    return ElevatedButton(
                      onPressed: _isSubmitting ? null : () {
                        if (_currentStep < 2) {
                          setState(() {
                            _currentStep++;
                          });
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _createArea();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting
                          ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Creating...',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep < 2 ? 'Next' : 'Create Area',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentStep < 2
                                ? Icons.arrow_forward_ios_rounded
                                : Icons.check_rounded,
                            size: 18,
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildGradientBackground(),
          Column(
            children: [
              _buildModernAppBar(),
              _buildStepIndicator(),
              Expanded(
                child: AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: _slideAnimation.value * 100,
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: Form(
                          key: _formKey,
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentStep = index;
                              });
                            },
                            children: [
                              _buildAreaInfoStep(),
                              _buildOwnerInfoStep(),
                              _buildManagerInfoStep(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ],
      ),
    );
  }
}