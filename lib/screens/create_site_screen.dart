import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../models/site.dart';
import '../models/area.dart';
import 'site_details_screen.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class CreateSiteScreen extends StatefulWidget {
  final String areaId;
  final Area area;

  const CreateSiteScreen({super.key, required this.areaId, required this.area});

  @override
  State<CreateSiteScreen> createState() => _CreateSiteScreenState();
}

class _CreateSiteScreenState extends State<CreateSiteScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _supabaseService = SupabaseService();

  final _imagePicker = ImagePicker();
  final _uuid = const Uuid();
  File? _inspectorPhoto;
  String _siteLocation = '';
  int _currentStep = 0;
  bool _isCompleting = false;
  bool _createPumpRooms = false;
  int _floorCount = 1;
  final _floorCountController = TextEditingController();

  // Form controllers
  final _siteNameController = TextEditingController();
  final _siteOwnerController = TextEditingController();
  final _siteOwnerEmailController = TextEditingController();
  final _siteOwnerPhoneController = TextEditingController();
  final _siteManagerController = TextEditingController();
  final _siteManagerEmailController = TextEditingController();
  final _siteManagerPhoneController = TextEditingController();
  final _siteInspectorNameController = TextEditingController();
  final _siteInspectorEmailController = TextEditingController();
  final _siteInspectorPhoneController = TextEditingController();
  final _siteLocationController = TextEditingController();
  final _contractorEmailController = TextEditingController();

  // Progress tracking
  bool _siteInfoComplete = false;
  bool _ownerInfoComplete = false;
  bool _managerInfoComplete = false;
  bool _inspectorInfoComplete = false;
  bool _pumpRoomConfigComplete = false;
  bool _floorConfigComplete =
      true; // Default to true since floor count defaults to 1

  // Animation controllers
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

  // Selected freelancer data
  Map<String, dynamic>? _selectedFreelancer;

  @override
  void initState() {
    super.initState();
    _floorCountController.text = _floorCount.toString();
    _initializeFields();
    _setContractorEmail();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _progressAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _initializeFields() async {
    // Pre-fill fields from area data
    _siteOwnerController.text = widget.area.siteOwner;
    _siteOwnerEmailController.text = widget.area.siteOwnerEmail;
    _siteOwnerPhoneController.text = widget.area.siteOwnerPhone;
    _siteManagerController.text = widget.area.siteManager;
    _siteManagerEmailController.text = widget.area.siteManagerEmail;
    _siteManagerPhoneController.text = widget.area.siteManagerPhone;
    _siteLocationController.text = widget.area.siteLocation;

    // Set default site name to "Building One" if it's the first site
    _siteNameController.text = "Building One";

    // Get current user details
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      try {
        // Check if user is a freelancer or employee
        final userData =
            await Supabase.instance.client
                .from('freelancers')
                .select()
                .eq('email', user.email!)
                .maybeSingle();

        if (userData != null) {
          // Prefill inspector details with user's information regardless of role
          setState(() {
            _siteInspectorNameController.text = userData['name'] ?? '';
            _siteInspectorEmailController.text = userData['email'] ?? '';
            _siteInspectorPhoneController.text = userData['phone'] ?? '';
            _selectedFreelancer = userData;
            _inspectorInfoComplete = true;
          });

          // Handle profile photo if it exists
          if (userData['profile_photo_url'] != null) {
            try {
              final photoUrl = userData['profile_photo_url'];
              final response = await http.get(Uri.parse(photoUrl));
              if (response.statusCode == 200) {
                final tempDir = await getTemporaryDirectory();
                final file = File('${tempDir.path}/temp_photo.jpg');
                await file.writeAsBytes(response.bodyBytes);
                setState(() {
                  _inspectorPhoto = file;
                });
              }
            } catch (e) {
              print('Error loading profile photo: $e');
            }
          }

          print(
            'Prefilled inspector details for ${userData['role']}: ${userData['name']}',
          );
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }

    // Update completion states
    _updateCompletionStates();
  }

  void _updateCompletionStates() {
    setState(() {
      _siteInfoComplete =
          _siteNameController.text.isNotEmpty &&
          _siteLocationController.text.isNotEmpty;

      _ownerInfoComplete =
          _siteOwnerController.text.isNotEmpty &&
          _siteOwnerEmailController.text.isNotEmpty &&
          _siteOwnerPhoneController.text.isNotEmpty;

      _managerInfoComplete =
          _siteManagerController.text.isNotEmpty &&
          _siteManagerEmailController.text.isNotEmpty &&
          _siteManagerPhoneController.text.isNotEmpty;
    });
  }

  Future<void> _setContractorEmail() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      try {
        // Simplified approach: Get contractor email based on user type
        String contractorEmail =
            widget.area.contractorEmail; // Default fallback

        // Check if user is a contractor directly
        final contractorData =
            await Supabase.instance.client
                .from('contractor')
                .select('email')
                .eq('id', user.id)
                .maybeSingle();

        if (contractorData != null) {
          // User is a contractor, use their email
          contractorEmail = contractorData['email'] ?? contractorEmail;
          print('User is contractor with email: $contractorEmail');
        } else {
          // Check if user is a freelancer/site manager
          final freelancerData =
              await Supabase.instance.client
                  .from('freelancers')
                  .select('contractor_id')
                  .eq('email', user.email!)
                  .maybeSingle();

          if (freelancerData != null) {
            // User is a freelancer/site manager, get their contractor's email
            final contractorId = freelancerData['contractor_id'];
            final associatedContractorData =
                await Supabase.instance.client
                    .from('contractor')
                    .select('email')
                    .eq('id', contractorId)
                    .maybeSingle();

            if (associatedContractorData != null) {
              contractorEmail =
                  associatedContractorData['email'] ?? contractorEmail;
              print(
                'User is freelancer/site manager under contractor: $contractorEmail',
              );
            }
          }
        }

        // Set the contractor email
        setState(() {
          _contractorEmailController.text = contractorEmail;
        });
        print('Contractor email set to: $contractorEmail');
      } catch (e) {
        print('Error in _setContractorEmail: $e');
        print('Using widget.area data as fallback');
      }

      // Always ensure we have contractor email from the area as fallback
      if (_contractorEmailController.text.isEmpty &&
          widget.area.contractorEmail.isNotEmpty) {
        setState(() {
          _contractorEmailController.text = widget.area.contractorEmail;
        });
        print(
          'Using area contractor email as fallback: ${widget.area.contractorEmail}',
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _inspectorPhoto = File(pickedFile.path);
      });
    }
  }

  Future<void> _createSite() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      String? photoUrl;
      if (_inspectorPhoto != null) {
        final fileName = '${_uuid.v4()}.jpg';
        await _supabaseService.uploadFile(
          'inspectorphotos',
          fileName,
          _inspectorPhoto!,
        );
        photoUrl = _supabaseService.getFileUrl('inspectorphotos', fileName);
      } else if (_selectedFreelancer != null &&
          _selectedFreelancer!['profile_photo_url'] != null) {
        // If no new photo was uploaded but we have a selected freelancer with a photo
        photoUrl = _selectedFreelancer!['profile_photo_url'];
      }

      // Get the correct contractor_id
      String contractorId;
      try {
        final freelancerDataList = await Supabase.instance.client
            .from('freelancers')
            .select('contractor_id')
            .eq('email', user.email!)
            .limit(1);

        if (freelancerDataList.isNotEmpty) {
          // If user is a freelancer, use the contractor_id from freelancers table
          contractorId = freelancerDataList.first['contractor_id'];
        } else {
          // If user is a contractor, use their own ID
          contractorId = user.id;
        }
      } catch (e) {
        print('Error fetching freelancer data: $e');
        // Fallback to using user's own ID
        contractorId = user.id;
      }

      final site = Site(
        id: _uuid.v4(),
        siteName: _siteNameController.text.trim(),
        siteOwner: _siteOwnerController.text.trim(),
        siteOwnerEmail: _siteOwnerEmailController.text.trim(),
        siteOwnerPhone: _siteOwnerPhoneController.text.trim(),
        siteManager: _siteManagerController.text.trim(),
        siteManagerEmail: _siteManagerEmailController.text.trim(),
        siteManagerPhone: _siteManagerPhoneController.text.trim(),
        siteInspectorName: _siteInspectorNameController.text.trim(),
        siteInspectorEmail: _siteInspectorEmailController.text.trim(),
        siteInspectorPhone: _siteInspectorPhoneController.text.trim(),
        siteInspectorPhoto: photoUrl ?? '',
        siteLocation: _siteLocationController.text.trim(),
        contractorEmail: _contractorEmailController.text.trim(),
        contractorId: contractorId,
        areaId: widget.areaId,
        createdAt: DateTime.now(),
      );

      try {
        final createdSite = await _supabaseService.createSite(site);

        // Only create pump rooms if user selected the option
        if (_createPumpRooms) {
          await _supabaseService.createDefaultPumps(site.id);
        }

        // Create floors based on user input
        await _supabaseService.createDefaultFloors(site.id, _floorCount);

        if (!mounted) return;

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Site created successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Navigate to the site details screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (context) => SiteDetailsScreen(
                  site: createdSite,
                  assignedSections: [], // Admin can see all sections
                ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _showFreelancerSelectionDialog() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please login to continue'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if user is a contractor
      final contractorResponse =
          await Supabase.instance.client
              .from('contractor')
              .select('id')
              .eq('email', user.email!)
              .maybeSingle();

      if (contractorResponse == null) {
        // User is a freelancer, auto-select their own data
        final freelancerDataList = await Supabase.instance.client
            .from('freelancers')
            .select()
            .eq('email', user.email!)
            .limit(1);

        final freelancerData =
            freelancerDataList.isNotEmpty ? freelancerDataList.first : null;

        if (freelancerData != null) {
          setState(() {
            _selectedFreelancer = freelancerData;
            _siteInspectorNameController.text = freelancerData['name'] ?? '';
            _siteInspectorEmailController.text = freelancerData['email'] ?? '';
            _siteInspectorPhoneController.text = freelancerData['phone'] ?? '';
            _inspectorInfoComplete = true;
          });

          // Handle photo if it exists
          if (freelancerData['profile_photo_url'] != null) {
            try {
              final response = await http.get(
                Uri.parse(freelancerData['profile_photo_url']),
              );
              if (response.statusCode == 200) {
                final tempDir = await getTemporaryDirectory();
                final file = File('${tempDir.path}/temp_photo.jpg');
                await file.writeAsBytes(response.bodyBytes);
                setState(() {
                  _inspectorPhoto = file;
                });
              }
            } catch (e) {
              print('Error loading profile photo: $e');
            }
          }
        }
        return;
      }

      // User is a contractor, show selection dialog
      final contractorId = contractorResponse['id'];

      // Fetch all freelancers for this contractor
      final allInspectors = await Supabase.instance.client
          .from('freelancers')
          .select()
          .eq('contractor_id', contractorId);

      // Separate into employees and freelancers based on role
      final employees =
          allInspectors
              .where((inspector) => inspector['role'] == 'employee')
              .toList();
      final freelancers =
          allInspectors
              .where((inspector) => inspector['role'] == 'freelancer')
              .toList();

      if (!mounted) return;

      if (employees.isEmpty && freelancers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No inspectors available for selection'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show selection dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                'Select Site Inspector',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              content: Container(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (employees.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Employees',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        ...employees.map(
                          (employee) => ListTile(
                            leading:
                                employee['profile_photo_url'] != null
                                    ? CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        employee['profile_photo_url'],
                                      ),
                                    )
                                    : CircleAvatar(child: Icon(Icons.person)),
                            title: Text(
                              employee['name'] ?? 'Unnamed Employee',
                              style: GoogleFonts.poppins(),
                            ),
                            subtitle: Text(
                              employee['email'] ?? '',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            onTap: () async {
                              setState(() {
                                _selectedFreelancer = employee;
                                // Prefill inspector details
                                if (employee['name'] != null) {
                                  _siteInspectorNameController.text =
                                      employee['name'];
                                }
                                if (employee['email'] != null) {
                                  _siteInspectorEmailController.text =
                                      employee['email'];
                                }
                                if (employee['phone'] != null) {
                                  _siteInspectorPhoneController.text =
                                      employee['phone'];
                                }
                              });

                              // Handle photo
                              if (employee['profile_photo_url'] != null) {
                                try {
                                  final response = await http.get(
                                    Uri.parse(employee['profile_photo_url']),
                                  );
                                  if (response.statusCode == 200) {
                                    final tempDir =
                                        await getTemporaryDirectory();
                                    final file = File(
                                      '${tempDir.path}/inspector_photo.jpg',
                                    );
                                    await file.writeAsBytes(response.bodyBytes);
                                    setState(() {
                                      _inspectorPhoto = file;
                                    });
                                  }
                                } catch (e) {
                                  print('Error downloading photo: $e');
                                }
                              }

                              setState(() {
                                _inspectorInfoComplete = true;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                      if (freelancers.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Freelancers',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                        ...freelancers.map(
                          (freelancer) => ListTile(
                            leading:
                                freelancer['profile_photo_url'] != null
                                    ? CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        freelancer['profile_photo_url'],
                                      ),
                                    )
                                    : CircleAvatar(child: Icon(Icons.person)),
                            title: Text(
                              freelancer['name'] ?? 'Unnamed Freelancer',
                              style: GoogleFonts.poppins(),
                            ),
                            subtitle: Text(
                              freelancer['email'] ?? '',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            onTap: () async {
                              setState(() {
                                _selectedFreelancer = freelancer;
                                // Prefill inspector details
                                if (freelancer['name'] != null) {
                                  _siteInspectorNameController.text =
                                      freelancer['name'];
                                }
                                if (freelancer['email'] != null) {
                                  _siteInspectorEmailController.text =
                                      freelancer['email'];
                                }
                                if (freelancer['phone'] != null) {
                                  _siteInspectorPhoneController.text =
                                      freelancer['phone'];
                                }
                              });

                              // Handle photo
                              if (freelancer['profile_photo_url'] != null) {
                                try {
                                  final response = await http.get(
                                    Uri.parse(freelancer['profile_photo_url']),
                                  );
                                  if (response.statusCode == 200) {
                                    final tempDir =
                                        await getTemporaryDirectory();
                                    final file = File(
                                      '${tempDir.path}/inspector_photo.jpg',
                                    );
                                    await file.writeAsBytes(response.bodyBytes);
                                    setState(() {
                                      _inspectorPhoto = file;
                                    });
                                  }
                                } catch (e) {
                                  print('Error downloading photo: $e');
                                }
                              }

                              setState(() {
                                _inspectorInfoComplete = true;
                              });
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
              ],
            ),
      );
    } catch (e) {
      print('Error fetching inspectors: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _siteNameController.dispose();
    _siteOwnerController.dispose();
    _siteOwnerEmailController.dispose();
    _siteOwnerPhoneController.dispose();
    _siteManagerController.dispose();
    _siteManagerEmailController.dispose();
    _siteManagerPhoneController.dispose();
    _siteInspectorNameController.dispose();
    _siteInspectorEmailController.dispose();
    _siteInspectorPhoneController.dispose();
    _siteLocationController.dispose();
    _contractorEmailController.dispose();
    _floorCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create New Site',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.blue.shade700,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: Colors.blue.shade700,
            secondary: Colors.green.shade600,
          ),
        ),
        child: Form(
          key: _formKey,
          child: Stepper(
            type: StepperType.vertical,
            physics: const ClampingScrollPhysics(),
            currentStep: _currentStep,
            onStepContinue: () {
              setState(() {
                if (_currentStep < 5) {
                  _currentStep++;
                  _updateProgress();
                } else {
                  _createSite();
                }
              });
            },
            onStepCancel: () {
              setState(() {
                if (_currentStep > 0) {
                  _currentStep--;
                  _updateProgress();
                }
              });
            },
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: details.onStepCancel,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.blue.shade700),
                          ),
                          child: Text(
                            'Previous',
                            style: GoogleFonts.poppins(
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _isCompleting ? null : details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child:
                            _isCompleting
                                ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : Text(
                                  _currentStep == 5 ? 'Create Site' : 'Next',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: Text(
                  'Site Information',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  _siteInfoComplete ? 'Completed' : 'Basic site details',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color:
                        _siteInfoComplete
                            ? Colors.green.shade600
                            : Colors.grey.shade600,
                  ),
                ),
                content: _buildSiteInfoStep(),
                isActive: _currentStep >= 0,
                state:
                    _siteInfoComplete
                        ? StepState.complete
                        : _currentStep > 0
                        ? StepState.error
                        : StepState.indexed,
              ),
              Step(
                title: Text(
                  'Owner Information',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  _ownerInfoComplete ? 'Completed' : 'Owner contact details',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color:
                        _ownerInfoComplete
                            ? Colors.green.shade600
                            : Colors.grey.shade600,
                  ),
                ),
                content: _buildOwnerInfoStep(),
                isActive: _currentStep >= 1,
                state:
                    _ownerInfoComplete
                        ? StepState.complete
                        : _currentStep > 1
                        ? StepState.error
                        : StepState.indexed,
              ),
              Step(
                title: Text(
                  'Manager Information',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  _managerInfoComplete
                      ? 'Completed'
                      : 'Manager contact details',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color:
                        _managerInfoComplete
                            ? Colors.green.shade600
                            : Colors.grey.shade600,
                  ),
                ),
                content: _buildManagerInfoStep(),
                isActive: _currentStep >= 2,
                state:
                    _managerInfoComplete
                        ? StepState.complete
                        : _currentStep > 2
                        ? StepState.error
                        : StepState.indexed,
              ),
              Step(
                title: Text(
                  'Inspector Information',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  _inspectorInfoComplete ? 'Completed' : 'Inspector details',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color:
                        _inspectorInfoComplete
                            ? Colors.green.shade600
                            : Colors.grey.shade600,
                  ),
                ),
                content: _buildInspectorInfoStep(),
                isActive: _currentStep >= 3,
                state:
                    _inspectorInfoComplete
                        ? StepState.complete
                        : _currentStep > 3
                        ? StepState.error
                        : StepState.indexed,
              ),
              Step(
                title: Text(
                  'Pump Room Configuration',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  _pumpRoomConfigComplete
                      ? 'Completed'
                      : 'Configure pump rooms',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color:
                        _pumpRoomConfigComplete
                            ? Colors.green.shade600
                            : Colors.grey.shade600,
                  ),
                ),
                content: _buildPumpRoomConfigStep(),
                isActive: _currentStep >= 4,
                state:
                    _pumpRoomConfigComplete
                        ? StepState.complete
                        : _currentStep > 4
                        ? StepState.error
                        : StepState.indexed,
              ),
              Step(
                title: Text(
                  'Floor Configuration',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  _floorConfigComplete
                      ? 'Completed'
                      : 'Configure building floors',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color:
                        _floorConfigComplete
                            ? Colors.green.shade600
                            : Colors.grey.shade600,
                  ),
                ),
                content: _buildFloorConfigStep(),
                isActive: _currentStep >= 5,
                state:
                    _floorConfigComplete
                        ? StepState.complete
                        : _currentStep > 5
                        ? StepState.error
                        : StepState.indexed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateProgress() {
    _progressAnimationController.forward(from: 0);
  }

  Widget _buildSiteInfoStep() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Site Information',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _siteNameController,
            label: 'Site Name',
            icon: Icons.business,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter site name';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _siteInfoComplete =
                    _siteNameController.text.isNotEmpty &&
                    _siteLocationController.text.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildLocationField(controller: _siteLocationController),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _contractorEmailController,
            label: 'Contractor Email',
            icon: Icons.email,
            enabled: false,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerInfoStep() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Owner Information',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _siteOwnerController,
            label: 'Owner Name',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter owner name';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _ownerInfoComplete =
                    _siteOwnerController.text.isNotEmpty &&
                    _siteOwnerEmailController.text.isNotEmpty &&
                    _siteOwnerPhoneController.text.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _siteOwnerEmailController,
            label: 'Owner Email',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter owner email';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _ownerInfoComplete =
                    _siteOwnerController.text.isNotEmpty &&
                    _siteOwnerEmailController.text.isNotEmpty &&
                    _siteOwnerPhoneController.text.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _siteOwnerPhoneController,
            label: 'Owner Phone',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter owner phone';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _ownerInfoComplete =
                    _siteOwnerController.text.isNotEmpty &&
                    _siteOwnerEmailController.text.isNotEmpty &&
                    _siteOwnerPhoneController.text.isNotEmpty;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildManagerInfoStep() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manager Information',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _siteManagerController,
            label: 'Manager Name',
            icon: Icons.manage_accounts,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter manager name';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _managerInfoComplete =
                    _siteManagerController.text.isNotEmpty &&
                    _siteManagerEmailController.text.isNotEmpty &&
                    _siteManagerPhoneController.text.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _siteManagerEmailController,
            label: 'Manager Email',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter manager email';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _managerInfoComplete =
                    _siteManagerController.text.isNotEmpty &&
                    _siteManagerEmailController.text.isNotEmpty &&
                    _siteManagerPhoneController.text.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _siteManagerPhoneController,
            label: 'Manager Phone',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter manager phone';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _managerInfoComplete =
                    _siteManagerController.text.isNotEmpty &&
                    _siteManagerEmailController.text.isNotEmpty &&
                    _siteManagerPhoneController.text.isNotEmpty;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorInfoStep() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inspector Information',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showFreelancerSelectionDialog,
            icon: Icon(Icons.person_search, size: 18),
            label: Text(
              'Select Inspector',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
              side: BorderSide(color: Colors.blue.shade700),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _siteInspectorNameController,
            label: 'Inspector Name',
            icon: Icons.engineering,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter inspector name';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _inspectorInfoComplete =
                    _siteInspectorNameController.text.isNotEmpty &&
                    _siteInspectorEmailController.text.isNotEmpty &&
                    _siteInspectorPhoneController.text.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _siteInspectorEmailController,
            label: 'Inspector Email',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter inspector email';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _inspectorInfoComplete =
                    _siteInspectorNameController.text.isNotEmpty &&
                    _siteInspectorEmailController.text.isNotEmpty &&
                    _siteInspectorPhoneController.text.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _siteInspectorPhoneController,
            label: 'Inspector Phone',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter inspector phone';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _inspectorInfoComplete =
                    _siteInspectorNameController.text.isNotEmpty &&
                    _siteInspectorEmailController.text.isNotEmpty &&
                    _siteInspectorPhoneController.text.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 20),
          _buildPhotoUploadSection(),
        ],
      ),
    );
  }

  Widget _buildPhotoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inspector Photo',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Column(
              children: [
                if (_inspectorPhoto == null) ...[
                  Icon(
                    Icons.add_a_photo,
                    size: 48,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Upload Inspector Photo',
                    style: GoogleFonts.poppins(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to select a photo',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ] else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.file(
                          _inspectorPhoto!,
                          height: 150,
                          width: 150,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                              ),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPumpRoomConfigStep() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pump Room Configuration',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Would you like to create pump rooms for this site?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        _createPumpRooms ? 'Yes' : 'No',
                        style: GoogleFonts.poppins(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      leading: Icon(
                        _createPumpRooms ? Icons.check_circle : Icons.cancel,
                        color: _createPumpRooms ? Colors.green : Colors.red,
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<bool>(
                                      title: Text(
                                        'Yes',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      value: true,
                                      groupValue: _createPumpRooms,
                                      onChanged: (value) {
                                        setState(() {
                                          _createPumpRooms = value!;
                                          _pumpRoomConfigComplete = true;
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<bool>(
                                      title: Text(
                                        'No',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      value: false,
                                      groupValue: _createPumpRooms,
                                      onChanged: (value) {
                                        setState(() {
                                          _createPumpRooms = value!;
                                          _pumpRoomConfigComplete = true;
                                        });
                                      },
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                    ),
                                  ),
                                ],
                              ),
                              if (_createPumpRooms) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Default pump rooms will be created for this site.',
                                  style: GoogleFonts.poppins(
                                    color: Colors.green.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorConfigStep() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Floor Configuration',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'How many floors are there in the building?',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _floorCountController,
            label: 'Number of floors',
            icon: Icons.layers,
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter number of floors';
              }
              final intValue = int.tryParse(value);
              if (intValue == null || intValue < 1 || intValue > 50) {
                return 'Please enter a number between 1 and 50';
              }
              return null;
            },
            onChanged: (value) {
              final intValue = int.tryParse(value);
              if (intValue != null && intValue >= 1 && intValue <= 50) {
                setState(() {
                  _floorCount = intValue;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Floors will be created as: Floor 1, Floor 2, Floor 3, etc.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _floorCount == 1
                                ? 'Floor 1 will be created with fire alarm templates ready.'
                                : 'Floors 1 to $_floorCount will be created with fire alarm templates ready.',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool enabled = true,
    TextStyle? style,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.blue.shade700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade700, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
      ),
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      enabled: enabled,
      style: style ?? GoogleFonts.poppins(),
    );
  }

  Widget _buildLocationField({required controller, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        suffixIcon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IconButton(
            onPressed: () async {
              _siteLocationController.text = await fetchAddress();
            },
            icon: Icon(Icons.my_location),
            iconSize: 30,
          ),
        ),
        labelText: "Site Location",
        labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
        prefixIcon: Icon(Icons.location_on, color: Colors.blue.shade700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade700, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
      ),
      keyboardType: TextInputType.text,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please press location icon';
        }
        return null;
      },
      enabled: enabled,
      style: GoogleFonts.poppins(),
    );
  }
}
