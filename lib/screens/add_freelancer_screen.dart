import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_upload_service.dart';
import '../services/freelancer_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import 'dart:math' as math;
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';

class AddFreelancerScreen extends StatefulWidget {
  const AddFreelancerScreen({Key? key}) : super(key: key);

  @override
  State<AddFreelancerScreen> createState() => _AddFreelancerScreenState();
}

class _AddFreelancerScreenState extends State<AddFreelancerScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _skillController = TextEditingController();
  final _specializationController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _notesController = TextEditingController();
  final _fileUploadService = FileUploadService();
  final _freelancerService = FreelancerService();
  final _imagePicker = ImagePicker();
  bool _isLoading = false;

  // For non-web platforms
  File? _resumeFile;
  File? _profilePhoto;

  // For web platform
  PlatformFile? _webResumeFile;
  Uint8List? _webProfilePhoto;

  String? _resumeFileName;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _skillController.dispose();
    _specializationController.dispose();
    _experienceYearsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickResume() async {
    try {
      print('DEBUG: Starting _pickResume');
      // Use FilePicker for both web and mobile
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: kIsWeb, // Load file bytes for web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Check if it's a PDF by extension
        if (!file.path!.toLowerCase().endsWith('.pdf') &&
            !file.name.toLowerCase().endsWith('.pdf')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please select a PDF file. Selected file: ${file.name}',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
          return;
        }

        setState(() {
          if (kIsWeb) {
            print('DEBUG: Setting web resume file');
            _webResumeFile = file;
          } else {
            print('DEBUG: Setting non-web resume file');
            _resumeFile = File(file.path!);
          }
          _resumeFileName = file.name;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PDF file selected successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: ThemeHelper.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('DEBUG: Error in _pickResume: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking file: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    try {
      print('DEBUG: Starting _pickProfilePhoto');
      if (kIsWeb) {
        print('DEBUG: Picking profile photo for web');
        // For web, use FilePicker with image filter
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );

        if (result != null && result.files.isNotEmpty) {
          setState(() {
            _webProfilePhoto = result.files.first.bytes;
          });
          print('DEBUG: Web profile photo selected');
        }
      } else {
        print('DEBUG: Picking profile photo for non-web');
        // Show options dialog
        final source = await showDialog<ImageSource>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(
                  'Select Image Source',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('Camera'),
                      onTap: () => Navigator.pop(context, ImageSource.camera),
                    ),
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('Gallery'),
                      onTap: () => Navigator.pop(context, ImageSource.gallery),
                    ),
                  ],
                ),
              ),
        );

        if (source == null) return;

        final XFile? pickedFile = await _imagePicker.pickImage(
          source: source,
          imageQuality: 80,
        );

        if (pickedFile != null) {
          setState(() {
            _profilePhoto = File(pickedFile.path);
          });
          print('DEBUG: Non-web profile photo selected');
        }
      }
    } catch (e) {
      print('DEBUG: Error in _pickProfilePhoto: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking photo: $e')));
      }
    }
  }

  Future<void> _addFreelancer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('DEBUG: Starting _addFreelancer method');
      String? resumeUrl;
      String? profilePhotoUrl;

      // Skip file uploads on web for now as a temporary fix
      if (kIsWeb) {
        print('DEBUG: Running on web, skipping file uploads');
      } else {
        if (_resumeFile != null) {
          print('DEBUG: Uploading resume file');
          resumeUrl = await _fileUploadService.uploadResume(
            _resumeFile!,
            DateTime.now().millisecondsSinceEpoch.toString(),
          );
          print('DEBUG: Resume uploaded successfully: $resumeUrl');
        }

        if (_profilePhoto != null) {
          print('DEBUG: Uploading profile photo');
          profilePhotoUrl = await _fileUploadService.uploadProfilePhoto(
            _profilePhoto!,
            DateTime.now().millisecondsSinceEpoch.toString(),
          );
          print('DEBUG: Profile photo uploaded successfully: $profilePhotoUrl');
        }
      }

      print('DEBUG: Preparing freelancer data');
      final freelancerData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'skill': _skillController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'experience_years':
            int.tryParse(_experienceYearsController.text.trim()) ?? 0,
        'notes': _notesController.text.trim(),
        'resume_url': resumeUrl,
        'profile_photo_url': profilePhotoUrl,
        'role': 'freelancer',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      print('DEBUG: Freelancer data prepared: $freelancerData');

      print('DEBUG: Calling _freelancerService.addFreelancer');
      final freelancer = await _freelancerService.addFreelancer(freelancerData);
      print('DEBUG: addFreelancer response: $freelancer');

      if (freelancer == null) {
        print('DEBUG: Freelancer is null, throwing exception');
        throw Exception('Failed to add freelancer');
      }

      // Skip file updates on web for now
      if (!kIsWeb) {
        if (_resumeFile != null && resumeUrl != null) {
          try {
            print('DEBUG: Updating resume URL with freelancer ID');
            final newResumeUrl = await _fileUploadService.uploadResume(
              _resumeFile!,
              freelancer.id,
            );

            await Supabase.instance.client
                .from('freelancers')
                .update({'resume_url': newResumeUrl})
                .eq('id', freelancer.id);
            print('DEBUG: Resume URL updated successfully');
          } catch (e) {
            print('DEBUG: Error updating resume URL: $e');
            // Continue execution even if this fails
          }
        }

        if (_profilePhoto != null && profilePhotoUrl != null) {
          try {
            print('DEBUG: Updating profile photo URL with freelancer ID');
            final newProfilePhotoUrl = await _fileUploadService
                .uploadProfilePhoto(_profilePhoto!, freelancer.id);

            await Supabase.instance.client
                .from('freelancers')
                .update({'profile_photo_url': newProfilePhotoUrl})
                .eq('id', freelancer.id);
            print('DEBUG: Profile photo URL updated successfully');
          } catch (e) {
            print('DEBUG: Error updating profile photo URL: $e');
            // Continue execution even if this fails
          }
        }
      }

      print('DEBUG: Freelancer added successfully');

      // Use Future.delayed to ensure the UI has time to update before navigating
      if (mounted) {
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Freelancer added successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Use Future.delayed to ensure the SnackBar has time to appear before navigating
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      print('DEBUG: Error in _addFreelancer: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error adding freelancer: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isMultiline = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          maxLines: isMultiline ? 3 : 1,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.getFontSize(context, 14),
            color: ThemeHelper.textPrimary,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(
              color: ThemeHelper.purple,
              fontSize: ResponsiveHelper.getFontSize(context, 14),
            ),
            prefixIcon: Icon(icon, color: ThemeHelper.purple),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: ThemeHelper.purple.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: ThemeHelper.purple.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: ThemeHelper.purple, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: validator,
        ),
      ),
    );
  }

  // Profile Photo Section
  Widget _buildProfilePhotoWidget() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickProfilePhoto,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
                border: Border.all(color: ThemeHelper.purple, width: 2),
                boxShadow: ThemeHelper.coloredShadow(ThemeHelper.purple),
              ),
              child:
                  kIsWeb
                      ? (_webProfilePhoto != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.memory(
                              _webProfilePhoto!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                          : Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: ThemeHelper.purple,
                          ))
                      : (_profilePhoto != null
                          ? ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.file(
                              _profilePhoto!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                          : Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: ThemeHelper.purple,
                          )),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to add profile photo',
            style: GoogleFonts.poppins(
              color: ThemeHelper.textSecondary,
              fontSize: ResponsiveHelper.getFontSize(context, 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      shadowColor: ThemeHelper.purple.withOpacity(0.3),
      child: Container(
        decoration: ThemeHelper.cardDecoration(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: ThemeHelper.purpleGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: ThemeHelper.coloredShadow(ThemeHelper.purple),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Personal Information',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 20),
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Profile Photo Section
            _buildProfilePhotoWidget(),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _nameController,
              label: 'Name',
              icon: Icons.person,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an email';
                }
                if (!value.contains('@')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            _buildTextField(
              controller: _phoneController,
              label: 'Phone',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a phone number';
                }
                return null;
              },
            ),
            _buildTextField(
              controller: _addressController,
              label: 'Address/Location',
              icon: Icons.location_on,
              isMultiline: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter an address/location';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalDetailsCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      shadowColor: ThemeHelper.cyan.withOpacity(0.3),
      child: Container(
        decoration: ThemeHelper.cardDecoration(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: ThemeHelper.cyanGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: ThemeHelper.coloredShadow(ThemeHelper.cyan),
                  ),
                  child: const Icon(Icons.work, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Professional Details',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 20),
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.cyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: _skillController,
              label: 'Skills',
              icon: Icons.engineering,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter skills';
                }
                return null;
              },
            ),
            _buildTextField(
              controller: _specializationController,
              label: 'Specialization',
              icon: Icons.work,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter specialization';
                }
                return null;
              },
            ),
            _buildTextField(
              controller: _experienceYearsController,
              label: 'Years of Experience',
              icon: Icons.timeline,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter years of experience';
                }
                return null;
              },
            ),
            _buildTextField(
              controller: _notesController,
              label: 'Additional Notes',
              icon: Icons.note,
              isMultiline: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumeCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      shadowColor: ThemeHelper.teal.withOpacity(0.3),
      child: Container(
        decoration: ThemeHelper.cardDecoration(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: ThemeHelper.tealGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: ThemeHelper.coloredShadow(ThemeHelper.teal),
                  ),
                  child: const Icon(
                    Icons.description,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Resume',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 20),
                    fontWeight: FontWeight.bold,
                    color: ThemeHelper.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: _pickResume,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ThemeHelper.teal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: ThemeHelper.teal.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.upload_file, color: ThemeHelper.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _resumeFileName ?? 'Upload Resume (PDF)',
                        style: GoogleFonts.poppins(
                          color: ThemeHelper.teal,
                          fontSize: ResponsiveHelper.getFontSize(context, 14),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_resumeFileName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeHelper.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: ThemeHelper.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Resume uploaded successfully',
                        style: GoogleFonts.poppins(
                          color: ThemeHelper.green,
                          fontSize: ResponsiveHelper.getFontSize(context, 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _addFreelancer,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeHelper.purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
          shadowColor: ThemeHelper.purple.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child:
            _isLoading
                ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_add, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Add Freelancer',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 18),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
      backgroundColor: ThemeHelper.backgroundLight,
      body: SafeArea(
        child: Stack(
          children: [
            // Background decorations
            Positioned(
              top: -50,
              right: -30,
              child: ThemeHelper.floatingElement(
                size: 180,
                color: ThemeHelper.purple,
                opacity: 0.05,
              ),
            ),
            Positioned(
              bottom: 100,
              left: -20,
              child: ThemeHelper.floatingElement(
                size: 150,
                color: ThemeHelper.cyan,
                opacity: 0.04,
              ),
            ),

            // Main content
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 200,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Add Freelancer',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: ResponsiveHelper.getFontSize(context, 20),
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: ThemeHelper.purpleGradient,
                      ),
                      child: Stack(
                        children: [
                          // Background decoration
                          Positioned(
                            right: 20,
                            bottom: 20,
                            child: Icon(
                              Icons.person_add,
                              size: 120,
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          // Foreground content
                          Center(
                            child: Icon(
                              Icons.person_add,
                              size: 80,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Padding(
                      padding: ResponsiveHelper.getPadding(context),
                      child: Form(
                        key: _formKey,
                        child: ResponsiveHelper.responsiveWidget(
                          context: context,
                          mobile: _buildMobileLayout(),
                          tablet: _buildTabletLayout(),
                          desktop: _buildDesktopLayout(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPersonalInfoCard(),
        const SizedBox(height: 20),
        _buildProfessionalDetailsCard(),
        const SizedBox(height: 20),
        _buildResumeCard(),
        const SizedBox(height: 32),
        _buildSubmitButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPersonalInfoCard(),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildProfessionalDetailsCard()),
            const SizedBox(width: 20),
            Expanded(child: _buildResumeCard()),
          ],
        ),
        const SizedBox(height: 32),
        _buildSubmitButton(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildPersonalInfoCard()),
            const SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  _buildProfessionalDetailsCard(),
                  const SizedBox(height: 20),
                  _buildResumeCard(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildSubmitButton(),
        const SizedBox(height: 32),
      ],
    );
  }
}
