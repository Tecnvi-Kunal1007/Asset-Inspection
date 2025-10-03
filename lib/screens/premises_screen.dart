import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_helper.dart';
import '../services/supabase_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import '../models/premise.dart';
import 'PremiseDetailsScreen.dart';


class CreatePremiseScreen extends StatefulWidget {
  const CreatePremiseScreen({super.key});

  @override
  State<CreatePremiseScreen> createState() => _CreatePremiseScreenState();
}

class _CreatePremiseScreenState extends State<CreatePremiseScreen>
    with TickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  String? _contractorName;
  bool _isLoading = true;
  List<Premise> _premises = [];
  bool _isCreating = false;

  List<PremiseForm> _premiseForms = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContractorDetails();
      _loadPremises();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _disposePremiseForms();
    super.dispose();
  }

  void _disposePremiseForms() {
    for (var form in _premiseForms) {
      form.dispose();
    }
    _premiseForms.clear();
  }

  Future<void> _loadContractorDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final contractor = await _supabase
            .from('contractor')
            .select('name')
            .eq('id', user.id)
            .single()
            .catchError((_) {
          setState(() => _isLoading = false);
          throw Exception('Contractor profile not found');
        });

        setState(() {
          _contractorName = contractor['name'] as String?;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (!mounted) return;
        _showSnackBar('Please log in as a contractor');
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      _showSnackBar('Error loading contractor details: $e');
    }
  }

  // Method to show location on map
  Future<void> _showLocationOnMap(String location) async {
    try {
      // Check if location contains coordinates (with or without "Location:" prefix)
      final coordinatePattern = RegExp(r'(-?\d+\.?\d*),\s*(-?\d+\.?\d*)');
      final match = coordinatePattern.firstMatch(location);
      
      String mapUrl;
      
      if (match != null) {
        // Extract coordinates
        final lat = match.group(1);
        final lng = match.group(2);
        
        // Check if this is just coordinates or if there's readable address text
        final coordinatePart = match.group(0)!;
        
        // Remove common prefixes and the coordinate part to get potential address
        String addressPart = location
            .replaceAll(RegExp(r'^Location:\s*'), '') // Remove "Location: " prefix
            .replaceAll(coordinatePart, '') // Remove coordinates
            .replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '') // Remove leading/trailing commas
            .trim();
        
        // If there's meaningful address text (more than just coordinates), use it
        if (addressPart.isNotEmpty && 
            addressPart.length > 5 && 
            !RegExp(r'^[-\d\s.,]+$').hasMatch(addressPart)) { // Not just numbers, spaces, commas, dots, dashes
          final encodedLocation = Uri.encodeComponent(addressPart);
          mapUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedLocation';
          if (kDebugMode) {
            print('🗺️ Using address for map: $addressPart');
          }
        } else {
          // Use coordinates with a descriptive label
          mapUrl = 'https://www.google.com/maps?q=$lat,$lng&query_place_id=';
          if (kDebugMode) {
            print('🗺️ Using coordinates for map: $lat, $lng');
          }
        }
      } else {
        // Location is purely an address, encode it for URL
        final encodedLocation = Uri.encodeComponent(location);
        mapUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedLocation';
        if (kDebugMode) {
          print('🗺️ Using full address for map: $location');
        }
      }

      final uri = Uri.parse(mapUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open map application'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error opening map: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening map'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadPremises() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final premises = await _supabaseService.getPremises();
        setState(() {
          _premises = premises.where((p) => p.contractorId == user.id).toList();
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error loading premises: $e');
    }
  }

  Future<void> _createAllPremises() async {
    List<PremiseForm> validForms = [];
    for (var form in _premiseForms) {
      if (form.isValid()) {
        validForms.add(form);
      }
    }

    if (validForms.isEmpty) {
      _showSnackBar('Please fill at least one premise form correctly');
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      _showLoadingDialog();

      List<Premise> createdPremises = [];
      for (var form in validForms) {
        final data = form.getData();
        final createdPremise = await _supabaseService.createPremise(
          user.id,
          data,
          name: '',
          additionalData: {},
        );
        createdPremises.add(createdPremise);
      }

      Navigator.of(context).pop();

      _disposePremiseForms();
      setState(() {
        _isCreating = false;
      });

      _animationController.reverse();
      await _loadPremises();

      if (!mounted) return;
      _showSnackBar(
        '${createdPremises.length} premises created successfully!',
        isSuccess: true,
      );

      if (createdPremises.length == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PremiseDetailsScreen(premise: createdPremises.first),
          ),
        );
      }
    } on PostgrestException catch (e) {
      Navigator.of(context).pop();
      _showSnackBar(
        e.code == '23514'
            ? 'Invalid premise name. Please ensure it starts with a capital letter.'
            : 'Error creating premises: ${e.message}',
      );
    } catch (e) {
      Navigator.of(context).pop();
      _showSnackBar('Error creating premises: $e');
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Text('Creating premises...', style: GoogleFonts.poppins()),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _addPremiseForm() {
    setState(() {
      _premiseForms.add(PremiseForm(onShowLocationOnMap: _showLocationOnMap));
    });
  }

  void _removePremiseForm(int index) {
    if (_premiseForms.length > 1) {
      setState(() {
        _premiseForms[index].dispose();
        _premiseForms.removeAt(index);
      });
    }
  }

  void _toggleCreateForm() {
    setState(() {
      _isCreating = !_isCreating;
      if (_isCreating) {
        if (_premiseForms.isEmpty) {
          _premiseForms.add(PremiseForm(onShowLocationOnMap: _showLocationOnMap));
        }
        _animationController.forward();
      } else {
        _animationController.reverse();
        _disposePremiseForms();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredPremises =
    _premises.where((premise) => premise.name.toLowerCase().contains(_searchController.text.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ThemeHelper.primaryBlue,
        title: Text(
          'My Premises',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: ThemeHelper.blueGradient),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isCreating ? Icons.close : Icons.add,
                  key: ValueKey(_isCreating),
                  color: Colors.white,
                  size: 28,
                ),
              ),
              onPressed: _toggleCreateForm,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (!_isCreating) _buildHeaderCard(),
          if (_isCreating)
            Expanded(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) => FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildCreateForm(),
                  ),
                ),
              ),
            ),
          if (!_isCreating)
            Expanded(
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search your premises...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredPremises.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredPremises.length,
                      itemBuilder: (context, index) => _buildPremiseCard(filteredPremises[index]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeHelper.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business,
                  color: ThemeHelper.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${_contractorName ?? 'Contractor'}!',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.textPrimary,
                      ),
                    ),
                    Text(
                      'Manage your premises and their hierarchy',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: ThemeHelper.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_premises.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'Total Premises',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.green.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.add_business, color: Colors.blue.shade600),
                      Text(
                        'Add More',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThemeHelper.primaryBlue.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_business, color: ThemeHelper.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Premises',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: ThemeHelper.textPrimary,
                          ),
                        ),
                        Text(
                          'Add multiple premises at once',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: ThemeHelper.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addPremiseForm,
                    icon: const Icon(Icons.qr_code_2),
                    label: Text('Qr Enabled'),
                    style: TextButton.styleFrom(
                      foregroundColor: ThemeHelper.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _premiseForms.length,
                itemBuilder: (context, index) {
                  return _buildPremiseFormCard(index);
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _toggleCreateForm,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _createAllPremises,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ThemeHelper.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Create All Premises',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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
    );
  }

  Widget _buildPremiseFormCard(int index) {
    final form = _premiseForms[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: ThemeHelper.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Premise ${index + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.primaryBlue,
                  ),
                ),
              ),
              const Spacer(),
              if (_premiseForms.length > 1)
                IconButton(
                  onPressed: () => _removePremiseForm(index),
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: 16),
          form.buildForm(context),
        ],
      ),
    );
  }

  Widget _buildPremiseCard(Premise premise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PremiseDetailsScreen(premise: premise),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ThemeHelper.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.business,
                    color: ThemeHelper.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              premise.name,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ThemeHelper.textPrimary,
                              ),
                            ),
                          ),
                          if (premise.qr_Url != null && premise.qr_Url!.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.download,
                                color: ThemeHelper.primaryBlue,
                              ),
                              onPressed: () => _downloadQrCode(premise.qr_Url!),
                            ),
                        ],
                      ),
                      Text(
                        'by ${premise.contractorName}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: ThemeHelper.textSecondary,
                        ),
                      ),
                      if (premise.location != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                premise.location!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Premises Yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: ThemeHelper.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to create your first premise',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: ThemeHelper.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadQrCode(String qrUrl) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) throw Exception('Storage directory not found');
      final filePath =
          '${directory.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final response = await http.get(Uri.parse(qrUrl));
      if (response.statusCode == 200) {
        await File(filePath).writeAsBytes(response.bodyBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QR code downloaded to $filePath')),
        );
      } else {
        throw Exception('Failed to download QR code');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading QR code: $e')),
      );
    }
  }
}

