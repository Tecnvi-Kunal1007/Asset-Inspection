import 'package:flutter/material.dart';
import '../models/site.dart';
import '../models/pump.dart';
import '../models/floor.dart';
import '../models/hydrant_valve.dart';
import '../models/hydrant_ug.dart';
import '../models/hydrant_wheel.dart';
import '../models/hydrant_cap.dart';
import '../models/hydrant_mouth_gasket.dart';
import '../models/canvas_hose.dart';
import '../models/branch_pipe.dart';
import '../models/fireman_axe.dart';
import '../models/hose_reel.dart';
import '../models/shut_off_nozzle.dart';
import '../services/supabase_service.dart';
import 'pump_details_screen.dart';
import 'qr_scanner_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart'; // Added to open downloaded files
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/floor_components.dart';
import '../components/fire_alarm_floor_components.dart';
import '../components/fire_alarm_floor_management.dart';
import '../components/building_accessories.dart';
import '../components/site_report_generator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../components/add_building_accessories.dart';

class SiteDetailsScreen extends StatefulWidget {
  final Site site;
  final List<String> assignedSections;

  const SiteDetailsScreen({
    super.key,
    required this.site,
    required this.assignedSections,
  });

  @override
  State<SiteDetailsScreen> createState() => _SiteDetailsScreenState();
}

class _SiteDetailsScreenState extends State<SiteDetailsScreen> {
  final _supabaseService = SupabaseService();
  List<Pump> _pumps = [];
  List<Floor> _floors = [];
  bool _isLoading = true;
  bool _isGeneratingReport = false;
  String? _reportUrl;
  Map<String, dynamic>? _assignedFreelancer;
  Map<String, dynamic>? _pumpsFloorFreelancer;
  Map<String, dynamic>? _buildingFireFreelancer;
  String? _lastViewedPumpId;
  String? _siteDescription;
  final _descriptionController = TextEditingController();
  bool _isSavingDescription = false;
  Map<String, bool> _isSavingPump = {};
  Floor? _selectedFloor;
  Floor? _selectedPumpFloor;
  Floor? _selectedFireAlarmFloor;
  bool _isContractor = false;

  // Add controllers for each editable field
  Map<String, TextEditingController> _pumpControllers = {};
  Map<String, String> _pumpStatuses = {};
  Map<String, String> _pumpModes = {};
  Map<String, String> _pumpValveStatuses = {};
  Map<String, dynamic> _pumpNumericValues =
      {}; // Changed from Map<String, num> to Map<String, dynamic>

  // Add these new variables for operational tests
  Map<String, Map<String, dynamic>> _operationalTests = {};
  Map<String, bool> _isSavingTest = {};
  Map<String, Map<String, String>> _engineInspections = {};
  Map<String, bool> _isSavingInspection = {};

  // Add these maps to the class variables at the top of the _SiteDetailsScreenState class
  Map<String, bool> _isEditingInspection = {};
  Map<String, TextEditingController> _inspectionValueControllers = {};
  Map<String, TextEditingController> _inspectionCommentsControllers = {};

  // Add these controllers at the top of the class with other controllers
  Map<String, TextEditingController> _standardValueControllers = {};
  Map<String, TextEditingController> _observedValueControllers = {};
  Map<String, TextEditingController> _testCommentsControllers = {};

  MobileScannerController? _scannerController;

