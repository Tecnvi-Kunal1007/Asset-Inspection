import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pump_management_system/screens/section_details_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import '../models/section.dart';
import '../models/premise.dart';
import 'PremiseDetailsScreen.dart';
// Add this import

class CreateSectionScreen extends StatefulWidget {
  final Premise premise;

  const CreateSectionScreen({super.key, required this.premise, required String premiseId});

  @override
  State<CreateSectionScreen> createState() => _CreateSectionScreenState();
}

class _CreateSectionScreenState extends State<CreateSectionScreen> with TickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  final List<Map<String, String>> _keyValuePairs = [{}];
  List<Section> _sections = [];
  bool _isCreating = false;

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
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSections();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSections() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final sections = await _supabaseService.getSections(widget.premise.id);
        setState(() {
          _sections = sections;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error loading sections: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createSection() async {
    if (_nameController.text.isEmpty) {
      _showSnackBar('Please enter a section name');
      return;
    }

    if (!RegExp(r'^[A-Z]').hasMatch(_nameController.text)) {
      _showSnackBar('Section name must start with a capital letter');
      return;
    }

    final data = {
      'name': _nameController.text,
      'location': _locationController.text.isNotEmpty ? _locationController.text : null,
    };

    for (var pair in _keyValuePairs) {
      if (pair['key']?.isNotEmpty == true && pair['value']?.isNotEmpty == true) {
        data[pair['key']!] = pair['value'];
      }
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final newSection = await _supabaseService.createSection(widget.premise.id, data);

      setState(() {
        _nameController.clear();
        _locationController.clear();
        _keyValuePairs.clear();
        _keyValuePairs.add({});
        _isCreating = false;
      });

      _animationController.reverse();
      await _loadSections();

      if (!mounted) return;
      _showSnackBar('Section created successfully!', isSuccess: true);

      // Navigate back to PremiseDetailsScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PremiseDetailsScreen(premise: widget.premise),
        ),
      );

    } on PostgrestException catch (e) {
      _showSnackBar(e.code == '23514'
          ? 'Invalid section name. Please ensure it starts with a capital letter.'
          : 'Error creating section: ${e.message}');
    } catch (e) {
      _showSnackBar('Error creating section: $e');
    }
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

  void _addKeyValuePair() {
    setState(() => _keyValuePairs.add({}));
  }

  void _removeKeyValuePair(int index) {
    if (_keyValuePairs.length > 1) {
      setState(() => _keyValuePairs.removeAt(index));
    }
  }

  void _toggleCreateForm() {
    setState(() {
      _isCreating = !_isCreating;
      if (_isCreating) {
        _animationController.forward();
      } else {
        _animationController.reverse();
        _nameController.clear();
        _locationController.clear();
        _keyValuePairs.clear();
        _keyValuePairs.add({});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredSections = _sections
        .where((section) => section.name.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ThemeHelper.primaryBlue,
        title: Text(
          'Sections',
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
          // Header Info Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.green.shade50],
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
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.layers,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sections in ${widget.premise.name}',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: ThemeHelper.textPrimary,
                            ),
                          ),
                          Text(
                            'Organize your premise into major areas',
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
                // Section Explanation
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.green.shade600, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sections are major divisions like floors, wings, parking areas, or departments within your premise.',
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

          // Create Form (Animated)
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

          // Sections List
          if (!_isCreating)
            Expanded(
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search sections...',
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

                  // Sections List
                  Expanded(
                    child: filteredSections.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredSections.length,
                      itemBuilder: (context, index) => _buildSectionCard(filteredSections[index]),
                    ),
                  ),
                ],
              ),
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Section',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: ThemeHelper.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add a major division to ${widget.premise.name}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: ThemeHelper.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Section Name Field
                _buildInputField(
                  controller: _nameController,
                  label: 'Section Name',
                  hint: 'e.g., Ground Floor, Parking Area, East Wing',
                  icon: Icons.layers,
                  isRequired: true,
                  validator: (value) {
                    if (value?.isEmpty == true) return 'Please enter a name';
                    if (!RegExp(r'^[A-Z]').hasMatch(value!)) {
                      return 'Name must start with a capital letter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Location Field
                _buildInputField(
                  controller: _locationController,
                  label: 'Specific Location',
                  hint: 'e.g., North Side, Level 1, Block A',
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 24),

                // Additional Properties Section
                Text(
                  'Additional Properties',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add custom properties for this section',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: ThemeHelper.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Key-Value Pairs
                ..._keyValuePairs.asMap().entries.map((entry) {
                  int index = entry.key;
                  var pair = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'Property',
                              hintText: 'e.g., Capacity, Area, Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                            onChanged: (value) => setState(() => pair['key'] = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'Value',
                              hintText: 'e.g., 50 people, 500 sqft, Office',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                            onChanged: (value) => setState(() => pair['value'] = value),
                          ),
                        ),
                        if (_keyValuePairs.length > 1)
                          IconButton(
                            onPressed: () => _removeKeyValuePair(index),
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                          ),
                      ],
                    ),
                  );
                }).toList(),

                // Add More Button
                TextButton.icon(
                  onPressed: _addKeyValuePair,
                  icon: const Icon(Icons.add),
                  label: Text('Add Property', style: GoogleFonts.poppins()),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
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
                        onPressed: _createSection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Create Section',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: '$label${isRequired ? ' *' : ''}',
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.green, width: 2),
        ),
        errorText: validator?.call(controller.text),
      ),
      onChanged: (value) => setState(() {}),
    );
  }

  Widget _buildSectionCard(Section section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Navigate to SectionDetailsScreen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SectionDetailsScreen(
                  premise: widget.premise,
                  section: section,
                ),
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.layers,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.textPrimary,
                        ),
                      ),
                      Text(
                        'In ${widget.premise.name}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: ThemeHelper.textSecondary,
                        ),
                      ),
                      if (section.additionalData?['location'] != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              section.additionalData!['location'].toString(),
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
              Icons.layers_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Sections Yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: ThemeHelper.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to create your first section',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: ThemeHelper.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}