// Helper class for individual premise forms
class PremiseForm {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final List<Map<String, String>> keyValuePairs = [{}];
  final Function(String)? onShowLocationOnMap;

  PremiseForm({this.onShowLocationOnMap});

  void dispose() {
    nameController.dispose();
    locationController.dispose();
  }

  bool isValid() {
    return nameController.text.isNotEmpty &&
        RegExp(r'^[A-Z]').hasMatch(nameController.text);
  }

  Map<String, dynamic> getData() {
    final data = {
      'name': nameController.text,
      'location': locationController.text.isNotEmpty ? locationController.text : null,
    };

    for (var pair in keyValuePairs) {
      if (pair['key']?.isNotEmpty == true && pair['value']?.isNotEmpty == true) {
        data[pair['key']!] = pair['value'];
      }
    }

    return data;
  }

  // Updated buildForm method for PremiseForm class
  Widget buildForm(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setFormState) {
        return Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Premise Name *',
                hintText: 'e.g., Office Building, Shopping Mall',
                prefixIcon: Icon(Icons.business, color: ThemeHelper.primaryBlue),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: locationController,
                    decoration: InputDecoration(
                      labelText: 'Location',
                      hintText: 'e.g., Delhi, Mumbai, Bangalore',
                      prefixIcon: Icon(Icons.location_on, color: ThemeHelper.primaryBlue),
                      suffixIcon: locationController.text.isNotEmpty 
                        ? Tooltip(
                            message: 'View on Map',
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => onShowLocationOnMap?.call(locationController.text),
                                child: Icon(
                                  Icons.map,
                                  color: ThemeHelper.primaryBlue,
                                  size: 20,
                                ),
                              ),
                            ),
                          )
                        : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.my_location, color: ThemeHelper.primaryBlue),
                  onPressed: () async {
                    try {
                      if (kDebugMode) {
                        print('🎯 Location button pressed - starting location fetch...');
                      }

                      // Show immediate feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              SizedBox(width: 12),
                              Text('Getting your location...'),
                            ],
                          ),
                          backgroundColor: Colors.blue,
                          duration: Duration(seconds: 30),
                        ),
                      );

                      final locationHelper = LocationHelper();
                      final address = await locationHelper.getCurrentAddressSafely(context);

                      // Hide the loading snackbar
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();

                      if (address != null && address.isNotEmpty) {
                        if (kDebugMode) {
                          print('✅ Address received: $address');
                        }

                        // Update the text field
                        locationController.text = address;

                        // Force UI update
                        setFormState(() {});

                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Location found: ${address.length > 50 ? address.substring(0, 50) + '...' : address}'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      } else {
                        if (kDebugMode) {
                          print('⚠️ No valid address received');
                        }

                        // Show option to enter manually
                        final shouldEnterManually = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Text('Location Not Found'),
                              content: Text(
                                  'We couldn\'t determine a readable address for your current location. '
                                      'This might be because:\n'
                                      '• You\'re in a remote area\n'
                                      '• Location services are limited\n'
                                      '• Network connectivity issues\n\n'
                                      'Would you like to enter your location manually?'
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: Text('Enter Manually'),
                                ),
                              ],
                            );
                          },
                        );

                        if (shouldEnterManually == true) {
                          // Focus on the location text field
                          FocusScope.of(context).requestFocus();
                          // You might want to add a FocusNode to the TextField and use it here
                        }
                      }
                    } catch (e) {
                      if (kDebugMode) {
                        print('❌ Error in location button handler: $e');
                      }

                      // Hide loading snackbar
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();

                      // Show error message with helpful information
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Could not get your location'),
                              Text(
                                'Please check: GPS enabled, internet connection, app permissions',
                                style: TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 5),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Additional Properties',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ThemeHelper.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...keyValuePairs.asMap().entries.map((entry) {
              int pairIndex = entry.key;
              var pair = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Property',
                          hintText: 'Type, Capacity, etc.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          pair['key'] = value;
                          setFormState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Value',
                          hintText: 'Building, 100, etc.',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          pair['value'] = value;
                          setFormState(() {});
                        },
                      ),
                    ),
                    if (keyValuePairs.length > 1)
                      IconButton(
                        onPressed: () {
                          keyValuePairs.removeAt(pairIndex);
                          setFormState(() {});
                        },
                        icon: const Icon(Icons.remove_circle, color: Colors.red),
                        iconSize: 20,
                      ),
                  ],
                ),
              );
            }).toList(),
            TextButton.icon(
              onPressed: () {
                keyValuePairs.add({});
                setFormState(() {});
              },
              icon: const Icon(Icons.add, size: 16),
              label: Text('Add Property', style: GoogleFonts.poppins(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: ThemeHelper.primaryBlue),
            ),
          ],
        );
      },
    );
  }



}