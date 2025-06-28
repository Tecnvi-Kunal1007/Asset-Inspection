
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart' as location_service;
import '../models/site.dart';
import '../models/area.dart';
import 'site_details_screen.dart';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../utils/responsive_helper.dart';

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
  Uint8List? _inspectorPhotoBytes;
  String _siteLocation = '';
  int _currentStep = 0;
  bool _isCompleting = false;
  int _floorCount = 1;
  final _floorCountController = TextEditingController();

// Multiple sites functionality
  List<Map<String, dynamic>> _siteConfigurations = [];
  int _currentSiteNumber = 1;
  bool _isAddingMultipleSites = false;
  bool _isCreatingAllSites = false;

// Controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
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

// Step completion status
  bool _basicInfoComplete = false;
  bool _contactInfoComplete = false;
  bool _inspectorInfoComplete = false;
  bool _locationInfoComplete = false;
  bool _floorConfigComplete = false;

// Animation controllers
  late AnimationController _progressAnimationController;
  late Animation<double> _progressAnimation;

// Selected freelancer data
  Map<String, dynamic>? _selectedFreelancer;

  @override
  void initState() {
    super.initState();
    _floorCountController.text = _floorCount.toString();

// Add listener to floor count controller
    _floorCountController.addListener(() {
      final text = _floorCountController.text.trim();
      if (text.isNotEmpty) {
        final value = int.tryParse(text);
        if (value != null && value >= 1 && value <= 50) {
          _floorCount = value;
        }
      }
      _updateCompletionStates();
    });

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
    _siteOwnerController.text = widget.area.siteOwner;
    _siteOwnerEmailController.text = widget.area.siteOwnerEmail;
    _siteOwnerPhoneController.text = widget.area.siteOwnerPhone;
    _siteManagerController.text = widget.area.siteManager;
    _siteManagerEmailController.text = widget.area.siteManagerEmail;
    _siteManagerPhoneController.text = widget.area.siteManagerPhone;
    _siteLocationController.text = widget.area.siteLocation;

    _siteNameController.text = _getSiteName(_currentSiteNumber);

// Get current user details
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      try {
// Check if user is a freelancer or employee
        final userData = await Supabase.instance.client
            .from('freelancers')
            .select()
            .eq('email', user.email!)
            .maybeSingle();

        if (userData != null) {
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
                setState(() {
                  _inspectorPhotoBytes = response.bodyBytes;
                  _inspectorPhoto = null;
                });
              }
            } catch (e) {
              print('Error loading profile photo: $e');
            }
          }

          print(
              'Prefilled inspector details for ${userData['role']}: ${userData['name']}');
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }

    _updateCompletionStates();
  }

  void _updateCompletionStates() {
    setState(() {
      _basicInfoComplete =
          _siteNameController.text.isNotEmpty &&
              _siteLocationController.text.isNotEmpty;

      _contactInfoComplete =
          _siteOwnerController.text.isNotEmpty &&
              _siteOwnerEmailController.text.isNotEmpty &&
              _siteOwnerPhoneController.text.isNotEmpty;

      _inspectorInfoComplete =
          _siteInspectorNameController.text.isNotEmpty &&
              _siteInspectorEmailController.text.isNotEmpty &&
              _siteInspectorPhoneController.text.isNotEmpty;

      _locationInfoComplete = _siteLocationController.text.isNotEmpty;

      final floorText = _floorCountController.text.trim();
      if (floorText.isNotEmpty) {
        final floorValue = int.tryParse(floorText);
        _floorConfigComplete =
            floorValue != null && floorValue >= 1 && floorValue <= 50;
      } else {
        _floorConfigComplete = false;
      }
    });
  }

  String _getSiteName(int siteNumber) {
    switch (siteNumber) {
      case 1:
        return "Building One";
      case 2:
        return "Building Two";
      case 3:
        return "Building Three";
      case 4:
        return "Building Four";
      case 5:
        return "Building Five";
      case 6:
        return "Building Six";
      case 7:
        return "Building Seven";
      case 8:
        return "Building Eight";
      case 9:
        return "Building Nine";
      case 10:
        return "Building Ten";
      default:
        return "Building $siteNumber";
    }
  }

  void _addCurrentSiteToConfigurations() {
    final currentSiteConfig = {
      'siteName': _siteNameController.text.trim(),
      'siteLocation': _siteLocationController.text.trim(),
      'floorCount': _floorCount,
      'siteNumber': _currentSiteNumber,
    };

    _siteConfigurations.add(currentSiteConfig);
  }

  void _resetForNextSite() {
    setState(() {
      _currentSiteNumber++;
      _siteNameController.text = _getSiteName(_currentSiteNumber);
      _floorCount = 1;
      _floorCountController.text = _floorCount.toString();
      _currentStep = 0;
      _isAddingMultipleSites = true;
      _updateCompletionStates();
    });
  }

  Future<void> _setContractorEmail() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      try {
        String contractorEmail = widget.area.contractorEmail;
        final contractorData = await Supabase.instance.client
            .from('contractor')
            .select('email')
            .eq('id', user.id)
            .maybeSingle();

        if (contractorData != null) {
          contractorEmail = contractorData['email'] ?? contractorEmail;
        } else {
          final freelancerData = await Supabase.instance.client
              .from('freelancers')
              .select('contractor_id')
              .eq('email', user.email!)
              .maybeSingle();

          if (freelancerData != null) {
            final contractorId = freelancerData['contractor_id'];
            final associatedContractorData = await Supabase.instance.client
                .from('contractor')
                .select('email')
                .eq('id', contractorId)
                .maybeSingle();

            if (associatedContractorData != null) {
              contractorEmail =
                  associatedContractorData['email'] ?? contractorEmail;
            }
          }
        }

        setState(() {
          _contractorEmailController.text = contractorEmail;
        });
      } catch (e) {
        print('Error in _setContractorEmail: $e');
      }

      if (_contractorEmailController.text.isEmpty &&
          widget.area.contractorEmail.isNotEmpty) {
        setState(() {
          _contractorEmailController.text = widget.area.contractorEmail;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _inspectorPhotoBytes = bytes;
          _inspectorPhoto = null;
        });
      } else {
        setState(() {
          _inspectorPhoto = File(pickedFile.path);
          _inspectorPhotoBytes = null;
        });
      }
    }
  }

  Future<void> _createSingleSite() async {
    try {
      setState(() {
        _isCompleting = true;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (!_formKey.currentState!.validate()) {
        setState(() {
          _isCompleting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill all required fields'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      String? photoUrl;
      if (_inspectorPhoto != null || _inspectorPhotoBytes != null) {
        final fileName = '${_uuid.v4()}.jpg';
        if (kIsWeb && _inspectorPhotoBytes != null) {
          await _supabaseService.uploadBytes(
            'inspectorphotos',
            fileName,
            _inspectorPhotoBytes!,
          );
        } else if (_inspectorPhoto != null) {
          await _supabaseService.uploadFile(
            'inspectorphotos',
            fileName,
            _inspectorPhoto!,
          );
        }
        photoUrl = _supabaseService.getFileUrl('inspectorphotos', fileName);
      } else if (_selectedFreelancer != null &&
          _selectedFreelancer!['profile_photo_url'] != null) {
        photoUrl = _selectedFreelancer!['profile_photo_url'];
      }

      String contractorId;
      try {
        final freelancerDataList = await Supabase.instance.client
            .from('freelancers')
            .select('contractor_id')
            .eq('email', user.email!)
            .limit(1);

        if (freelancerDataList.isNotEmpty) {
          contractorId = freelancerDataList.first['contractor_id'];
        } else {
          contractorId = user.id;
        }
      } catch (e) {
        print('Error fetching freelancer data: $e');
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
        description: _descriptionController.text.trim(),
      );

      final createdSite = await _supabaseService.createSite(site);

      await _supabaseService.createDefaultFloors(site.id, _floorCount);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Site "${site.siteName}" created successfully!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      print('Error creating site: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating site: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        _isCompleting = false;
      });
    }
  }

  Future<void> _createSite() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_basicInfoComplete || !_contactInfoComplete ||
        !_inspectorInfoComplete || !_floorConfigComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete all steps before creating the site'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isAddingMultipleSites || _siteConfigurations.isNotEmpty) {
      _addCurrentSiteToConfigurations();
      await _createAllSites();
      return;
    }
    await _createSingleSite();
  }

  Future<void> _createAllSites() async {
    try {
      setState(() {
        _isCreatingAllSites = true;
      });

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      String? photoUrl;
      if (_inspectorPhoto != null || _inspectorPhotoBytes != null) {
        final fileName = '${_uuid.v4()}.jpg';
        if (kIsWeb && _inspectorPhotoBytes != null) {
          await _supabaseService.uploadBytes(
            'inspectorphotos',
            fileName,
            _inspectorPhotoBytes!,
          );
        } else if (_inspectorPhoto != null) {
          await _supabaseService.uploadFile(
            'inspectorphotos',
            fileName,
            _inspectorPhoto!,
          );
        }
        photoUrl = _supabaseService.getFileUrl('inspectorphotos', fileName);
      } else if (_selectedFreelancer != null &&
          _selectedFreelancer!['profile_photo_url'] != null) {
        photoUrl = _selectedFreelancer!['profile_photo_url'];
      }

      String contractorId;
      try {
        final freelancerDataList = await Supabase.instance.client
            .from('freelancers')
            .select('contractor_id')
            .eq('email', user.email!)
            .limit(1);

        if (freelancerDataList.isNotEmpty) {
          contractorId = freelancerDataList.first['contractor_id'];
        } else {
          contractorId = user.id;
        }
      } catch (e) {
        print('Error fetching freelancer data: $e');
        contractorId = user.id;
      }

      List<Site> createdSites = [];
      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < _siteConfigurations.length; i++) {
        try {
          final siteConfig = _siteConfigurations[i];

          final site = Site(
            id: _uuid.v4(),
            siteName: siteConfig['siteName'],
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
            siteLocation: siteConfig['siteLocation'],
            contractorEmail: _contractorEmailController.text.trim(),
            contractorId: contractorId,
            areaId: widget.areaId,
            createdAt: DateTime.now(),
            description: _descriptionController.text.trim(),
          );

          final createdSite = await _supabaseService.createSite(site);
          createdSites.add(createdSite);

          await _supabaseService.createDefaultFloors(
            site.id,
            siteConfig['floorCount'],
          );

          successCount++;
        } catch (e) {
          print(
              'Error creating site ${_siteConfigurations[i]['siteName']}: $e');
          failCount++;
        }
      }

      if (!mounted) return;

      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'All $successCount sites created successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$successCount sites created, $failCount failed',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: failCount > successCount ? Colors.red : Colors
                .orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating sites: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        _isCreatingAllSites = false;
      });
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

      final contractorResponse = await Supabase.instance.client
          .from('contractor')
          .select('id')
          .eq('email', user.email!)
          .maybeSingle();

      if (contractorResponse == null) {
        final freelancerDataList = await Supabase.instance.client
            .from('freelancers')
            .select()
            .eq('email', user.email!)
            .limit(1);

        final freelancerData = freelancerDataList.isNotEmpty
            ? freelancerDataList.first
            : null;

        if (freelancerData != null) {
          setState(() {
            _selectedFreelancer = freelancerData;
            _siteInspectorNameController.text = freelancerData['name'] ?? '';
            _siteInspectorEmailController.text = freelancerData['email'] ?? '';
            _siteInspectorPhoneController.text = freelancerData['phone'] ?? '';
            _inspectorInfoComplete = true;
          });

          if (freelancerData['profile_photo_url'] != null) {
            try {
              final response = await http.get(
                  Uri.parse(freelancerData['profile_photo_url']));
              if (response.statusCode == 200) {
                setState(() {
                  _inspectorPhotoBytes = response.bodyBytes;
                  _inspectorPhoto = null;
                });
              }
            } catch (e) {
              print('Error downloading photo: $e');
            }
          }
          return;
        }
      }

      final contractorId = contractorResponse?['id'];

      final allInspectors = await Supabase.instance.client
          .from('freelancers')
          .select()
          .eq('contractor_id', contractorId);

      final employees = allInspectors.where((inspector) =>
      inspector['role'] == 'employee').toList();
      final freelancers = allInspectors.where((
          inspector) => inspector['role'] == 'freelancer').toList();

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

      showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text(
                'Select Site Inspector',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              content: Container(
                width: double.maxFinite,
                height: MediaQuery
                    .of(context)
                    .size
                    .height * 0.6,
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
                              (employee) =>
                              ListTile(
                                leading: employee['profile_photo_url'] != null
                                    ? CircleAvatar(
                                  backgroundImage: NetworkImage(
                                      employee['profile_photo_url']),
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

                                  if (employee['profile_photo_url'] != null) {
                                    try {
                                      final response = await http.get(Uri.parse(
                                          employee['profile_photo_url']));
                                      if (response.statusCode == 200) {
                                        setState(() {
                                          _inspectorPhotoBytes =
                                              response.bodyBytes;
                                          _inspectorPhoto = null;
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
                              (freelancer) =>
                              ListTile(
                                leading: freelancer['profile_photo_url'] != null
                                    ? CircleAvatar(
                                  backgroundImage: NetworkImage(
                                      freelancer['profile_photo_url']),
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

                                  if (freelancer['profile_photo_url'] != null) {
                                    try {
                                      final response = await http.get(Uri.parse(
                                          freelancer['profile_photo_url']));
                                      if (response.statusCode == 200) {
                                        setState(() {
                                          _inspectorPhotoBytes =
                                              response.bodyBytes;
                                          _inspectorPhoto = null;
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

  Future<String> fetchAddress() async {
    try {
      final address = await location_service.fetchAddress();
      _updateCompletionStates();
      return address;
    } catch (e) {
      print('Error fetching address: $e');
      if (!mounted) return 'Unable to fetch location';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      return 'Unable to fetch location';
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
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
          _isAddingMultipleSites || _siteConfigurations.isNotEmpty
              ? 'Create Site $_currentSiteNumber'
              : 'Create New Site',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveHelper.getFontSize(context, 16),
          ),
        ),
        elevation: 0,
        backgroundColor: Theme
            .of(context)
            .scaffoldBackgroundColor,
        foregroundColor: Colors.blue.shade700,
        actions: [
          if (_siteConfigurations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_siteConfigurations.length + 1} sites',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.getFontSize(context, 12),
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            type: ResponsiveHelper.isMobile(context)
                ? StepperType.vertical
                : StepperType.horizontal,
            physics: const ClampingScrollPhysics(),
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 3) {
                bool canProceed = false;
                switch (_currentStep) {
                  case 0:
                    canProceed = _basicInfoComplete;
                    break;
                  case 1:
                    canProceed = _contactInfoComplete;
                    break;
                  case 2:
                    canProceed = _inspectorInfoComplete;
                    break;
                  case 3:
                    canProceed = _floorConfigComplete;
                    break;
                }

                if (canProceed) {
                  setState(() {
                    _currentStep++;
                    _updateProgress();
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Please complete the current step before proceeding'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              } else {
                _createSite();
              }
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
                child: _currentStep == 3
                    ? _buildFinalStepControls()
                    : Row(
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
                              fontSize: ResponsiveHelper.getFontSize(
                                  context, 14),
                            ),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: details.onStepContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _currentStep == 3 ? 'Create Site' : 'Next',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: ResponsiveHelper.getFontSize(context, 14),
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
                    fontSize: ResponsiveHelper.getFontSize(context, 16),
                  ),
                ),
                subtitle: Text(
                  _basicInfoComplete ? 'Completed' : 'Basic site details',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 12),
                    color: _basicInfoComplete ? Colors.green.shade600 : Colors
                        .grey.shade600,
                  ),
                ),
                content: _buildSiteInfoStep(),
                isActive: _currentStep >= 0,
                state: _basicInfoComplete
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
                    fontSize: ResponsiveHelper.getFontSize(context, 16),
                  ),
                ),
                subtitle: Text(
                  _contactInfoComplete ? 'Completed' : 'Owner contact details',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 12),
                    color: _contactInfoComplete ? Colors.green.shade600 : Colors
                        .grey.shade600,
                  ),
                ),
                content: _buildOwnerInfoStep(),
                isActive: _currentStep >= 1,
                state: _contactInfoComplete
                    ? StepState.complete
                    : _currentStep > 1
                    ? StepState.error
                    : StepState.indexed,
              ),
              Step(
                title: Text(
                  'Inspector Information',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: ResponsiveHelper.getFontSize(context, 16),
                  ),
                ),
                subtitle: Text(
                  _inspectorInfoComplete ? 'Completed' : 'Inspector details',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 12),
                    color: _inspectorInfoComplete
                        ? Colors.green.shade600
                        : Colors.grey.shade600,
                  ),
                ),
                content: _buildInspectorInfoStep(),
                isActive: _currentStep >= 2,
                state: _inspectorInfoComplete
                    ? StepState.complete
                    : _currentStep > 2
                    ? StepState.error
                    : StepState.indexed,
              ),
              Step(
                title: Text(
                  'Floor Configuration',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: ResponsiveHelper.getFontSize(context, 16),
                  ),
                ),
                subtitle: Text(
                  _floorConfigComplete
                      ? 'Completed'
                      : 'Configure building floors',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 12),
                    color: _floorConfigComplete ? Colors.green.shade600 : Colors
                        .grey.shade600,
                  ),
                ),
                content: _buildFloorConfigStep(),
                isActive: _currentStep >= 3,
                state: _floorConfigComplete
                    ? StepState.complete
                    : _currentStep > 3
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

  Widget _buildFinalStepControls() {
    return Column(
      children: [
        if (_siteConfigurations.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configured Sites (${_siteConfigurations.length + 1}):',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ...(_siteConfigurations.map(
                      (config) =>
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green,
                                size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${config['siteName']} (${config['floorCount']} floors)',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                )),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.settings, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_siteNameController
                              .text} ($_floorCount floors) - Current',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      if (_currentStep > 0) {
                        _currentStep--;
                        _updateProgress();
                      }
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(color: Colors.blue.shade700),
                  ),
                  child: Text(
                    'Previous',
                    style: GoogleFonts.poppins(color: Colors.blue.shade700),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: (_isCompleting || _isCreatingAllSites)
                    ? null
                    : () {
                  _addCurrentSiteToConfigurations();
                  _resetForNextSite();
                },
                icon: const Icon(Icons.add),
                label: Text('Add Another Site', style: GoogleFonts.poppins()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(color: Colors.green.shade700),
                  foregroundColor: Colors.green.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_isCompleting || _isCreatingAllSites)
                    ? null
                    : _createSite,
                icon: (_isCompleting || _isCreatingAllSites)
                    ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(
                    _siteConfigurations.isNotEmpty ? Icons.done_all : Icons
                        .done),
                label: Text(
                  (_isCompleting || _isCreatingAllSites)
                      ? (_siteConfigurations.isNotEmpty
                      ? 'Creating Sites...'
                      : 'Creating Site...')
                      : (_siteConfigurations.isNotEmpty
                      ? 'Create All Sites'
                      : 'Create Site'),
                  style: GoogleFonts.poppins(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
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
          Row(
            children: [
              Text(
                'Site Information',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.getFontSize(context, 18),
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              if (_isAddingMultipleSites || _siteConfigurations.isNotEmpty) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Site $_currentSiteNumber',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.getFontSize(context, 12),
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          ResponsiveHelper.responsiveWidget(
            context: context,
            mobile: Column(
              children: [
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
                    _updateCompletionStates();
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
            tablet: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
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
                          _updateCompletionStates();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildLocationField(
                          controller: _siteLocationController),
                    ),
                  ],
                ),
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
            desktop: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTextField(
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
                          _updateCompletionStates();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildLocationField(
                          controller: _siteLocationController),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _contractorEmailController,
                        label: 'Contractor Email',
                        icon: Icons.email,
                        enabled: false,
                        style: TextStyle(color: Colors.grey[700]),
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
              fontSize: ResponsiveHelper.getFontSize(context, 18),
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
              _updateCompletionStates();
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
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(
                  value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            onChanged: (value) {
              _updateCompletionStates();
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
              if (value.length < 10) {
                return 'Please enter a valid phone number';
              }
              return null;
            },
            onChanged: (value) {
              _updateCompletionStates();
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
              fontSize: ResponsiveHelper.getFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showFreelancerSelectionDialog,
            icon: Icon(Icons.person_search,
                size: ResponsiveHelper.getFontSize(context, 18)),
            label: Text(
              'Select Inspector',
              style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.getFontSize(context, 13)),
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
              _updateCompletionStates();
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
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(
                  value)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            onChanged: (value) {
              _updateCompletionStates();
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
              if (value.length < 10) {
                return 'Please enter a valid phone number';
              }
              return null;
            },
            onChanged: (value) {
              _updateCompletionStates();
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
            fontSize: ResponsiveHelper.getFontSize(context, 16),
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
                if (_inspectorPhoto == null &&
                    _inspectorPhotoBytes == null) ...[
                  Icon(
                    Icons.add_a_photo,
                    size: ResponsiveHelper.getFontSize(context, 48),
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
                      fontSize: ResponsiveHelper.getFontSize(context, 12),
                    ),
                  ),
                ] else
                  ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_inspectorPhotoBytes != null)
                            Image.memory(
                              _inspectorPhotoBytes!,
                              height: ResponsiveHelper.getFontSize(
                                  context, 150),
                              width: ResponsiveHelper.getFontSize(context, 150),
                              fit: BoxFit.cover,
                            )
                          else
                            if (_inspectorPhoto != null)
                              Image.file(
                                _inspectorPhoto!,
                                height: ResponsiveHelper.getFontSize(
                                    context, 150),
                                width: ResponsiveHelper.getFontSize(
                                    context, 150),
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
              ],
            ),
          ),
        ),
      ],
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
              fontSize: ResponsiveHelper.getFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'How many floors are there in the building?',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.getFontSize(context, 16),
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
                        size: ResponsiveHelper.getFontSize(context, 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Floors will be created as: Floor 1, Floor 2, Floor 3, etc.',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 12),
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
                          size: ResponsiveHelper.getFontSize(context, 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _floorCount == 1
                                ? 'Floor 1 will be created with fire alarm templates ready.'
                                : 'Floors 1 to $_floorCount will be created with fire alarm templates ready.',
                            style: GoogleFonts.poppins(
                              fontSize: ResponsiveHelper.getFontSize(
                                  context, 12),
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

  Widget _buildLocationField(
      {required TextEditingController controller, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        suffixIcon: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IconButton(
            onPressed: () async {
              try {
                final address = await fetchAddress();
                controller.text = address;
                _updateCompletionStates();
              } catch (e) {
                print('Error fetching address: $e');
              }
            },
            icon: Icon(Icons.my_location),
            iconSize: ResponsiveHelper.getFontSize(context, 30),
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
          return 'Please enter site location or press location icon';
        }
        return null;
      },
      enabled: enabled,
      style: GoogleFonts.poppins(),
      onChanged: (value) {
        _updateCompletionStates();
      },
    );
  }
}