  // Add variables for bulk save operations
  bool _isSavingAllTests = false;
  bool _isSavingAllInspections = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _initializeData();
    _loadAssignedFreelancers(); // Add this line
  }

  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final contractorResponse =
            await Supabase.instance.client
                .from('contractor')
                .select('id')
                .eq('email', user.email!)
                .maybeSingle();

        setState(() {
          _isContractor = contractorResponse != null;
        });
      }
    } catch (e) {
      print('Error checking user role: $e');
    }
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load all data in parallel
      await Future.wait([
        _loadPumps(),
        _loadReports(),
        _loadAssignedFreelancer(),
        _loadLastViewedPump(),
        _loadSiteDescription(),
        _loadFloors(),
      ]);

      // Load operational tests and engine inspections after floors are loaded
      await Future.wait([_loadOperationalTests(), _loadEngineInspections()]);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    // Dispose all pump controllers
    _pumpControllers.values.forEach((controller) => controller.dispose());
    // Dispose all inspection controllers
    _inspectionValueControllers.values.forEach(
      (controller) => controller.dispose(),
    );
    _inspectionCommentsControllers.values.forEach(
      (controller) => controller.dispose(),
    );
    // Dispose all test controllers
    _standardValueControllers.values.forEach(
      (controller) => controller.dispose(),
    );
    _observedValueControllers.values.forEach(
      (controller) => controller.dispose(),
    );
    _testCommentsControllers.values.forEach(
      (controller) => controller.dispose(),
    );
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _loadSiteDescription() async {
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase
              .from('site_descriptions')
              .select('description')
              .eq('site_id', widget.site.id)
              .maybeSingle();

      if (response != null) {
        setState(() {
          _siteDescription = response['description'];
          _descriptionController.text = _siteDescription ?? '';
        });
      }
    } catch (e) {
      print('Error loading site description: $e');
    }
  }

  Future<void> _saveSiteDescription() async {
    if (_isSavingDescription) return;

    setState(() {
      _isSavingDescription = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final description = _descriptionController.text.trim();

      await supabase.from('site_descriptions').upsert({
        'site_id': widget.site.id,
        'description': description,
        'updated_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        _siteDescription = description;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Site description saved successfully',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving site description: $e',
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
        setState(() {
          _isSavingDescription = false;
        });
      }
    }
  }

  Future<void> _loadLastViewedPump() async {
    final prefs = await SharedPreferences.getInstance();
    final lastViewedPumpId = prefs.getString(
      'last_viewed_pump_${widget.site.id}',
    );
    if (mounted) {
      setState(() {
        _lastViewedPumpId = lastViewedPumpId;
      });
    }
  }

  Future<void> _saveLastViewedPump(String pumpId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_viewed_pump_${widget.site.id}', pumpId);
    if (mounted) {
      setState(() {
        _lastViewedPumpId = pumpId;
      });
    }
  }

  Future<void> _loadPumps() async {
    try {
      final pumps = await _supabaseService.getPumpsBySiteId(widget.site.id);
      setState(() {
        _pumps = pumps;
        _isLoading = false;
        // Initialize controllers and status maps for each pump
        for (var pump in pumps) {
          _pumpControllers[pump.id] = TextEditingController(
            text: pump.comments,
          );
          // Ensure status values match exactly with dropdown options
          _pumpStatuses[pump.id] =
              pump.status == 'Not Working' ? 'Not Working' : 'Working';
          _pumpModes[pump.id] = pump.mode == 'Manual' ? 'Manual' : 'Auto';
          _pumpValveStatuses['${pump.id}_suction'] =
              pump.suctionValve == 'Closed' ? 'Closed' : 'Open';
          _pumpValveStatuses['${pump.id}_delivery'] =
              pump.deliveryValve == 'Closed' ? 'Closed' : 'Open';
          _pumpValveStatuses['${pump.id}_gauge'] =
              pump.pressureGauge == 'Not Working' ? 'Not Working' : 'Working';
          _pumpNumericValues['${pump.id}_capacity'] = pump.capacity;
          _pumpNumericValues['${pump.id}_head'] = pump.head;
          _pumpNumericValues['${pump.id}_ratedPower'] = pump.ratedPower;
          _pumpNumericValues['${pump.id}_startPressure'] = pump.startPressure;
          _pumpNumericValues['${pump.id}_stop_pressure'] = pump.stopPressure;
          _isSavingPump[pump.id] = false;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _loadReports() async {
    try {
      final reports = await _supabaseService.getSiteReports(widget.site.id);
      if (reports.isNotEmpty) {
        setState(() {
          _reportUrl = reports.first['url'];
        });
      }
    } catch (error) {
      print('Error loading reports: $error');
    }
  }

  Future<void> _loadAssignedFreelancer() async {
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase
              .from('site_assignments')
              .select('freelancer_id')
              .eq('site_id', widget.site.id)
              .single();

      if (response != null) {
        final freelancerResponse =
            await supabase
                .from('freelancers')
                .select()
                .eq('id', response['freelancer_id'])
                .single();

        setState(() {
          _assignedFreelancer = freelancerResponse;
        });
      }
    } catch (e) {
      // No freelancer assigned or error occurred
      print('Error loading assigned freelancer: $e');
    }
  }

  Future<void> _loadFloors() async {
    try {
      final floors = await _supabaseService.getFloorsBySiteId(widget.site.id);
      if (mounted) {
        setState(() {
          _floors = floors;
        });
        if (_selectedPumpFloor != null) {
          _loadOperationalTests();
          _loadEngineInspections();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading floors: $e')));
      }
    }
  }

  Future<void> _loadOperationalTests() async {
    try {
      print('Loading operational tests for site: ${widget.site.id}');
      final tests = await _supabaseService.getOperationalTests(widget.site.id);
      print('Loaded operational tests: $tests');

      if (mounted) {
        setState(() {
          _operationalTests = {};
          for (var test in tests) {
            final testType = test['test_type'] as String;
            _operationalTests[testType] = {
              'standard_value': test['standard_value']?.toString() ?? '',
              'observed_value': test['observed_value']?.toString() ?? '',
              'comments': test['comments']?.toString() ?? '',
            };

            // Initialize or update controllers
            _standardValueControllers[testType]?.text =
                test['standard_value']?.toString() ?? '';
            _observedValueControllers[testType]?.text =
                test['observed_value']?.toString() ?? '';
            _testCommentsControllers[testType]?.text =
                test['comments']?.toString() ?? '';
          }
          print('Updated operational tests state: $_operationalTests');
        });
      }
    } catch (e) {
      print('Error loading operational tests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading operational tests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadEngineInspections() async {
    try {
      print('Loading engine inspections for site: ${widget.site.id}');
      final inspections = await _supabaseService.getEngineInspections(
        widget.site.id,
      );
      print('Loaded engine inspections: $inspections');

      if (mounted) {
        setState(() {
          _engineInspections = {};
          for (var inspection in inspections) {
            final inspectionType = inspection['inspection_type'] as String;
            _engineInspections[inspectionType] = {
              'value': inspection['value']?.toString() ?? '',
              'comments': inspection['comments']?.toString() ?? '',
            };
          }
          print('Updated engine inspections state: $_engineInspections');
        });
      }
    } catch (e) {
      print('Error loading engine inspections: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading engine inspections: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveOperationalTest(String testType) async {
    if (_isSavingTest[testType] == true) return;

    setState(() {
      _isSavingTest[testType] = true;
    });

    try {
      final testData = _operationalTests[testType] ?? {};
      print('Saving operational test: $testType with data: $testData');

      await _supabaseService.saveOperationalTest(
        siteId: widget.site.id,
        testType: testType,
        standardValue: double.tryParse(testData['standard_value'] ?? '0') ?? 0,
        observedValue: double.tryParse(testData['observed_value'] ?? '0') ?? 0,
        comments: testData['comments'] ?? '',
      );

      // Unfocus all text fields
      FocusScope.of(context).unfocus();

      // Reload operational tests after saving
      await _loadOperationalTests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${testType == 'hydrant' ? 'Hydrant' : 'Sprinkler'} test saved successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving operational test: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving test: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingTest[testType] = false;
        });
      }
    }
  }

  Future<void> _saveEngineInspection(String inspectionType) async {
    if (_isSavingInspection[inspectionType] == true) return;

    setState(() {
      _isSavingInspection[inspectionType] = true;
    });

    try {
      final inspectionData = _engineInspections[inspectionType] ?? {};
      print(
        'Saving engine inspection: $inspectionType with data: $inspectionData',
      );

      await _supabaseService.saveEngineInspection(
        siteId: widget.site.id,
        inspectionType: inspectionType,
        value: inspectionData['value'] ?? '',
        comments: inspectionData['comments'] ?? '',
      );

      // Unfocus all text fields
      FocusScope.of(context).unfocus();

      // Reload engine inspections after saving
      await _loadEngineInspections();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Engine inspection saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving engine inspection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving inspection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingInspection[inspectionType] = false;
        });
      }
    }
  }

  // Add methods for bulk save operations
  Future<void> _saveAllOperationalTests() async {
    if (_isSavingAllTests) return;

    setState(() {
      _isSavingAllTests = true;
    });

    try {
      List<String> failedTests = [];

      // Save all operational tests
      for (String testType in ['hydrant', 'sprinkler']) {
        try {
          final testData = _operationalTests[testType] ?? {};
          await _supabaseService.saveOperationalTest(
            siteId: widget.site.id,
            testType: testType,
            standardValue:
                double.tryParse(testData['standard_value'] ?? '0') ?? 0,
            observedValue:
                double.tryParse(testData['observed_value'] ?? '0') ?? 0,
            comments: testData['comments'] ?? '',
          );
        } catch (e) {
          print('Error saving $testType test: $e');
          failedTests.add(testType);
        }
      }

      // Unfocus all text fields
      FocusScope.of(context).unfocus();

      // Reload operational tests after saving
      await _loadOperationalTests();

      if (mounted) {
        if (failedTests.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('All operational tests saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Some tests failed to save: ${failedTests.join(', ')}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving operational tests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving operational tests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAllTests = false;
        });
      }
    }
  }

  Future<void> _saveAllEngineInspections() async {
    if (_isSavingAllInspections) return;

    setState(() {
      _isSavingAllInspections = true;
    });

    try {
      List<String> failedInspections = [];

      // Save all engine inspections
      List<String> inspectionTypes = [
        'engine_oil',
        'fuel_level',
        'battery_condition',
        'coolant_level',
        'air_filter',
        'engine_running',
        'rpm',
      ];

      for (String inspectionType in inspectionTypes) {
        try {
          final inspectionData = _engineInspections[inspectionType] ?? {};
          await _supabaseService.saveEngineInspection(
            siteId: widget.site.id,
            inspectionType: inspectionType,
            value: inspectionData['value'] ?? '',
            comments: inspectionData['comments'] ?? '',
          );
        } catch (e) {
          print('Error saving $inspectionType inspection: $e');
          failedInspections.add(inspectionType);
        }
      }

      // Unfocus all text fields
      FocusScope.of(context).unfocus();

      // Reload engine inspections after saving
      await _loadEngineInspections();

      if (mounted) {
        if (failedInspections.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('All engine inspections saved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Some inspections failed to save: ${failedInspections.join(', ')}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error saving engine inspections: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving engine inspections: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAllInspections = false;
        });
      }
    }
  }

  Future<void> _loadAssignedFreelancers() async {
    try {
      final supabase = Supabase.instance.client;

      // Get the area ID for this site
      final siteResponse =
          await supabase
              .from('sites')
              .select('area_id')
              .eq('id', widget.site.id)
              .single();

      if (siteResponse != null) {
        final areaId = siteResponse['area_id'];

        // Get area assignments for both sections
        final areaAssignments = await supabase
            .from('area_assignments')
            .select('assigned_to_id, assignment_type')
            .eq('area_id', areaId)
            .eq('status', 'active');

        // Process assignments
        for (var assignment in areaAssignments) {
          final freelancerId = assignment['assigned_to_id'];
          final assignmentType = assignment['assignment_type'];

          // Get freelancer details
          final freelancerResponse =
              await supabase
                  .from('freelancers')
                  .select()
                  .eq('id', freelancerId)
                  .single();

          if (freelancerResponse != null) {
            setState(() {
              if (assignmentType == 'pumps_floor') {
                _pumpsFloorFreelancer = freelancerResponse;
              } else if (assignmentType == 'building_fire') {
                _buildingFireFreelancer = freelancerResponse;
              }
            });
          }
        }
      }
    } catch (e) {
      print('Error loading assigned freelancers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.site.siteName),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => QRScannerScreen(site: widget.site),
                ),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSiteInfo(),
                    const SizedBox(height: 24),
                    // Pumps & Floor Management Section
                    if (_isContractor ||
                        widget.assignedSections.contains('pumps_floor'))
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Pumps & Floor Management',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildPumpsList(),
                                  const SizedBox(height: 24),
                                  // Operational Test Section
                                  _buildOperationalTestSection(),
                                  const SizedBox(height: 24),
                                  // Engine Inspection Section
                                  _buildEngineInspectionSection(),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => _showAddFloorDialog(),
                                    icon: const Icon(Icons.add),
                                    label: Text(
                                      'Add Floor',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      labelText: 'Select Floor for Pumps',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    value: _selectedPumpFloor?.id,
                                    items:
                                        _floors.map((floor) {
                                          return DropdownMenuItem(
                                            value: floor.id,
                                            child: Text(floor.floorType),
                                          );
                                        }).toList(),
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedPumpFloor = _floors.firstWhere(
                                          (floor) => floor.id == value,
                                          orElse: () => _floors.first,
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  if (_selectedPumpFloor != null)
                                    FloorComponents(
                                      floor: _selectedPumpFloor!,
                                      onFloorUpdated: _loadFloors,
                                      supabaseService: _supabaseService,
                                    )
                                  else
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'Please select a floor to manage pumps & accessories',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Building Accessories & Fire Alarm Management Section
                    if (_isContractor ||
                        widget.assignedSections.contains('building_fire'))
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: true,
                          collapsedIconColor: Colors.red.shade800,
                          iconColor: Colors.red.shade800,
                          title: Row(
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                color: Colors.red.shade800,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Fire Alram Checks & Fire Alarm Management',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BuildingAccessoriesWidget(
                                    siteId: widget.site.id,
                                    supabaseService: _supabaseService,
                                    onUpdated: () {
                                      // Refresh the UI if needed
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.add_circle_outline,
                                        color: Colors.red.shade800,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Add New Fire Alarm Check',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  AddBuildingAccessories(
                                    siteId: widget.site.id,
                                    supabaseService: _supabaseService,
                                    onUpdated: () {
                                      // Refresh the UI if needed
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.warning_rounded,
                                        color: Colors.red.shade800,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Fire Alarm Management',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade800,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Transform.scale(
                                    scale: 0.95,
                                    child: FireAlarmFloorManagement(
                                      siteId: widget.site.id,
                                      supabaseService: _supabaseService,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Colors.blue.shade50, Colors.white],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Site Description',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 5,
                                decoration: InputDecoration(
                                  hintText:
                                      'Enter site description and details about devices...',
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.all(16),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed:
                                      _isSavingDescription
                                          ? null
                                          : _saveSiteDescription,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child:
                                      _isSavingDescription
                                          ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                          : Text(
                                            'Save Description',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildReportButtons(),
                  ],
                ),
              ),
    );
  }

  Widget _buildSiteInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Site Information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Site Name', widget.site.siteName, Icons.business),
            _buildInfoRow(
              'Location',
              widget.site.siteLocation,
              Icons.location_on,
            ),
            _buildInfoRow('Owner', widget.site.siteOwner, Icons.person),
            _buildInfoRow(
              'Owner Email',
              widget.site.siteOwnerEmail,
              Icons.email,
              isEmail: true,
            ),
            _buildInfoRow(
              'Owner Phone',
              widget.site.siteOwnerPhone,
              Icons.phone,
              isPhone: true,
            ),
            _buildInfoRow(
              'Manager',
              widget.site.siteManager,
              Icons.manage_accounts,
            ),
            _buildInfoRow(
              'Manager Email',
              widget.site.siteManagerEmail,
              Icons.email,
              isEmail: true,
            ),
            _buildInfoRow(
              'Manager Phone',
              widget.site.siteManagerPhone,
              Icons.phone,
              isPhone: true,
            ),
            _buildInfoRow(
              'Contractor Email',
              widget.site.contractorEmail,
              Icons.email,
              isEmail: true,
            ),
            const Divider(height: 30),
            Text(
              'Assigned Freelancers',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),

            // Pumps & Floor Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pumps & Floor Section',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_pumpsFloorFreelancer != null) ...[
                      _buildInfoRow(
                        'Name',
                        _pumpsFloorFreelancer!['name'] ?? '',
                        Icons.person_outline,
                      ),
                      _buildInfoRow(
                        'Email',
                        _pumpsFloorFreelancer!['email'] ?? '',
                        Icons.email,
                        isEmail: true,
                      ),
                      _buildInfoRow(
                        'Phone',
                        _pumpsFloorFreelancer!['phone'] ?? '',
                        Icons.phone,
                        isPhone: true,
                      ),
                      _buildInfoRow(
                        'Address',
                        _pumpsFloorFreelancer!['address'] ?? '',
                        Icons.location_on,
                      ),
                    ] else
                      Text(
                        'No freelancer assigned',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Building & Fire Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Building & Fire Section',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_buildingFireFreelancer != null) ...[
                      _buildInfoRow(
                        'Name',
                        _buildingFireFreelancer!['name'] ?? '',
                        Icons.person_outline,
                      ),
                      _buildInfoRow(
                        'Email',
                        _buildingFireFreelancer!['email'] ?? '',
                        Icons.email,
                        isEmail: true,
                      ),
                      _buildInfoRow(
                        'Phone',
                        _buildingFireFreelancer!['phone'] ?? '',
                        Icons.phone,
                        isPhone: true,
                      ),
                      _buildInfoRow(
                        'Address',
                        _buildingFireFreelancer!['address'] ?? '',
                        Icons.location_on,
                      ),
                    ] else
                      Text(
                        'No freelancer assigned',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    bool isEmail = false,
    bool isPhone = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blue.shade700, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if ((isEmail || isPhone) && value.isNotEmpty)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () async {
                    String urlScheme = isEmail ? 'mailto:' : 'tel:';
                    final Uri uri = Uri.parse('$urlScheme$value');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(
                        uri,
                        mode:
                            isEmail
                                ? LaunchMode.externalApplication
                                : LaunchMode.platformDefault,
                      );
                    } else {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Could not launch ${isEmail ? "email" : "phone"} app',
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      isEmail ? Icons.email : Icons.phone,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _pumps.length,
      itemBuilder: (context, index) {
        final pump = _pumps[index];
        final isLastViewed = pump.id == _lastViewedPumpId;

        // Calculate operational status
        final isOperating =
            _pumpValveStatuses['${pump.id}_suction'] == 'Open' &&
            _pumpValveStatuses['${pump.id}_delivery'] == 'Open' &&
            _pumpValveStatuses['${pump.id}_gauge'] == 'Working';

        return ExpansionTile(
          title: Text(
            pump.name,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isOperating ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
          subtitle: Text(
            'Status: ${_pumpStatuses[pump.id] ?? pump.status}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          leading: Icon(
            isOperating ? Icons.check_circle : Icons.error,
            color: isOperating ? Colors.green : Colors.red,
          ),
          trailing: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient:
                      isLastViewed
                          ? LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Colors.blue.shade50, Colors.white],
                          )
                          : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with pump name and status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.settings,
                            color:
                                isLastViewed
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade600,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pump.name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isLastViewed
                                            ? Colors.blue.shade700
                                            : Colors.black,
                                    fontSize: 18,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                // Status
                                _buildEditablePumpDetailBox(
                                  pump.id,
                                  'Status',
                                  pump.status,
                                  Icons.power_settings_new,
                                  'status',
                                ),
                                const SizedBox(height: 12),
                                // Mode
                                _buildEditablePumpDetailBox(
                                  pump.id,
                                  'Mode',
                                  pump.mode,
                                  Icons.mode,
                                  'mode',
                                ),
                                const SizedBox(height: 12),
                                // Operational Status
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isOperating
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          isOperating
                                              ? Colors.green.shade200
                                              : Colors.red.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isOperating
                                            ? Icons.check_circle
                                            : Icons.error,
                                        size: 16,
                                        color:
                                            isOperating
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOperating
                                            ? 'Operating'
                                            : 'Non-Operating',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color:
                                              isOperating
                                                  ? Colors.green.shade700
                                                  : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Pump Specifications
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pump Specifications',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Column(
                              children: [
                                _buildEditablePumpDetailBox(
                                  pump.id,
                                  'Capacity',
                                  pump.capacity.toString(),
                                  Icons.speed,
                                  'numeric',
                                ),
                                const SizedBox(height: 12),
                                _buildEditablePumpDetailBox(
                                  pump.id,
                                  'Head',
                                  pump.head.toString(),
                                  Icons.height,
                                  'numeric',
                                ),
                                const SizedBox(height: 12),
                                _buildEditablePumpDetailBox(
                                  pump.id,
                                  'Rated Power',
                                  pump.ratedPower.toString(),
                                  Icons.power,
                                  'numeric',
                                ),
                                const SizedBox(height: 12),
                                _buildEditablePumpDetailBox(
                                  pump.id,
                                  'Start Pressure',
                                  pump.startPressure.toString(),
                                  Icons.speed,
                                  'numeric',
                                ),
                                const SizedBox(height: 12),
                                _buildEditablePumpDetailBox(
                                  pump.id,
                                  'Stop Pressure',
                                  pump.stopPressure.toString(),
                                  Icons.speed,
                                  'numeric',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Valve status
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Valve Status',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Column(
                              children: [
                                _buildEditablePumpDetailBox(
                                  pump.id,
                                  'Suction',
                                  pump.suctionValve,
                                  Icons.arrow_downward,
                                  'valve',
                                ),
                                const SizedBox(height: 12),
                                _buildEditablePumpDetailBox(
                                  pump.id,
                                  'Delivery',
                                  pump.deliveryValve,
                                  Icons.arrow_upward,
                                  'valve',
                                ),
                                const SizedBox(height: 12),
                                _buildEditablePumpDetailBox(
                                  pump.id,
                                  'Pressure Gauge',
                                  pump.pressureGauge,
                                  Icons.speed,
                                  'valve',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Comments section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.shade200,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.comment,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Comments',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: Icon(
                                    Icons.qr_code_scanner,
                                    color: Colors.blue.shade700,
                                  ),
                                  onPressed:
                                      () => _startBarcodeScanner(pump.id),
                                  tooltip: 'Scan Barcode',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _pumpControllers[pump.id],
                              maxLines: 3,
                              decoration: InputDecoration(
                                hintText: 'Please enter a comment',
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade500,
                                  fontStyle: FontStyle.italic,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isSavingPump[pump.id] == true
                                  ? null
                                  : () => _savePumpDetails(pump.id),
                          icon:
                              _isSavingPump[pump.id] == true
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Icon(Icons.save),
                          label: Text(
                            _isSavingPump[pump.id] == true
                                ? 'Saving...'
                                : 'Save Changes',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
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
                      const SizedBox(height: 12),
                      // Delete button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _deletePump(pump),
                          icon: const Icon(Icons.delete),
                          label: Text(
                            'Delete Pump',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
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
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePump(Pump pump) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Delete Pump',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Are you sure you want to delete ${pump.name}? This action cannot be undone.',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Delete', style: GoogleFonts.poppins()),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final supabase = Supabase.instance.client;

        // Delete the pump from the pumps table
        await supabase.from('pumps').delete().eq('id', pump.id);

        setState(() {
          _pumps.removeWhere((p) => p.id == pump.id);
          // Clean up local state
          _pumpControllers.remove(pump.id);
          _pumpStatuses.remove(pump.id);
          _pumpModes.remove(pump.id);
          _pumpValveStatuses.remove('${pump.id}_suction');
          _pumpValveStatuses.remove('${pump.id}_delivery');
          _pumpValveStatuses.remove('${pump.id}_gauge');
          _pumpNumericValues.remove('${pump.id}_capacity');
          _pumpNumericValues.remove('${pump.id}_head');
          _pumpNumericValues.remove('${pump.id}_ratedpower');
          _pumpNumericValues.remove('${pump.id}_startpressure');
          _pumpNumericValues.remove('${pump.id}_stop_pressure');
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${pump.name} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error deleting pump: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting pump: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildEditablePumpDetailBox(
    String pumpId,
    String label,
    String value,
    IconData icon,
    String fieldType,
  ) {
    // Get the correct value based on field type and label
    bool getToggleValue() {
      if (fieldType == 'valve') {
        if (label.toLowerCase() == 'pressure gauge') {
          return _pumpValveStatuses['${pumpId}_gauge'] == 'Working';
        }
        return _pumpValveStatuses['${pumpId}_${label.toLowerCase()}'] == 'Open';
      } else if (fieldType == 'status') {
        return _pumpStatuses[pumpId] == 'Working';
      } else if (fieldType == 'mode') {
        return _pumpModes[pumpId] == 'Auto';
      }
      return false;
    }

    // Get the correct items based on field type and label
    List<String> getDropdownItems() {
      if (fieldType == 'valve') {
        if (label.toLowerCase() == 'pressure gauge') {
          return ['Working', 'Not Working'];
        }
        return ['Open', 'Closed'];
      } else if (fieldType == 'status') {
        return ['Working', 'Not Working'];
      } else if (fieldType == 'mode') {
        return ['Auto', 'Manual'];
      }
      return [];
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (fieldType == 'status' ||
              fieldType == 'mode' ||
              fieldType == 'valve')
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  getToggleValue()
                      ? (fieldType == 'status'
                          ? 'Working'
                          : fieldType == 'mode'
                          ? 'Auto'
                          : label.toLowerCase() == 'pressure gauge'
                          ? 'Working'
                          : 'Open')
                      : (fieldType == 'status'
                          ? 'Not Working'
                          : fieldType == 'mode'
                          ? 'Manual'
                          : label.toLowerCase() == 'pressure gauge'
                          ? 'Not Working'
                          : 'Closed'),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: getToggleValue(),
                  onChanged: (bool newValue) async {
                    setState(() {
                      if (fieldType == 'valve') {
                        if (label.toLowerCase() == 'pressure gauge') {
                          _pumpValveStatuses['${pumpId}_gauge'] =
                              newValue ? 'Working' : 'Not Working';
                        } else {
                          _pumpValveStatuses['${pumpId}_${label.toLowerCase()}'] =
                              newValue ? 'Open' : 'Closed';
                        }
                      } else if (fieldType == 'status') {
                        _pumpStatuses[pumpId] =
                            newValue ? 'Working' : 'Not Working';
                      } else {
                        _pumpModes[pumpId] = newValue ? 'Auto' : 'Manual';
                      }
                    });

                    // Save changes immediately
                    try {
                      final pump = _pumps.firstWhere((p) => p.id == pumpId);
                      final comments = _pumpControllers[pumpId]?.text ?? '';
                      final status = _pumpStatuses[pumpId] ?? pump.status;
                      final mode = _pumpModes[pumpId] ?? pump.mode;
                      final suctionValve =
                          _pumpValveStatuses['${pumpId}_suction'] ??
                          pump.suctionValve;
                      final deliveryValve =
                          _pumpValveStatuses['${pumpId}_delivery'] ??
                          pump.deliveryValve;
                      final pressureGauge =
                          _pumpValveStatuses['${pumpId}_gauge'] ??
                          pump.pressureGauge;
                      final capacity =
                          _pumpNumericValues['${pumpId}_capacity']?.toInt() ??
                          pump.capacity;
                      final head =
                          _pumpNumericValues['${pumpId}_head']?.toInt() ??
                          pump.head;
                      final ratedPower =
                          _pumpNumericValues['${pumpId}_ratedpower']?.toInt() ??
                          pump.ratedPower;
                      final startPressure =
                          _pumpNumericValues['${pumpId}_startpressure'] != null
                              ? double.tryParse(
                                    _pumpNumericValues['${pumpId}_startpressure']
                                        .toString(),
                                  ) ??
                                  pump.startPressure
                              : pump.startPressure;
                      final stopPressure =
                          _pumpNumericValues['${pumpId}_stop_pressure']
                              ?.toString() ??
                          pump.stopPressure;

                      // Calculate operational status
                      final isOperating =
                          suctionValve == 'Open' &&
                          deliveryValve == 'Open' &&
                          pressureGauge == 'Working';
                      final operationalStatus =
                          isOperating ? 'Operating' : 'Non-Operating';

                      // Update pump in database
                      final supabase = Supabase.instance.client;
                      final response =
                          await supabase
                              .from('pumps')
                              .update({
                                'status': status,
                                'mode': mode,
                                'suction_valve': suctionValve,
                                'delivery_valve': deliveryValve,
                                'pressure_gauge': pressureGauge,
                                'comments': comments,
                                'capacity': capacity,
                                'head': head,
                                'rated_power': ratedPower,
                                'start_pressure': startPressure,
                                'stop_pressure': stopPressure,
                                'operational_status': operationalStatus,
                                'updated_at':
                                    DateTime.now().toUtc().toIso8601String(),
                              })
                              .eq('id', pumpId)
                              .select()
                              .single();

                      if (response != null) {
                        // Update local state with response
                        setState(() {
                          final index = _pumps.indexWhere(
                            (p) => p.id == pumpId,
                          );
                          if (index != -1) {
                            _pumps[index] = Pump.fromJson(response);
                          }
                        });
                      }
                    } catch (e) {
                      print('Error saving toggle state: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error saving changes: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  activeColor: Colors.blue.shade700,
                  activeTrackColor: Colors.blue.shade200,
                ),
              ],
            )
          else if (fieldType == 'numeric')
            TextFormField(
              initialValue:
                  label.toLowerCase() == 'stop pressure'
                      ? (_pumpNumericValues['${pumpId}_stop_pressure']
                              ?.toString() ??
                          value ??
                          '')
                      : (_pumpNumericValues['${pumpId}_${label.toLowerCase().replaceAll(' ', '')}']
                              ?.toString() ??
                          '0'),
              keyboardType:
                  label.toLowerCase() == 'stop pressure'
                      ? TextInputType.text
                      : TextInputType.number,
              onChanged: (newValue) {
                if (label.toLowerCase() == 'stop pressure') {
                  setState(() {
                    _pumpNumericValues['${pumpId}_stop_pressure'] = newValue;
                  });
                } else {
                  final numericValue = num.tryParse(newValue) ?? 0;
                  setState(() {
                    _pumpNumericValues['${pumpId}_${label.toLowerCase().replaceAll(' ', '')}'] =
                        numericValue;
                  });
                }
              },
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                suffixText:
                    label.toLowerCase().contains('pressure')
                        ? 'kg/cm²'
                        : label.toLowerCase().contains('capacity')
                        ? 'LPM'
                        : label.toLowerCase().contains('head')
                        ? 'm'
                        : label.toLowerCase().contains('power')
                        ? 'HP'
                        : '',
              ),
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _savePumpDetails(String pumpId) async {
    if (_isSavingPump[pumpId] == true) return;

    setState(() {
      _isSavingPump[pumpId] = true;
    });

    try {
      final pump = _pumps.firstWhere((p) => p.id == pumpId);
      final comments = _pumpControllers[pumpId]?.text ?? '';
      final status = _pumpStatuses[pumpId] ?? pump.status;
      final mode = _pumpModes[pumpId] ?? pump.mode;
      final suctionValve =
          _pumpValveStatuses['${pumpId}_suction'] ?? pump.suctionValve;
      final deliveryValve =
          _pumpValveStatuses['${pumpId}_delivery'] ?? pump.deliveryValve;
      final pressureGauge =
          _pumpValveStatuses['${pumpId}_gauge'] ?? pump.pressureGauge;
      final capacity =
          _pumpNumericValues['${pumpId}_capacity']?.toInt() ?? pump.capacity;
      final head = _pumpNumericValues['${pumpId}_head']?.toInt() ?? pump.head;
      final ratedPower =
          _pumpNumericValues['${pumpId}_ratedpower']?.toInt() ??
          pump.ratedPower;
      final startPressure =
          _pumpNumericValues['${pumpId}_startpressure'] != null
              ? double.tryParse(
                    _pumpNumericValues['${pumpId}_startpressure'].toString(),
                  ) ??
                  pump.startPressure
              : pump.startPressure;
      final stopPressure =
          _pumpNumericValues['${pumpId}_stop_pressure']?.toString() ??
          pump.stopPressure;

      // Calculate operational status based on valve and gauge status
      final isOperating =
          suctionValve == 'Open' &&
          deliveryValve == 'Open' &&
          pressureGauge == 'Working';
      final operationalStatus = isOperating ? 'Operating' : 'Non-Operating';

      // Update pump in database using Supabase
      final supabase = Supabase.instance.client;
      final response =
          await supabase
              .from('pumps')
              .update({
                'status': status,
                'mode': mode,
                'suction_valve': suctionValve,
                'delivery_valve': deliveryValve,
                'pressure_gauge': pressureGauge,
                'comments': comments,
                'capacity': capacity,
                'head': head,
                'rated_power': ratedPower,
                'start_pressure': startPressure,
                'stop_pressure': stopPressure,
                'operational_status': operationalStatus,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', pumpId)
              .select()
              .single();

      if (response == null) {
        throw Exception('Failed to update pump details');
      }

      // Update local state with the response data
      setState(() {
        final index = _pumps.indexWhere((p) => p.id == pumpId);
        if (index != -1) {
          _pumps[index] = Pump.fromJson(response);
          // Update all the local state maps
          _pumpControllers[pumpId]?.text = response['comments'] ?? '';
          _pumpStatuses[pumpId] = response['status'];
          _pumpModes[pumpId] = response['mode'];
          _pumpValveStatuses['${pumpId}_suction'] = response['suction_valve'];
          _pumpValveStatuses['${pumpId}_delivery'] = response['delivery_valve'];
          _pumpValveStatuses['${pumpId}_gauge'] = response['pressure_gauge'];
          _pumpNumericValues['${pumpId}_capacity'] = response['capacity'];
          _pumpNumericValues['${pumpId}_head'] = response['head'];
          _pumpNumericValues['${pumpId}_ratedpower'] = response['rated_power'];
          _pumpNumericValues['${pumpId}_startpressure'] =
              response['start_pressure'];
          _pumpNumericValues['${pumpId}_stop_pressure'] =
              response['stop_pressure'];
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pump details saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving pump details: $e'); // For debugging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving pump details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingPump[pumpId] = false;
        });
      }
    }
  }

  Widget _buildReportButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.description),
          label: Text(
            _isGeneratingReport
                ? 'Generating Report...'
                : 'Generate Society Report',
            style: GoogleFonts.poppins(),
          ),
          onPressed: _isGeneratingReport ? null : _generateSocietyReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: Text('Download Report', style: GoogleFonts.poppins()),
          onPressed: _reportUrl != null ? _downloadReport : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Future<File> _generateReportFile() async {
    final reportGenerator = SiteReportGenerator(
      site: widget.site,
      pumps: _pumps,
      floors: _floors,
      siteDescription: _siteDescription,
      supabaseService: _supabaseService,
    );
    return await reportGenerator.generateReport();
  }

  Future<void> _generateSocietyReport() async {
    try {
      setState(() {
        _isGeneratingReport = true;
      });

      // Generate report
      final reportFile = await _generateReportFile();

      // Upload to Supabase
      final reportUrl = await _supabaseService.uploadSocietyReport(
        widget.site.id,
        reportFile,
      );

      setState(() {
        _reportUrl = reportUrl;
        _isGeneratingReport = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report generated successfully')),
      );
    } catch (error) {
      setState(() {
        _isGeneratingReport = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: ${error.toString()}')),
      );
    }
  }

  Future<void> _downloadReport() async {
    if (_reportUrl == null) return;

    try {
      final success = await _downloadAndSaveReport(_reportUrl!);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report downloaded successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download report')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading report: ${error.toString()}'),
        ),
      );
    }
  }

  Future<bool> _downloadAndSaveReport(String url) async {
    try {
      // Request storage permission
      if (await Permission.storage.request().isGranted) {
        // Get the download directory
        final directory = await getExternalStorageDirectory();
        if (directory == null) throw Exception('Could not access storage');

        // Download the file
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('Failed to download file');
        }

        // Generate a filename with timestamp
        final fileName =
            'site_report_${widget.site.siteName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final filePath = '${directory.path}/$fileName';

        // Save the file
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        // Open the file after download
        await OpenFile.open(filePath);

        return true;
      } else {
        throw Exception('Storage permission denied');
      }
    } catch (e) {
      print('Error downloading file: $e');
      return false;
    }
  }

  void _showAddFloorDialog() {
    final floorTypeController = TextEditingController();
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Floor', style: GoogleFonts.poppins()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: floorTypeController,
                  decoration: InputDecoration(
                    hintText: 'Enter floor type (e.g., Parking, Floor 1)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: remarksController,
                  decoration: InputDecoration(
                    hintText: 'Enter remarks (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (floorTypeController.text.trim().isNotEmpty) {
                    await _supabaseService.createFloor(
                      widget.site.id,
                      floorTypeController.text.trim(),
                      remarks:
                          remarksController.text.trim().isEmpty
                              ? null
                              : remarksController.text.trim(),
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      _loadFloors();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Floor added successfully'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _showEditFloorDialog(BuildContext context, Floor floor) async {
    final floorTypeController = TextEditingController(text: floor.floorType);
    final remarksController = TextEditingController(text: floor.remarks ?? '');

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Floor', style: GoogleFonts.poppins()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: floorTypeController,
                  decoration: InputDecoration(
                    hintText: 'Enter floor type (e.g., Parking, Floor 1)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: remarksController,
                  decoration: InputDecoration(
                    hintText: 'Enter remarks (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (floorTypeController.text.trim().isNotEmpty) {
                    await _supabaseService.updateFloor(
                      floor.id,
                      floorTypeController.text.trim(),
                      remarks:
                          remarksController.text.trim().isEmpty
                              ? null
                              : remarksController.text.trim(),
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      _loadFloors();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Floor updated successfully'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteFloor(BuildContext context, Floor floor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Floor'),
            content: Text(
              'Are you sure you want to delete ${floor.floorType}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await _supabaseService.deleteFloor(floor.id);
        if (mounted) {
          _loadFloors();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Floor deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting floor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildEngineInspectionSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Engine Inspection',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildInspectionFieldWithoutSave(
              'Engine Oil',
              _engineInspections['engine_oil']?['value'] ?? '',
              _engineInspections['engine_oil']?['comments'] ?? '',
              (value) {
                setState(() {
                  _engineInspections['engine_oil'] = {
                    ..._engineInspections['engine_oil'] ?? {},
                    'value': value,
                  };
                });
              },
              (comments) {
                setState(() {
                  _engineInspections['engine_oil'] = {
                    ..._engineInspections['engine_oil'] ?? {},
                    'comments': comments,
                  };
                });
              },
            ),
            const SizedBox(height: 12),
            _buildInspectionFieldWithoutSave(
              'Fuel Level',
              _engineInspections['fuel_level']?['value'] ?? '',
              _engineInspections['fuel_level']?['comments'] ?? '',
              (value) {
                setState(() {
                  _engineInspections['fuel_level'] = {
                    ..._engineInspections['fuel_level'] ?? {},
                    'value': value,
                  };
                });
              },
              (comments) {
                setState(() {
                  _engineInspections['fuel_level'] = {
                    ..._engineInspections['fuel_level'] ?? {},
                    'comments': comments,
                  };
                });
              },
            ),
            const SizedBox(height: 12),
            _buildInspectionFieldWithoutSave(
              'Battery Conditions & Voltage',
              _engineInspections['battery_condition']?['value'] ?? '',
              _engineInspections['battery_condition']?['comments'] ?? '',
              (value) {
                setState(() {
                  _engineInspections['battery_condition'] = {
                    ..._engineInspections['battery_condition'] ?? {},
                    'value': value,
                  };
                });
              },
              (comments) {
                setState(() {
                  _engineInspections['battery_condition'] = {
                    ..._engineInspections['battery_condition'] ?? {},
                    'comments': comments,
                  };
                });
              },
            ),
            const SizedBox(height: 12),
            _buildInspectionFieldWithoutSave(
              'Coolant Level & Radiant Condition',
              _engineInspections['coolant_level']?['value'] ?? '',
              _engineInspections['coolant_level']?['comments'] ?? '',
              (value) {
                setState(() {
                  _engineInspections['coolant_level'] = {
                    ..._engineInspections['coolant_level'] ?? {},
                    'value': value,
                  };
                });
              },
              (comments) {
                setState(() {
                  _engineInspections['coolant_level'] = {
                    ..._engineInspections['coolant_level'] ?? {},
                    'comments': comments,
                  };
                });
              },
            ),
            const SizedBox(height: 12),
            _buildInspectionFieldWithoutSave(
              'Air Filter Condition',
              _engineInspections['air_filter']?['value'] ?? '',
              _engineInspections['air_filter']?['comments'] ?? '',
              (value) {
                setState(() {
                  _engineInspections['air_filter'] = {
                    ..._engineInspections['air_filter'] ?? {},
                    'value': value,
                  };
                });
              },
              (comments) {
                setState(() {
                  _engineInspections['air_filter'] = {
                    ..._engineInspections['air_filter'] ?? {},
                    'comments': comments,
                  };
                });
              },
            ),
            const SizedBox(height: 12),
            _buildInspectionFieldWithoutSave(
              'Engine Running Smoothly',
              _engineInspections['engine_running']?['value'] ?? '',
              _engineInspections['engine_running']?['comments'] ?? '',
              (value) {
                setState(() {
                  _engineInspections['engine_running'] = {
                    ..._engineInspections['engine_running'] ?? {},
                    'value': value,
                  };
                });
              },
              (comments) {
                setState(() {
                  _engineInspections['engine_running'] = {
                    ..._engineInspections['engine_running'] ?? {},
                    'comments': comments,
                  };
                });
              },
            ),
            const SizedBox(height: 12),
            _buildInspectionFieldWithoutSave(
              'RPM During Operation',
              _engineInspections['rpm']?['value'] ?? '',
              _engineInspections['rpm']?['comments'] ?? '',
              (value) {
                setState(() {
                  _engineInspections['rpm'] = {
                    ..._engineInspections['rpm'] ?? {},
                    'value': value,
                  };
                });
              },
              (comments) {
                setState(() {
                  _engineInspections['rpm'] = {
                    ..._engineInspections['rpm'] ?? {},
                    'comments': comments,
                  };
                });
              },
            ),
            const SizedBox(height: 20),
            // Single save button for all engine inspections
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _isSavingAllInspections ? null : _saveAllEngineInspections,
                icon:
                    _isSavingAllInspections
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Icon(Icons.save),
                label: Text(
                  _isSavingAllInspections
                      ? 'Saving...'
                      : 'Save All Engine Inspections',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
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
      ),
    );
  }

  Widget _buildInspectionField(
    String title,
    String value,
    String comments,
    Function(String) onValueChanged,
    Function(String) onCommentsChanged,
    Function() onSave,
  ) {
    // Initialize controllers if they don't exist
    if (!_inspectionValueControllers.containsKey(title)) {
      _inspectionValueControllers[title] = TextEditingController(text: value);
      _inspectionCommentsControllers[title] = TextEditingController(
        text: comments,
      );
    } else {
      // Update controller values if they exist
      _inspectionValueControllers[title]?.text = value;
      _inspectionCommentsControllers[title]?.text = comments;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inspectionValueControllers[title],
                  decoration: InputDecoration(
                    labelText: 'Value',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: onValueChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _inspectionCommentsControllers[title],
                  decoration: InputDecoration(
                    labelText: 'Comments',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: onCommentsChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onSave,
                icon: const Icon(Icons.save),
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInspectionFieldWithoutSave(
    String title,
    String value,
    String comments,
    Function(String) onValueChanged,
    Function(String) onCommentsChanged,
  ) {
    // Initialize controllers if they don't exist
    if (!_inspectionValueControllers.containsKey(title)) {
      _inspectionValueControllers[title] = TextEditingController(text: value);
      _inspectionCommentsControllers[title] = TextEditingController(
        text: comments,
      );
    } else {
      // Update controller values if they exist
      _inspectionValueControllers[title]?.text = value;
      _inspectionCommentsControllers[title]?.text = comments;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inspectionValueControllers[title],
                  decoration: InputDecoration(
                    labelText: 'Value',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: onValueChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _inspectionCommentsControllers[title],
                  decoration: InputDecoration(
                    labelText: 'Comments',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onChanged: onCommentsChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPressureTestSection(String title, String testType) {
    final testData =
        _operationalTests[testType] ??
        {'standard_value': '', 'observed_value': '', 'comments': ''};

    // Initialize controllers if they don't exist
    if (!_standardValueControllers.containsKey(testType)) {
      _standardValueControllers[testType] = TextEditingController(
        text: testData['standard_value']?.toString() ?? '',
      );
      _observedValueControllers[testType] = TextEditingController(
        text: testData['observed_value']?.toString() ?? '',
      );
      _testCommentsControllers[testType] = TextEditingController(
        text: testData['comments']?.toString() ?? '',
      );
    } else {
      // Update controller values if they exist
      _standardValueControllers[testType]?.text =
          testData['standard_value']?.toString() ?? '';
      _observedValueControllers[testType]?.text =
          testData['observed_value']?.toString() ?? '';
      _testCommentsControllers[testType]?.text =
          testData['comments']?.toString() ?? '';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _standardValueControllers[testType],
                decoration: InputDecoration(
                  labelText: 'Standard Value (kg/cm²)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _operationalTests[testType] = {
                      ...testData,
                      'standard_value': value,
                    };
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _observedValueControllers[testType],
                decoration: InputDecoration(
                  labelText: 'Observed Value (kg/cm²)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  setState(() {
                    _operationalTests[testType] = {
                      ...testData,
                      'observed_value': value,
                    };
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _testCommentsControllers[testType],
          decoration: InputDecoration(
            labelText: 'Comments',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 2,
          onChanged: (value) {
            setState(() {
              _operationalTests[testType] = {...testData, 'comments': value};
            });
          },
        ),
      ],
    );
  }

  Widget _buildOperationalTestSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operational Test',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16),
            // Hydrant Line Pressure Test
            _buildPressureTestSection('Hydrant Line Pressure Test', 'hydrant'),
            const SizedBox(height: 24),
            // Sprinkler Line Pressure Test
            _buildPressureTestSection(
              'Sprinkler Line Pressure Test',
              'sprinkler',
            ),
            const SizedBox(height: 20),
            // Single save button for all operational tests
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingAllTests ? null : _saveAllOperationalTests,
                icon:
                    _isSavingAllTests
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Icon(Icons.save),
                label: Text(
                  _isSavingAllTests
                      ? 'Saving...'
                      : 'Save All Operational Tests',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
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
      ),
    );
  }

  Future<void> _startBarcodeScanner(String pumpId) async {
    _scannerController = MobileScannerController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Scan Barcode',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: SizedBox(
              height: 300,
              child: MobileScanner(
                controller: _scannerController!,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      setState(() {
                        _pumpControllers[pumpId]?.text = barcode.rawValue!;
                      });
                      Navigator.pop(context);
                      break;
                    }
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _scannerController?.dispose();
                  Navigator.pop(context);
                },
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
            ],
          ),
    );
  }

  Widget _buildAssignedFreelancersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 30),
        Text(
          'Assigned Freelancers',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 16),

        // Pumps & Floor Section
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pumps & Floor Section',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                if (_pumpsFloorFreelancer != null) ...[
                  _buildInfoRow(
                    'Name',
                    _pumpsFloorFreelancer!['name'] ?? '',
                    Icons.person_outline,
                  ),
                  _buildInfoRow(
                    'Email',
                    _pumpsFloorFreelancer!['email'] ?? '',
                    Icons.email,
                    isEmail: true,
                  ),
                  _buildInfoRow(
                    'Phone',
                    _pumpsFloorFreelancer!['phone'] ?? '',
                    Icons.phone,
                    isPhone: true,
                  ),
                  _buildInfoRow(
                    'Address',
                    _pumpsFloorFreelancer!['address'] ?? '',
                    Icons.location_on,
                  ),
                ] else
                  Text(
                    'No freelancer assigned',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Building & Fire Section
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Building & Fire Section',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                if (_buildingFireFreelancer != null) ...[
                  _buildInfoRow(
                    'Name',
                    _buildingFireFreelancer!['name'] ?? '',
                    Icons.person_outline,
                  ),
                  _buildInfoRow(
                    'Email',
                    _buildingFireFreelancer!['email'] ?? '',
                    Icons.email,
                    isEmail: true,
                  ),
                  _buildInfoRow(
                    'Phone',
                    _buildingFireFreelancer!['phone'] ?? '',
                    Icons.phone,
                    isPhone: true,
                  ),
                  _buildInfoRow(
                    'Address',
                    _buildingFireFreelancer!['address'] ?? '',
                    Icons.location_on,
                  ),
                ] else
                  Text(
                    'No freelancer assigned',
                    style: GoogleFonts.poppins(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
