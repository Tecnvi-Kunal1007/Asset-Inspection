import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/file_upload_service.dart';
import '../services/freelancer_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

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
  File? _resumeFile;
  String? _resumeFileName;
  File? _profilePhoto;
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
      final XFile? pickedFile = await _imagePicker.pickMedia();

      if (pickedFile != null) {
        if (!pickedFile.path.toLowerCase().endsWith('.pdf')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please select a PDF file',
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
          _resumeFile = File(pickedFile.path);
          _resumeFileName = pickedFile.name;
        });
      }
    } catch (e) {
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
      }
    } catch (e) {
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
      String? resumeUrl;
      String? profilePhotoUrl;

      if (_resumeFile != null) {
        resumeUrl = await _fileUploadService.uploadResume(
          _resumeFile!,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      if (_profilePhoto != null) {
        profilePhotoUrl = await _fileUploadService.uploadProfilePhoto(
          _profilePhoto!,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

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

      final freelancer = await _freelancerService.addFreelancer(freelancerData);

      if (freelancer == null) {
        throw Exception('Failed to add freelancer');
      }

      if (_resumeFile != null && resumeUrl != null) {
        final newResumeUrl = await _fileUploadService.uploadResume(
          _resumeFile!,
          freelancer.id,
        );

        await Supabase.instance.client
            .from('freelancers')
            .update({'resume_url': newResumeUrl})
            .eq('id', freelancer.id);
      }

      if (_profilePhoto != null && profilePhotoUrl != null) {
        final newProfilePhotoUrl = await _fileUploadService.uploadProfilePhoto(
          _profilePhoto!,
          freelancer.id,
        );

        await Supabase.instance.client
            .from('freelancers')
            .update({'profile_photo_url': newProfilePhotoUrl})
            .eq('id', freelancer.id);
      }

      if (mounted) {
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
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(
              color: Colors.blue.shade700,
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, color: Colors.blue.shade700),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.blue.shade100),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.blue.shade100),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: validator,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
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
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.person_add,
                    size: 80,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personal Information',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Profile Photo Section
                              Center(
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
                                          border: Border.all(
                                            color: Colors.blue.shade700,
                                            width: 2,
                                          ),
                                        ),
                                        child: _profilePhoto != null
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
                                                color: Colors.blue.shade700,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Tap to add profile photo',
                                      style: GoogleFonts.poppins(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
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
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Professional Details',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
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
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Resume',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: _pickResume,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.blue.shade100,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.upload_file,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _resumeFileName ??
                                              'Upload Resume (PDF)',
                                          style: GoogleFonts.poppins(
                                            color: Colors.blue.shade700,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addFreelancer,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                          child:
                              _isLoading
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : Text(
                                    'Add Freelancer',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
