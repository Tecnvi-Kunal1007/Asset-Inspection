import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/site_assignment_service.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/file_upload_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/freelancer_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/area_assignment_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _siteAssignmentService = SiteAssignmentService();
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _fileUploadService = FileUploadService();
  final _imagePicker = ImagePicker();
  final FreelancerService _freelancerService = FreelancerService();

  List<Map<String, dynamic>> _freelancers = [];
  bool _isLoading = true;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _specializationController = TextEditingController();
  final _experienceYearsController = TextEditingController();
  final _notesController = TextEditingController();
  final _skillController = TextEditingController();
  
  // For non-web platforms
  File? _resumeFile;
  // For web platform
  PlatformFile? _webResumeFile;
  
  String? _resumeFileName;
  File? _profilePhoto;

  @override
  void initState() {
    super.initState();
    _loadFreelancers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _specializationController.dispose();
    _experienceYearsController.dispose();
    _notesController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  Future<void> _loadFreelancers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final freelancers =
          await _freelancerService.getEmployeesForCurrentContractor();

      setState(() {
        _freelancers = freelancers.map((f) => f.toJson()).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading employees: $e')));
      setState(() {
        _isLoading = false;
      });
    }
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
        if (!file.name.toLowerCase().endsWith('.pdf')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please select a PDF file')),
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
            const SnackBar(content: Text('PDF file selected successfully')),
          );
        }
      }
    } catch (e) {
      print('DEBUG: Error in _pickResume: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking file: $e')));
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

    try {
      final freelancerId = _uuid.v4();

      // Get contractor ID
      final contractorId = await _freelancerService.getCurrentContractorId();
      if (contractorId == null) {
        throw Exception('No contractor ID found');
      }

      // Upload resume first if selected
      String? resumeUrl;
      String? profilePhotoUrl;

      if (_resumeFile != null || _webResumeFile != null) {
        if (kIsWeb && _webResumeFile != null) {
          resumeUrl = await _fileUploadService.uploadResume(
            _webResumeFile!,
            DateTime.now().millisecondsSinceEpoch.toString(),
          );
        } else if (_resumeFile != null) {
          resumeUrl = await _fileUploadService.uploadResume(
            _resumeFile!,
            DateTime.now().millisecondsSinceEpoch.toString(),
          );
        }
      }

      if (_profilePhoto != null) {
        profilePhotoUrl = await _fileUploadService.uploadProfilePhoto(
          _profilePhoto!,
          DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      // Insert the freelancer record with resume URL and contractor ID
      await _supabase.from('freelancers').insert({
        'id': freelancerId,
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
        'role': 'employee',
        'status': 'active',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'contractor_id': contractorId,
      });

      // If resume was uploaded, update the file name with the actual freelancer ID
      if (resumeUrl != null) {
        String newResumeUrl;
        if (kIsWeb && _webResumeFile != null) {
          newResumeUrl = await _fileUploadService.uploadResume(
            _webResumeFile!,
            freelancerId,
          );
        } else if (_resumeFile != null) {
          newResumeUrl = await _fileUploadService.uploadResume(
            _resumeFile!,
            freelancerId,
          );
        } else {
          newResumeUrl = resumeUrl;
        }

        // Update the resume URL with the correct one
        await _supabase
            .from('freelancers')
            .update({'resume_url': newResumeUrl})
            .eq('id', freelancerId);
      }

      // If profile photo was uploaded, update the file name with the actual freelancer ID
      if (_profilePhoto != null && profilePhotoUrl != null) {
        final newProfilePhotoUrl = await _fileUploadService.uploadProfilePhoto(
          _profilePhoto!,
          freelancerId,
        );

        // Update the profile photo URL with the correct one
        await _supabase
            .from('freelancers')
            .update({'profile_photo_url': newProfilePhotoUrl})
            .eq('id', freelancerId);
      }

      // Clear form
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _addressController.clear();
      _specializationController.clear();
      _experienceYearsController.clear();
      _notesController.clear();
      _skillController.clear();
      setState(() {
        _resumeFile = null;
        _webResumeFile = null;
        _resumeFileName = null;
        _profilePhoto = null;
      });

      // Reload freelancers
      await _loadFreelancers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee added successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding employee: $e')));
    }
  }

  Future<void> _deleteFreelancer(String freelancerId) async {
    try {
      await _supabase
          .from('freelancers')
          .update({
            'status': 'inactive',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', freelancerId);
      await _loadFreelancers();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Freelancer deleted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting freelancer: $e')));
    }
  }

  Future<void> _showAssignSiteDialog(Map<String, dynamic> employee) async {
    try {
      final supabase = Supabase.instance.client;

      // Get the current user ID (contractor ID)
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be logged in to assign sites'),
            ),
          );
        }
        return;
      }

      // Get available sites (unassigned + assigned to this employee)
      final sites = await _siteAssignmentService.getAvailableSitesForAssignment(
        user.id,
        employee['id'],
      );

      // Get already assigned sites for this employee
      final assignmentsResponse = await supabase
          .from('site_assignments')
          .select('site_id')
          .eq('freelancer_id', employee['id']);

      final assignedSiteIds =
          (assignmentsResponse as List)
              .map((assignment) => assignment['site_id'] as String)
              .toSet();

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('Assign Sites to ${employee['name']}'),
              content: SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child:
                    sites.isEmpty
                        ? const Center(
                          child: Text('No sites available for assignment'),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: sites.length,
                          itemBuilder: (context, index) {
                            final site = sites[index];
                            final isAssigned = assignedSiteIds.contains(
                              site['id'],
                            );
                            final siteName =
                                site['site_name'] ?? 'Unnamed Site';
                            final siteAddress = site['site_location'] ?? '';

                            return CheckboxListTile(
                              title: Text(
                                siteName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(siteAddress),
                              value: isAssigned,
                              onChanged: (bool? value) async {
                                try {
                                  if (value == true) {
                                    // Assign site using service
                                    await _siteAssignmentService.assignSite(
                                      siteId: site['id'],
                                      assignedToId: employee['id'],
                                    );
                                  } else {
                                    // Unassign site using service
                                    await _siteAssignmentService.unassignSite(
                                      site['id'],
                                    );
                                  }

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          value == true
                                              ? 'Site assigned successfully'
                                              : 'Site unassigned successfully',
                                        ),
                                      ),
                                    );
                                    Navigator.pop(context);
                                    _showAssignSiteDialog(employee);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error updating assignment: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
              ),
            ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading sites: $e')));
      }
    }
  }

  Future<void> _showAssignAreaDialog(Map<String, dynamic> employee) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be logged in to assign areas'),
            ),
          );
        }
        return;
      }

      // Get contractor ID
      final contractorResponse =
          await supabase
              .from('contractor')
              .select('id')
              .eq('email', user.email!)
              .maybeSingle();

      if (contractorResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contractor not found. Please contact support.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final contractorId = contractorResponse['id'];

      final areaAssignmentService = AreaAssignmentService();
      final areas = await areaAssignmentService.getAvailableAreasForAssignment(
        contractorId,
        employee['id'],
      );

      final assignmentsResponse = await supabase
          .from('area_assignments')
          .select('area_id, assignment_type')
          .eq('assigned_to_id', employee['id'])
          .eq('status', 'active');

      // Get all assignments for each area to check which sections are assigned
      final allAssignmentsResponse = await supabase
          .from('area_assignments')
          .select('area_id, assignment_type, assigned_to_id')
          .eq('status', 'active');

      // Create a map of area_id to list of assigned sections
      final Map<String, Set<String>> areaAssignments = {};
      for (var assignment in allAssignmentsResponse) {
        final areaId = assignment['area_id'] as String;
        final assignmentType = assignment['assignment_type'] as String;
        areaAssignments.putIfAbsent(areaId, () => {}).add(assignmentType);
      }

      // Create a map of area_id to list of sections assigned to this employee
      final Map<String, Set<String>> employeeAssignments = {};
      for (var assignment in assignmentsResponse) {
        final areaId = assignment['area_id'] as String;
        final assignmentType = assignment['assignment_type'] as String;
        employeeAssignments.putIfAbsent(areaId, () => {}).add(assignmentType);
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              title: Text(
                'Assign Areas to ${employee['name']}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              content: Container(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                  ),
                ),
                child:
                    areas.isEmpty
                        ? Center(
                          child: Text(
                            'No areas available for assignment',
                            style: GoogleFonts.poppins(),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: areas.length,
                          itemBuilder: (context, index) {
                            final area = areas[index];
                            final areaId = area['id'] as String;
                            final assignedSections =
                                areaAssignments[areaId] ?? {};
                            final employeeAssignedSections =
                                employeeAssignments[areaId] ?? {};
                            final areaName = area['name'] ?? 'Unnamed Area';
                            final areaLocation = area['site_location'] ?? '';

                            // Check if both sections are assigned
                            final bool isFullyAssigned =
                                assignedSections.contains('pumps_floor') &&
                                assignedSections.contains('building_fire');

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(
                                      areaName,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          areaLocation,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (assignedSections.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              if (assignedSections.contains(
                                                'pumps_floor',
                                              ))
                                                _buildAssignmentChip(
                                                  'Pumps & Floor',
                                                  employeeAssignedSections
                                                      .contains('pumps_floor'),
                                                  () async {
                                                    try {
                                                      await areaAssignmentService
                                                          .unassignArea(
                                                            areaId,
                                                            employee['id'],
                                                          );
                                                      if (mounted) {
                                                        Navigator.pop(context);
                                                        _showAssignAreaDialog(
                                                          employee,
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error: $e',
                                                            ),
                                                            backgroundColor:
                                                                Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                              if (assignedSections.contains(
                                                'building_fire',
                                              ))
                                                _buildAssignmentChip(
                                                  'Building & Fire',
                                                  employeeAssignedSections
                                                      .contains(
                                                        'building_fire',
                                                      ),
                                                  () async {
                                                    try {
                                                      await areaAssignmentService
                                                          .unassignArea(
                                                            areaId,
                                                            employee['id'],
                                                          );
                                                      if (mounted) {
                                                        Navigator.pop(context);
                                                        _showAssignAreaDialog(
                                                          employee,
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error: $e',
                                                            ),
                                                            backgroundColor:
                                                                Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing:
                                        isFullyAssigned
                                            ? null
                                            : IconButton(
                                              icon: const Icon(Icons.add),
                                              onPressed: () async {
                                                // Show only unassigned sections
                                                final availableSections = [
                                                  if (!assignedSections
                                                      .contains('pumps_floor'))
                                                    'pumps_floor',
                                                  if (!assignedSections
                                                      .contains(
                                                        'building_fire',
                                                      ))
                                                    'building_fire',
                                                ];

                                                if (availableSections.isEmpty)
                                                  return;

                                                final assignmentType = await showDialog<
                                                  String
                                                >(
                                                  context: context,
                                                  builder:
                                                      (context) => AlertDialog(
                                                        title: Text(
                                                          'Select Assignment Type',
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        content: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children:
                                                              availableSections.map((
                                                                section,
                                                              ) {
                                                                return ListTile(
                                                                  title: Text(
                                                                    section ==
                                                                            'pumps_floor'
                                                                        ? 'Pump and Floor Inspection'
                                                                        : 'Fire Alarm Inspection',
                                                                    style:
                                                                        GoogleFonts.poppins(),
                                                                  ),
                                                                  onTap:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        section,
                                                                      ),
                                                                );
                                                              }).toList(),
                                                        ),
                                                      ),
                                                );

                                                if (assignmentType != null) {
                                                  try {
                                                    await areaAssignmentService
                                                        .assignArea(
                                                          areaId: areaId,
                                                          assignedToId:
                                                              employee['id'],
                                                          assignedToType:
                                                              'employee',
                                                          assignedById: user.id,
                                                          assignmentType:
                                                              assignmentType,
                                                        );
                                                    if (mounted) {
                                                      Navigator.pop(context);
                                                      _showAssignAreaDialog(
                                                        employee,
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Error: $e',
                                                          ),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                }
                                              },
                                            ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildAssignmentChip(
    String label,
    bool isAssignedToEmployee,
    VoidCallback onUnassign,
  ) {
    return Chip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: isAssignedToEmployee ? Colors.white : Colors.blue.shade700,
        ),
      ),
      backgroundColor:
          isAssignedToEmployee ? Colors.blue.shade700 : Colors.blue.shade50,
      deleteIcon:
          isAssignedToEmployee
              ? const Icon(Icons.close, size: 16, color: Colors.white)
              : null,
      onDeleted: isAssignedToEmployee ? onUnassign : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Employee Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _freelancers.length,
                      itemBuilder: (context, index) {
                        final freelancer = _freelancers[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.all(16),
                            leading:
                                freelancer['profile_photo_url'] != null
                                    ? CircleAvatar(
                                      radius: 25,
                                      backgroundImage: NetworkImage(
                                        freelancer['profile_photo_url'],
                                      ),
                                    )
                                    : CircleAvatar(
                                      radius: 25,
                                      backgroundColor: Colors.grey.shade200,
                                      child: Icon(
                                        Icons.person,
                                        size: 30,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                            title: Text(
                              freelancer['name'] ?? 'No Name',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              freelancer['skill'] ?? 'No Skills',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInfoRow(
                                      'Email',
                                      freelancer['email'] ?? 'No Email',
                                      Icons.email,
                                    ),
                                    _buildInfoRow(
                                      'Phone',
                                      freelancer['phone'] ?? 'No Phone',
                                      Icons.phone,
                                    ),
                                    _buildInfoRow(
                                      'Address',
                                      freelancer['address'] ?? 'No Address',
                                      Icons.location_on,
                                    ),
                                    _buildInfoRow(
                                      'Specialization',
                                      freelancer['specialization'] ??
                                          'No Specialization',
                                      Icons.work,
                                    ),
                                    _buildInfoRow(
                                      'Experience',
                                      '${freelancer['experience_years'] ?? 0} years',
                                      Icons.timeline,
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed:
                                                () => _showAssignSiteDialog(
                                                  freelancer,
                                                ),
                                            icon: const Icon(Icons.business),
                                            label: Text(
                                              'Assign Sites',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.blue.shade700,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape:
                                                  const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.zero,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed:
                                                () => _showAssignAreaDialog(
                                                  freelancer,
                                                ),
                                            icon: const Icon(Icons.map),
                                            label: Text(
                                              'Assign Areas',
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.orange.shade700,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              shape:
                                                  const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.zero,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddEmployeeDialog(),
                      icon: const Icon(Icons.person_add),
                      label: Text(
                        'Add Employee',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Employee',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _pickProfilePhoto,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                border: Border.all(
                                  color: Colors.blue.shade700,
                                  width: 2,
                                ),
                              ),
                              child:
                                  _profilePhoto != null
                                      ? Image.file(
                                        _profilePhoto!,
                                        width: 120,
                                        height: 120,
                                        fit: BoxFit.cover,
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
                    const SizedBox(height: 24),
                    _buildFormField(
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
                    const SizedBox(height: 16),
                    _buildFormField(
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
                    const SizedBox(height: 16),
                    _buildFormField(
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
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _addressController,
                      label: 'Address',
                      icon: Icons.location_on,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildFormField(
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
                    const SizedBox(height: 16),
                    _buildFormField(
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
                    const SizedBox(height: 16),
                    _buildFormField(
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
                    const SizedBox(height: 16),
                    _buildFormField(
                      controller: _notesController,
                      label: 'Additional Notes',
                      icon: Icons.note,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickResume,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue.shade100),
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
                                _resumeFileName ?? 'Upload Resume (PDF)',
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              _addFreelancer();
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                            child: Text(
                              'Add Employee',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
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
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.blue.shade700),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.grey),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade700),
      ),
      style: GoogleFonts.poppins(),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
    );
  }
}
