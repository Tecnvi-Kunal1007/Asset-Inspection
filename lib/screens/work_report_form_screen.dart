import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import '../services/work_report_service.dart';
import '../services/location_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class WorkReportFormScreen extends StatefulWidget {
  final String freelancerId;
  final String? taskId;

  const WorkReportFormScreen({
    super.key,
    required this.freelancerId,
    this.taskId,
  });

  @override
  State<WorkReportFormScreen> createState() => _WorkReportFormScreenState();
}

class _WorkReportFormScreenState extends State<WorkReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
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
  bool _isLoading = false;
  String? _qrCodeData;

  final _imagePicker = ImagePicker();
  MobileScannerController? _scannerController;

  void _startQRScanner() {
    setState(() {
      _scannerController = MobileScannerController();
    });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            height: 300,
            width: 300,
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: MobileScanner(
                      controller: _scannerController!,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final String? code = barcodes.first.rawValue;
                          if (code != null) {
                            setState(() {
                              _qrCodeData = code;
                            });
                            _scannerController?.stop();
                            Navigator.pop(context);
                          }
                        }
                      },
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Center(
                    child: Text(
                      'Scan QR Code',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source, bool isGeotagged) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          if (isGeotagged) {
            _geotaggedPhoto = File(pickedFile.path);
            // Get location for geotagged photo
            _getCurrentLocation();
          } else if (_workPhoto == null) {
            _workPhoto = File(pickedFile.path);
          } else {
            _finishedPhoto = File(pickedFile.path);
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
        } else {
          // If address retrieval fails, use coordinates as fallback
          setState(() {
            _currentAddress =
                '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_repairDate == null || _nextDueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both repair and next due dates'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final workReportService = WorkReportService();

      // Upload photos if they exist
      String? workPhotoUrl;
      String? finishedPhotoUrl;
      String? geotaggedPhotoUrl;

      if (_workPhoto != null) {
        workPhotoUrl = await workReportService.uploadPhoto(
          _workPhoto!,
          widget.freelancerId,
          'work',
        );
      }

      if (_finishedPhoto != null) {
        finishedPhotoUrl = await workReportService.uploadPhoto(
          _finishedPhoto!,
          widget.freelancerId,
          'finished',
        );
      }

      if (_geotaggedPhoto != null) {
        geotaggedPhotoUrl = await workReportService.uploadPhoto(
          _geotaggedPhoto!,
          widget.freelancerId,
          'geotagged',
        );
      }

      // Create work report
      await workReportService.createWorkReport(
        freelancerId: widget.freelancerId,
        taskId: widget.taskId ?? '',
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work report submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting work report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Submit Work Report',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Equipment Name
                _buildFormCard('Equipment Details', Icons.build, [
                  TextFormField(
                    controller: _equipmentNameController,
                    decoration: InputDecoration(
                      labelText: 'Equipment Name',
                      prefixIcon: Icon(
                        Icons.build,
                        color: Colors.blue.shade700,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade700),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter equipment name';
                      }
                      return null;
                    },
                  ),
                ]),
                const SizedBox(height: 16),

                // Work Description
                _buildFormCard('Work Details', Icons.description, [
                  TextFormField(
                    controller: _workDescriptionController,
                    decoration: InputDecoration(
                      labelText: 'Work Description',
                      prefixIcon: Icon(
                        Icons.description,
                        color: Colors.blue.shade700,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade700),
                      ),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter work description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _replacedPartsController,
                    decoration: InputDecoration(
                      labelText: 'Replaced Parts',
                      prefixIcon: Icon(
                        Icons.settings,
                        color: Colors.blue.shade700,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade700),
                      ),
                    ),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter replaced parts';
                      }
                      return null;
                    },
                  ),
                ]),
                const SizedBox(height: 16),

                // Dates
                _buildFormCard('Schedule', Icons.calendar_today, [
                  _buildDatePicker(
                    'Repair Date',
                    _repairDate,
                    () => _selectDate(context, true),
                    Icons.build,
                  ),
                  const SizedBox(height: 16),
                  _buildDatePicker(
                    'Next Due Date',
                    _nextDueDate,
                    () => _selectDate(context, false),
                    Icons.event,
                  ),
                ]),
                const SizedBox(height: 16),

                // Photos
                _buildFormCard('Photos', Icons.photo_camera, [
                  _buildPhotoSection(
                    'Work Photo',
                    _workPhoto,
                    () => _pickImage(ImageSource.camera, false),
                    () => _pickImage(ImageSource.gallery, false),
                  ),
                  const SizedBox(height: 16),
                  _buildPhotoSection(
                    'Finished Photo',
                    _finishedPhoto,
                    () => _pickImage(ImageSource.camera, false),
                    () => _pickImage(ImageSource.gallery, false),
                  ),
                  const SizedBox(height: 16),
                  _buildPhotoSection(
                    'Geotagged Photo',
                    _geotaggedPhoto,
                    () => _pickImage(ImageSource.camera, true),
                    null,
                    isGeotagged: true,
                  ),
                ]),
                const SizedBox(height: 16),

                // QR Code Scanner
                _buildFormCard('QR Code Scanner', Icons.qr_code_scanner, [
                  if (_qrCodeData != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.qr_code, color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Scanned QR Code Data:',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _qrCodeData!,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startQRScanner,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(
                        _qrCodeData == null
                            ? 'Scan QR Code'
                            : 'Scan New QR Code',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
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
                            'Submit Work Report',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime? date,
    VoidCallback onTap,
    IconData icon,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue.shade700),
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
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null
                        ? DateFormat('MMM dd, yyyy').format(date)
                        : 'Not selected',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today, color: Colors.blue.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(
    String title,
    File? photo,
    VoidCallback onCameraTap,
    VoidCallback? onGalleryTap, {
    bool isGeotagged = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (photo != null)
              Expanded(
                flex: 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(photo, height: 120, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onCameraTap,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(
                        isGeotagged ? 'Take Geotagged Photo' : 'Take Photo',
                        style: GoogleFonts.poppins(fontSize: 13),
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
                  if (onGalleryTap != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onGalleryTap,
                        icon: const Icon(Icons.photo_library),
                        label: Text(
                          'Choose from Gallery',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (isGeotagged && _currentAddress != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Location: $_currentAddress',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
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
