import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import '../services/location_helper.dart';
import '../services/work_report_service.dart';
import '../models/work_report.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AssignedTasksScreen extends StatefulWidget {
  const AssignedTasksScreen({Key? key}) : super(key: key);

  @override
  State<AssignedTasksScreen> createState() => _AssignedTasksScreenState();
}

class _AssignedTasksScreenState extends State<AssignedTasksScreen> {
  final _supabase = Supabase.instance.client;
  final _workReportService = WorkReportService();
  final _imagePicker = ImagePicker();
  MobileScannerController? _scannerController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tasks = [];
  String? _userType;
  String? _userId;

  // Work report form controllers
  final _equipmentNameController = TextEditingController();
  final _workDescriptionController = TextEditingController();
  final _replacedPartsController = TextEditingController();
  DateTime? _repairDate;
  DateTime? _nextDueDate;
  File? _workPhoto;
  File? _finishedPhoto;
  File? _geotaggedPhoto;
  Position? _currentPosition;
  String? _currentAddress;
  String? _qrCodeData;
  bool _isSubmittingReport = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if user is a freelancer
      final freelancerData =
          await _supabase
              .from('freelancers')
              .select('id')
              .eq('email', user.email!)
              .maybeSingle();

      if (freelancerData != null) {
        _userType = 'freelancer';
        _userId = freelancerData['id'];
      } else {
        // Check if user is an employee
        final employeeData =
            await _supabase
                .from('employees')
                .select('id')
                .eq('email', user.email!)
                .maybeSingle();

        if (employeeData != null) {
          _userType = 'employee';
          _userId = employeeData['id'];
        } else {
          throw Exception('User not found as freelancer or employee');
        }
      }

