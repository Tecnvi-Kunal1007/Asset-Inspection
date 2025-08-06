import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import '../models/premise.dart';
import 'PremiseDetailsScreen.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
        createdPremises.add(createdPremise as Premise);
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
            builder:
                (context) =>
                    PremiseDetailsScreen(premise: createdPremises.first),
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
      _premiseForms.add(PremiseForm());
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
          _premiseForms.add(PremiseForm());
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
        _premises
            .where(
              (premise) => premise.name.toLowerCase().contains(
                _searchController.text.toLowerCase(),
              ),
            )
            .toList();

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
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (!_isCreating) _buildHeaderCard(),
                  if (_isCreating)
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder:
                            (context, child) => FadeTransition(
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
                            child:
                                filteredPremises.isEmpty
                                    ? _buildEmptyState()
                                    : ListView.builder(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      itemCount: filteredPremises.length,
                                      itemBuilder:
                                          (context, index) => _buildPremiseCard(
                                            filteredPremises[index],
                                          ),
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
                          if (premise.qr_Url != null &&
                              premise.qr_Url!.isNotEmpty)
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
                      if (premise.additionalData['location'] != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              premise.additionalData['location'].toString(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error downloading QR code: $e')));
    }
  }
}

// Helper class for individual premise forms
class PremiseForm {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final List<Map<String, String>> keyValuePairs = [{}];

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
      'location':
          locationController.text.isNotEmpty ? locationController.text : null,
    };

    for (var pair in keyValuePairs) {
      if (pair['key']?.isNotEmpty == true &&
          pair['value']?.isNotEmpty == true) {
        data[pair['key']!] = pair['value'];
      }
    }

    return data;
  }

  Widget buildForm(BuildContext context) {
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
        TextField(
          controller: locationController,
          decoration: InputDecoration(
            labelText: 'Location',
            hintText: 'e.g., Delhi, Mumbai, Bangalore',
            prefixIcon: Icon(Icons.location_on, color: ThemeHelper.primaryBlue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            isDense: true,
          ),
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
                    onChanged: (value) => pair['key'] = value,
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
                    onChanged: (value) => pair['value'] = value,
                  ),
                ),
                if (keyValuePairs.length > 1)
                  IconButton(
                    onPressed: () {
                      keyValuePairs.removeAt(pairIndex);
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
          },
          icon: const Icon(Icons.add, size: 16),
          label: Text('Add Property', style: GoogleFonts.poppins(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: ThemeHelper.primaryBlue),
        ),
      ],
    );
  }
}
