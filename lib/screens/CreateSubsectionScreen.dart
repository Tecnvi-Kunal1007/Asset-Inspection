// subsection_list_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/premise.dart';
import '../models/section.dart';
import '../models/subsection.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import '../services/supabase_service.dart';
import 'create_subsection_product_screen.dart';
import 'subsection_details_screen.dart';

class SubsectionListScreen extends StatefulWidget {
  final Premise premise;
  final Section section;

  const SubsectionListScreen({
    super.key,
    required this.premise,
    required this.section, required String sectionId,
  });

  @override
  State<SubsectionListScreen> createState() => _SubsectionListScreenState();
}

class _SubsectionListScreenState extends State<SubsectionListScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<Subsection> _subsections = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadSubsections();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSubsections() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final subsections = await _supabaseService.getSubsections(widget.section.id);
      setState(() {
        _subsections = subsections;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading subsections: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _navigateToCreateSubsection() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateSubsectionScreen(
          premise: widget.premise,
          sectionId: widget.section.id,
        ),
      ),
    );

    if (result == true) {
      _loadSubsections();
    }
  }

  void _navigateToSubsectionDetails(Subsection subsection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubsectionDetailsScreen(
          premise: widget.premise,
          section: widget.section,
          subsection: subsection,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.backgroundGray,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _loadSubsections,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionInfoCard(),
                        SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
                        _buildSubsectionsSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateSubsection,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Subsection',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.green, Colors.green.shade700],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.section.name,
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 24),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Subsections Management',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 16),
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _navigateToCreateSubsection,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.getUniformPadding(context),
                  vertical: ResponsiveHelper.getUniformPadding(context) / 1.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.premise.name,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 14),
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_subsections.length} Subsections',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 12),
                          color: Colors.white,
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
      ),
    );
  }

  Widget _buildSectionInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.layers,
                    color: Colors.green,
                    size: ResponsiveHelper.getIconSize(context, 24),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.getSpacing(context, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Section Information',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 18),
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.textPrimary,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                      Text(
                        'Manage all subsections within this section',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 14),
                          color: ThemeHelper.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubsectionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subsections',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 20),
                fontWeight: FontWeight.w600,
                color: ThemeHelper.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
        _isLoading
            ? Center(
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
            child: const CircularProgressIndicator(),
          ),
        )
            : _subsections.isEmpty
            ? _buildEmptySubsectionsCard()
            : Column(
          children: _subsections
              .map((subsection) => _buildSubsectionCard(subsection))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildEmptySubsectionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) * 1.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.room_outlined,
              size: ResponsiveHelper.getIconSize(context, 64),
              color: Colors.grey.shade400,
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
            Text(
              'No Subsections Yet',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 20),
                fontWeight: FontWeight.w600,
                color: ThemeHelper.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
            Text(
              'Create your first subsection to start organizing this section into manageable areas.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 14),
                color: ThemeHelper.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
            ElevatedButton.icon(
              onPressed: _navigateToCreateSubsection,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Create First Subsection',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.getFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.getUniformPadding(context) * 1.5,
                  vertical: ResponsiveHelper.getUniformPadding(context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubsectionCard(Subsection subsection) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: ResponsiveHelper.getSpacing(context, 12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToSubsectionDetails(subsection),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 1.5),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.room,
                  color: Colors.orange,
                  size: ResponsiveHelper.getIconSize(context, 24),
                ),
              ),
              SizedBox(width: ResponsiveHelper.getSpacing(context, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subsection.name,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.textPrimary,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                    Text(
                      'Tap to view details and manage products',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 14),
                        color: ThemeHelper.textSecondary,
                      ),
                    ),
                    if (subsection.additionalData != null &&
                        subsection.additionalData!.isNotEmpty) ...[
                      SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                      Text(
                        '${subsection.additionalData!.length} additional field(s)',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 12),
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade400,
                    size: ResponsiveHelper.getIconSize(context, 16),
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context, 8)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Active',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 10),
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Updated CreateSubsectionScreen with better success handling
class CreateSubsectionScreen extends StatefulWidget {
  final Premise premise;
  final String sectionId;

  const CreateSubsectionScreen({
    super.key,
    required this.premise,
    required this.sectionId,
  });

  @override
  State<CreateSubsectionScreen> createState() => _CreateSubsectionScreenState();
}

class _CreateSubsectionScreenState extends State<CreateSubsectionScreen> {
  final _supabaseService = SupabaseService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final List<Map<String, String>> _keyValuePairs = [{}];
  bool _isCreating = false;

  static const Color primaryBlue = Color(0xFF1B365D);
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color lightGray = Color(0xFFF5F6FA);
  static const Color darkGray = Color(0xFF2C3E50);
  static const Color successGreen = Color(0xFF27AE60);

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _addKeyValuePair() {
    setState(() {
      _keyValuePairs.add({});
    });
  }

  void _removeKeyValuePair(int index) {
    if (_keyValuePairs.length > 1) {
      setState(() {
        _keyValuePairs.removeAt(index);
      });
    }
  }

  Future<void> _createSubsection() async {
    if (!_formKey.currentState!.validate()) return;

    if (!RegExp(r'^[A-Z]').hasMatch(_nameController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Subsection name must start with a capital letter.'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final data = {
      'name': _nameController.text.trim(),
      'location': _locationController.text.isNotEmpty ? _locationController.text.trim() : null,
    };

    for (var pair in _keyValuePairs) {
      if (pair['key']?.isNotEmpty == true && pair['value']?.isNotEmpty == true) {
        data[pair['key']!] = pair['value']!;
      }
    }

    try {
      await _supabaseService.createSubsection(widget.sectionId, data);

      if (mounted) {
        // Show success animation/dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: successGreen,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Success!',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subsection "${_nameController.text}" has been created successfully.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: darkGray,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).pop(true); // Return to list with success
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Continue',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating subsection: $e'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryBlue, primaryBlue.withOpacity(0.8)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Subsection',
                          style: GoogleFonts.roboto(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add new area to manage',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.room_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Adding to ${widget.premise.name}',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subsection Details',
              style: GoogleFonts.roboto(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            _buildFormField(
              controller: _nameController,
              label: 'Subsection Name',
              icon: Icons.room_outlined,
              hint: 'Enter subsection name (must start with capital letter)',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a subsection name';
                }
                if (!RegExp(r'^[A-Z]').hasMatch(value)) {
                  return 'Subsection name must start with a capital letter';
                }
                return null;
              },
            ),
            _buildFormField(
              controller: _locationController,
              label: 'Location (Optional)',
              icon: Icons.location_on_outlined,
              hint: 'Enter location details',
            ),
            const SizedBox(height: 16),
            Text(
              'Additional Details',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: darkGray,
              ),
            ),
            const SizedBox(height: 12),
            ..._keyValuePairs.asMap().entries.map((entry) {
              int index = entry.key;
              var pair = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Field ${index + 1}',
                          hintText: 'e.g., Area, Capacity, etc.',
                          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500, fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentOrange, width: 2),
                          ),
                        ),
                        onChanged: (value) => setState(() => pair['key'] = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Value ${index + 1}',
                          hintText: 'Enter value',
                          hintStyle: GoogleFonts.roboto(color: Colors.grey.shade500, fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentOrange, width: 2),
                          ),
                        ),
                        onChanged: (value) => setState(() => pair['value'] = value),
                      ),
                    ),
                    if (_keyValuePairs.length > 1)
                      IconButton(
                        onPressed: () => _removeKeyValuePair(index),
                        icon: Icon(Icons.remove_circle_outline, color: Colors.red.shade400),
                      ),
                  ],
                ),
              );
            }).toList(),
            TextButton.icon(
              onPressed: _addKeyValuePair,
              icon: const Icon(Icons.add, color: primaryBlue),
              label: Text(
                'Add Detail Field',
                style: GoogleFonts.roboto(color: primaryBlue, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createSubsection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCreating ? Colors.grey.shade400 : accentOrange,
                  foregroundColor: Colors.white,
                  elevation: _isCreating ? 0 : 8,
                  shadowColor: accentOrange.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isCreating
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Creating Subsection...',
                      style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Create Subsection',
                      style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: darkGray,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.roboto(fontSize: 16, color: darkGray),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.roboto(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentOrange, size: 20),
              ),
              filled: true,
              fillColor: Colors.white,
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
                borderSide: const BorderSide(color: accentOrange, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.red.shade400),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width < 500 ? 16 : 32,
                      vertical: 20,
                    ),
                    child: _buildFormCard(),
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

// Enhanced SubsectionDetailsScreen with better product management
class EnhancedSubsectionDetailsScreen extends StatefulWidget {
  final Premise premise;
  final Section section;
  final Subsection subsection;

  const EnhancedSubsectionDetailsScreen({
    super.key,
    required this.premise,
    required this.section,
    required this.subsection,
  });

  @override
  State<EnhancedSubsectionDetailsScreen> createState() => _EnhancedSubsectionDetailsScreenState();
}

class _EnhancedSubsectionDetailsScreenState extends State<EnhancedSubsectionDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _supabaseService = SupabaseService();
  bool _isLoading = true;
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadProducts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final products = await _supabaseService.getProductsBySubsectionId(widget.subsection.id);
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _navigateToCreateProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubsectionProductsScreen(
          premise: widget.premise,
          subsectionId: widget.subsection.id,
          subsectionName: widget.subsection.name,
        ),
      ),
    );

    if (result == true) {
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.backgroundGray,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _loadProducts,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // _buildHierarchyCard(),
                        SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
                        _buildSubsectionInfoCard(),
                        SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
                        // _buildManagementSection(),
                        SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
                        _buildProductsSection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateProduct,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Product',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange, Colors.orange.shade700],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subsection.name,
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 24),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Subsection Details',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 16),
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _navigateToCreateProduct,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.getUniformPadding(context),
                  vertical: ResponsiveHelper.getUniformPadding(context) / 1.5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.business, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.premise.name,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 14),
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.layers, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.section.name,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 14),
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_products.length} Products',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 12),
                          color: Colors.white,
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
      ),
    );
  }

  // Widget _buildHierarchyCard() {
  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //     child: Padding(
  //       padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildHierarchyArrow() {
  //   return Padding(
  //     padding: EdgeInsets.symmetric(
  //       horizontal: ResponsiveHelper.getSpacing(context, 8),
  //     ),
  //     child: Icon(
  //       Icons.arrow_forward,
  //       color: Colors.grey.shade400,
  //       size: ResponsiveHelper.getIconSize(context, 20),
  //     ),
  //   );
  // }

  Widget _buildHierarchyItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String example,
    bool isActive = false,
  }) {
    return Container(
      width: ResponsiveHelper.isDesktop(context) ? 200 : 150,
      padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 1.5),
      decoration: BoxDecoration(
        color: isActive ? Colors.orange.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.orange : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.orange : Colors.grey.shade700,
                size: ResponsiveHelper.getIconSize(context, 20),
              ),
              SizedBox(width: ResponsiveHelper.getSpacing(context, 8)),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.getFontSize(context, 14),
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.orange : ThemeHelper.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.getSpacing(context, 8)),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.getFontSize(context, 12),
              color: ThemeHelper.textSecondary,
            ),
          ),
          SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
          Text(
            'e.g. $example',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveHelper.getFontSize(context, 10),
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsectionInfoCard() {
    final additionalDetails = widget.subsection.additionalData;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subsection Information',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: ThemeHelper.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
            _buildInfoRow(Icons.drive_file_rename_outline, 'Name', widget.subsection.name),
            if (additionalDetails != null && additionalDetails.isNotEmpty) ...[
              SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
              Text(
                'Additional Details',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.getFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.textPrimary,
                ),
              ),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 8)),
              ...additionalDetails.entries.map((entry) =>
                  _buildInfoRow(Icons.info_outline, entry.key, entry.value.toString())
              ).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.getSpacing(context, 12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 3),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Colors.orange,
              size: ResponsiveHelper.getIconSize(context, 20),
            ),
          ),
          SizedBox(width: ResponsiveHelper.getSpacing(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 14),
                    fontWeight: FontWeight.w500,
                    color: ThemeHelper.textSecondary,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 16),
                    fontWeight: FontWeight.w500,
                    color: ThemeHelper.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildManagementSection() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'Management Actions',
  //         style: GoogleFonts.poppins(
  //           fontSize: ResponsiveHelper.getFontSize(context, 20),
  //           fontWeight: FontWeight.w600,
  //           color: ThemeHelper.textPrimary,
  //         ),
  //       ),
  //       SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
  //       Card(
  //         elevation: 4,
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //         child: Padding(
  //           padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
  //           child: Column(
  //             children: [
  //               _buildActionButton(
  //                 context: context,
  //                 title: 'Add Product',
  //                 subtitle: 'Register new equipment or asset',
  //                 icon: Icons.add_box,
  //                 color: Colors.blue,
  //                 onPressed: _navigateToCreateProduct,
  //               ),
  //               SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
  //               _buildActionButton(
  //                 context: context,
  //                 title: 'Edit Subsection',
  //                 subtitle: 'Modify subsection details',
  //                 icon: Icons.edit,
  //                 color: Colors.amber,
  //                 onPressed: () {
  //                   ScaffoldMessenger.of(context).showSnackBar(
  //                     const SnackBar(content: Text('Edit subsection feature coming soon!')),
  //                   );
  //                 },
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildActionButton({
  //   required BuildContext context,
  //   required String title,
  //   required String subtitle,
  //   required IconData icon,
  //   required Color color,
  //   required VoidCallback onPressed,
  // }) {
  //   return InkWell(
  //     onTap: onPressed,
  //     borderRadius: BorderRadius.circular(12),
  //     child: Padding(
  //       padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 2),
  //       child: Row(
  //         children: [
  //           Container(
  //             padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 1.5),
  //             decoration: BoxDecoration(
  //               color: color.withOpacity(0.1),
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             child: Icon(
  //               icon,
  //               color: color,
  //               size: ResponsiveHelper.getIconSize(context, 24),
  //             ),
  //           ),
  //           SizedBox(width: ResponsiveHelper.getSpacing(context, 16)),
  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   title,
  //                   style: GoogleFonts.poppins(
  //                     fontSize: ResponsiveHelper.getFontSize(context, 16),
  //                     fontWeight: FontWeight.w600,
  //                     color: ThemeHelper.textPrimary,
  //                   ),
  //                 ),
  //                 SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
  //                 Text(
  //                   subtitle,
  //                   style: GoogleFonts.poppins(
  //                     fontSize: ResponsiveHelper.getFontSize(context, 14),
  //                     color: ThemeHelper.textSecondary,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           Icon(
  //             Icons.arrow_forward_ios,
  //             color: Colors.grey.shade400,
  //             size: ResponsiveHelper.getIconSize(context, 16),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Products',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 20),
                fontWeight: FontWeight.w600,
                color: ThemeHelper.textPrimary,
              ),
            ),
            if (_products.isNotEmpty)
              TextButton.icon(
                onPressed: _navigateToCreateProduct,
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Product'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
          ],
        ),
        SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
        _isLoading
            ? Center(
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
            child: const CircularProgressIndicator(),
          ),
        )
            : _products.isEmpty
            ? _buildEmptyProductsCard()
            : Column(
          children: _products.map((product) => _buildProductCard(product)).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyProductsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) * 1.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory,
              size: ResponsiveHelper.getIconSize(context, 64),
              color: Colors.grey.shade400,
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
            Text(
              'No Products Yet',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 20),
                fontWeight: FontWeight.w600,
                color: ThemeHelper.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
            Text(
              'Add products to this subsection to manage them effectively. Products can include equipment, furniture, or any items located in this area.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 14),
                color: ThemeHelper.textSecondary,
                height: 1.5,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
            ElevatedButton.icon(
              onPressed: _navigateToCreateProduct,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'Add First Product',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.getFontSize(context, 16),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.getUniformPadding(context) * 1.5,
                  vertical: ResponsiveHelper.getUniformPadding(context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(dynamic product) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: ResponsiveHelper.getSpacing(context, 12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product details coming soon!')),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 1.5),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory_2,
                  color: Colors.blue,
                  size: ResponsiveHelper.getIconSize(context, 24),
                ),
              ),
              SizedBox(width: ResponsiveHelper.getSpacing(context, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name ?? 'Unknown Product',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.textPrimary,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                    if (product.quantity != null)
                      Text(
                        'Quantity: ${product.quantity}',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 14),
                          color: ThemeHelper.textSecondary,
                        ),
                      ),
                    if (product.data != null && product.data.toString().isNotEmpty)
                      Text(
                        product.data.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 12),
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade400,
                    size: ResponsiveHelper.getIconSize(context, 16),
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context, 8)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Active',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 10),
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Usage Instructions and Navigation Example
/*
IMPLEMENTATION GUIDE:

1. Replace your existing subsection screens with these enhanced versions:
   - SubsectionListScreen: Main screen showing all subsections in a section
   - CreateSubsectionScreen: Enhanced with success dialog and better UX
   - EnhancedSubsectionDetailsScreen: Improved product management

2. Navigation Flow:
   Section Screen → SubsectionListScreen → CreateSubsectionScreen
                                        → SubsectionDetailsScreen → ProductScreen

3. Key Features Added:
   - Plus icon in header for quick access to create subsection
   - Success animation when subsection is created
   - Enhanced empty states with guidance
   - Better visual hierarchy and information display
   - Floating action buttons for easy access
   - Product count badges
   - Status indicators
   - Responsive design improvements

4. Integration Steps:

   a) In your section details screen, navigate to SubsectionListScreen:
   ```dart
   Navigator.push(
     context,
     MaterialPageRoute(
       builder: (context) => SubsectionListScreen(
         premise: premise,
         section: section,
       ),
     ),
   );
   ```

   b) Make sure your SupabaseService has these methods:
   ```dart
   Future<List<Subsection>> getSubsectionsBySectionId(String sectionId);
   Future<void> createSubsection(String sectionId, Map<String, dynamic> data);
   Future<List<dynamic>> getProductsBySubsectionId(String subsectionId);
   ```

   c) Update your model classes to handle the data properly:
   ```dart
   class Subsection {
     final String id;
     final String name;
     final Map<String, dynamic>? additionalData;
     // ... other properties
   }
   ```

5. Customization Options:
   - Change color schemes by modifying the gradient colors
   - Adjust animations by changing duration values
   - Modify card layouts and spacing using ResponsiveHelper
   - Add more management actions in the _buildManagementSection

6. Testing Checklist:
   ✓ Create subsection with success dialog
   ✓ View subsection list with proper navigation
   ✓ Access product creation from subsection details
   ✓ Refresh functionality works
   ✓ Empty states display correctly
   ✓ Plus icons in headers work
   ✓ Floating action buttons respond correctly

This implementation provides a complete subsection management system with
intuitive navigation, clear visual feedback, and efficient user workflows.
*/