      // Load tasks with work reports
      if (_userType != null && _userId != null) {
        final tasksResponse = await _supabase
            .from('tasks')
            .select('''
              *,
              freelancers!assigned_to_id (name, role)
            ''')
            .eq('assigned_to_id', _userId!)
            .order('created_at', ascending: false);

        // Get work reports for each task
        for (var task in tasksResponse) {
          if (task['status'] == 'completed') {
            final workReportResponse =
                await _supabase
                    .from('work_reports')
                    .select()
                    .eq('freelancer_id', _userId!)
                    .eq('created_at', task['completed_at'])
                    .maybeSingle();

            if (workReportResponse != null) {
              task['work_reports'] = [workReportResponse];
            }
          }
        }

        _tasks = List<Map<String, dynamic>>.from(tasksResponse);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitWorkReport(String taskId) async {
    if (_equipmentNameController.text.isEmpty ||
        _workDescriptionController.text.isEmpty ||
        _replacedPartsController.text.isEmpty ||
        _repairDate == null ||
        _nextDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmittingReport = true);

    try {
      // Upload photos if they exist
      String? workPhotoUrl;
      String? finishedPhotoUrl;
      String? geotaggedPhotoUrl;

      if (_workPhoto != null) {
        workPhotoUrl = await _workReportService.uploadPhoto(
          _workPhoto!,
          _userId!,
          'work',
        );
      }

      if (_finishedPhoto != null) {
        finishedPhotoUrl = await _workReportService.uploadPhoto(
          _finishedPhoto!,
          _userId!,
          'finished',
        );
      }

      if (_geotaggedPhoto != null) {
        geotaggedPhotoUrl = await _workReportService.uploadPhoto(
          _geotaggedPhoto!,
          _userId!,
          'geotagged',
        );
      }

      // Create work report
      await _workReportService.createWorkReport(
        freelancerId: _userId!,
        taskId: taskId,
        equipmentName: _equipmentNameController.text,
        workDescription: _workDescriptionController.text,
        replacedParts: _replacedPartsController.text,
        repairDate: _repairDate!,
        nextDueDate: _nextDueDate!,
        workPhotoUrl: workPhotoUrl,
        finishedPhotoUrl: finishedPhotoUrl,
        geotaggedPhotoUrl: geotaggedPhotoUrl,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        locationAddress: _currentAddress,
        qrCodeData: _qrCodeData,
      );

      // Update task status to completed
      await _supabase
          .from('tasks')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', taskId);

      // Clear form
      _equipmentNameController.clear();
      _workDescriptionController.clear();
      _replacedPartsController.clear();
      _repairDate = null;
      _nextDueDate = null;
      _workPhoto = null;
      _finishedPhoto = null;
      _geotaggedPhoto = null;
      _currentPosition = null;
      _currentAddress = null;
      _qrCodeData = null;

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Work report submitted and task marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting work report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingReport = false);
      }
    }
  }

  Future<void> _pickImage(
    ImageSource source,
    bool isGeotagged, {
    bool isFinishedPhoto = false,
  }) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          if (isFinishedPhoto) {
            _finishedPhoto = File(pickedFile.path);
          } else if (isGeotagged) {
            _geotaggedPhoto = File(pickedFile.path);
            _getCurrentLocation();
          } else {
            _workPhoto = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationHelper = LocationHelper();
      
      // Check if location is available and request permission if needed
      bool isAvailable = await locationHelper.isLocationAvailable();
      if (!isAvailable) {
        bool permissionGranted = await locationHelper.requestLocationPermission(context);
        if (!permissionGranted) {
          // User denied permission, exit early
          return;
        }
      }
      
      // Get location using the helper
      final position = await locationHelper.getCurrentLocationSafely(context);
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });
        
        // Get address using the helper
        final address = await locationHelper.getCurrentAddressSafely(context);
        if (address != null) {
          setState(() {
            _currentAddress = address;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  Future<void> _scanQRCode() async {
    setState(() {
      _scannerController = MobileScannerController();
    });

    if (!mounted) return;

    try {
      final result = await showDialog<String>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(
                'Scan QR Code',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: SizedBox(
                height: 300,
                width: 300,
                child: MobileScanner(
                  controller: _scannerController!,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String? code = barcodes.first.rawValue;
                      if (code != null) {
                        Navigator.of(context).pop(code);
                      }
                    }
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _scannerController?.dispose();
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
              ],
            ),
      );

      if (result != null) {
        setState(() {
          _qrCodeData = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error scanning QR code: $e')));
      }
    } finally {
      _scannerController?.dispose();
      _scannerController = null;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isRepairDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isRepairDate) {
          _repairDate = picked;
        } else {
          _nextDueDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Tasks',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.blue.shade700,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _tasks.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.task_alt, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No tasks assigned yet',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final assigneeName = task['freelancers']['name'];
                  final assigneeRole = task['freelancers']['role'];
                  final workReport =
                      task['work_reports'] != null &&
                              (task['work_reports'] as List).isNotEmpty
                          ? (task['work_reports'] as List).first
                          : null;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            task['task_description'],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned by: $assigneeName (${assigneeRole})',
                              ),
                              Text(
                                'Status: ${task['status']}',
                                style: TextStyle(
                                  color:
                                      task['status'] == 'completed'
                                          ? Colors.green
                                          : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (task['completed_at'] != null)
                                Text(
                                  'Completed: ${DateTime.parse(task['completed_at']).toString().split('.')[0]}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          trailing:
                              task['status'] == 'completed'
                                  ? const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                  : null,
                        ),
                        if (task['status'] == 'pending')
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                const SizedBox(height: 16),
                                Text(
                                  'Work Report Form',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _equipmentNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Equipment Name',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _workDescriptionController,
                                  decoration: InputDecoration(
                                    labelText: 'Work Description',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _replacedPartsController,
                                  decoration: InputDecoration(
                                    labelText: 'Replaced Parts',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 16),
                                // Repair Date
                                InkWell(
                                  onTap: () => _selectDate(context, true),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Repair Date',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _repairDate != null
                                                  ? DateFormat(
                                                    'MMM dd, yyyy',
                                                  ).format(_repairDate!)
                                                  : 'Select repair date',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                color:
                                                    _repairDate != null
                                                        ? Colors.black87
                                                        : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Next Due Date
                                InkWell(
                                  onTap: () => _selectDate(context, false),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Next Due Date',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _nextDueDate != null
                                                  ? DateFormat(
                                                    'MMM dd, yyyy',
                                                  ).format(_nextDueDate!)
                                                  : 'Select next due date',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                color:
                                                    _nextDueDate != null
                                                        ? Colors.black87
                                                        : Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Work Photo Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        () => _pickImage(
                                          ImageSource.camera,
                                          false,
                                        ),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Take Work Photo'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Finished Photo Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        () => _pickImage(
                                          ImageSource.camera,
                                          false,
                                          isFinishedPhoto: true,
                                        ),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Take Finished Photo'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Geotagged Photo Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        () => _pickImage(
                                          ImageSource.camera,
                                          true,
                                        ),
                                    icon: const Icon(Icons.location_on),
                                    label: const Text('Take Geotagged Photo'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // QR Code Scanner Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _scanQRCode,
                                    icon: const Icon(Icons.qr_code_scanner),
                                    label: const Text('Scan QR Code'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_workPhoto != null ||
                                    _finishedPhoto != null ||
                                    _geotaggedPhoto != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_workPhoto != null) ...[
                                          Text(
                                            'Work Photo',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              _workPhoto!,
                                              height: 100,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        if (_finishedPhoto != null) ...[
                                          Text(
                                            'Finished Photo',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              _finishedPhoto!,
                                              height: 100,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        if (_geotaggedPhoto != null) ...[
                                          Text(
                                            'Geotagged Photo',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              _geotaggedPhoto!,
                                              height: 100,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          if (_currentAddress != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Location: $_currentAddress',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ],
                                    ),
                                  ),
                                if (_qrCodeData != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.purple.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.qr_code,
                                          color: Colors.purple.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'QR Code: $_qrCodeData',
                                            style: GoogleFonts.poppins(
                                              color: Colors.purple.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isSubmittingReport
                                            ? null
                                            : () =>
                                                _submitWorkReport(task['id']),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child:
                                        _isSubmittingReport
                                            ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                            : Text(
                                              'Submit Work Report',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (workReport != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(),
                                const SizedBox(height: 16),
                                Text(
                                  'Work Report',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                  'Equipment',
                                  workReport['equipment_name'],
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'Work Description',
                                  workReport['work_description'],
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'Replaced Parts',
                                  workReport['replaced_parts'],
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'Repair Date',
                                  DateFormat('MMM dd, yyyy').format(
                                    DateTime.parse(workReport['repair_date']),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  'Next Due Date',
                                  DateFormat('MMM dd, yyyy').format(
                                    DateTime.parse(workReport['next_due_date']),
                                  ),
                                ),
                                if (workReport['work_photo_url'] != null ||
                                    workReport['finished_photo_url'] != null ||
                                    workReport['geotagged_photo_url'] !=
                                        null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Photos',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (workReport['work_photo_url'] != null)
                                    _buildPhotoSection(
                                      'Work Photo',
                                      workReport['work_photo_url'],
                                    ),
                                  if (workReport['finished_photo_url'] !=
                                      null) ...[
                                    const SizedBox(height: 8),
                                    _buildPhotoSection(
                                      'Finished Photo',
                                      workReport['finished_photo_url'],
                                    ),
                                  ],
                                  if (workReport['geotagged_photo_url'] !=
                                      null) ...[
                                    const SizedBox(height: 8),
                                    _buildPhotoSection(
                                      'Geotagged Photo',
                                      workReport['geotagged_photo_url'],
                                      locationAddress:
                                          workReport['location_address'],
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(
    String label,
    String url, {
    String? locationAddress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Icon(Icons.error),
              );
            },
          ),
        ),
        if (locationAddress != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locationAddress,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _equipmentNameController.dispose();
    _workDescriptionController.dispose();
    _replacedPartsController.dispose();
    super.dispose();
  }
}
