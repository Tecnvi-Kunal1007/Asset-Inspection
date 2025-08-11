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

class SectionForm {
  final TextEditingController nameController = TextEditingController();
  final List<Map<String, String>> keyValuePairs = [{}];

  SectionForm({String? name, List<Map<String, String>>? keyValuePairs}) {
    if (name != null) nameController.text = name;
    if (keyValuePairs != null && keyValuePairs.isNotEmpty) {
      this.keyValuePairs.clear();
      this.keyValuePairs.addAll(keyValuePairs.map((pair) => Map<String, String>.from(pair)));
    }
  }

  void dispose() {
    nameController.dispose();
  }

  bool isValid() {
    return nameController.text.isNotEmpty &&
        RegExp(r'^[A-Z]').hasMatch(nameController.text);
  }

  Map<String, dynamic> getData() {
    final dataMap = <String, dynamic>{};
    for (var pair in keyValuePairs) {
      if (pair['key']?.isNotEmpty == true && pair['value']?.isNotEmpty == true) {
        dataMap[pair['key']!] = pair['value'];
      }
    }

    return {
      'name': nameController.text,
      'data': dataMap.isNotEmpty ? dataMap : null,
    };
  }

  Widget buildForm(BuildContext context, {required int index, VoidCallback? onRemove, required VoidCallback onUpdate}) {
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ThemeHelper.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Section ${index + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.primaryBlue,
                  ),
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  iconSize: 20,
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Section Name *',
              hintText: 'e.g., Ground Floor, East Wing',
              prefixIcon: Icon(Icons.layers, color: Colors.green),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              isDense: true,
            ),
            onChanged: (value) => onUpdate(),
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
                        hintText: 'e.g., Capacity, Area',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        pair['key'] = value;
                        onUpdate();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Value',
                        hintText: 'e.g., 50 people, 500 sqft',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        pair['value'] = value;
                        onUpdate();
                      },
                    ),
                  ),
                  if (keyValuePairs.length > 1)
                    IconButton(
                      onPressed: () {
                        keyValuePairs.removeAt(pairIndex);
                        onUpdate();
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
              onUpdate();
            },
            icon: const Icon(Icons.add, size: 16),
            label: Text(
              'Add Property',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: ThemeHelper.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class CreateSectionScreen extends StatefulWidget {
  final Premise premise;
  final String premiseId;

  const CreateSectionScreen({super.key, required this.premise, required this.premiseId});

  @override
  State<CreateSectionScreen> createState() => _CreateSectionScreenState();
}

class _CreateSectionScreenState extends State<CreateSectionScreen> with TickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _numberOfSectionsController = TextEditingController();
  List<SectionForm> _sectionForms = [];
  bool _isCreating = false;
  bool _isNumberInput = false;

  bool _isLoading = true;
  List<Section> _sections = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSections();
      print('initState: Sections loaded, _isCreating=$_isCreating');
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _numberOfSectionsController.dispose();
    for (var form in _sectionForms) {
      form.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSections() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final response = await _supabaseService.getSections(widget.premise.id);
        setState(() {
          _sections = response;
          _isLoading = false;
        });
        print('loadSections: Loaded ${_sections.length} sections: ${_sections.map((s) => s.name).toList()}');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error loading sections: $e');
      setState(() => _isLoading = false);
      print('loadSections: Error - $e');
    }
  }

  Future<void> _createSections() async {
    List<SectionForm> validForms = _sectionForms.where((form) => form.isValid()).toList();

    if (validForms.isEmpty) {
      _showSnackBar('Please fill at least one section form correctly');
      return;
    }

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Sections',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'You have filled ${validForms.length} valid section(s). Do you want to create them?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: ThemeHelper.primaryBlue),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Confirm',
              style: GoogleFonts.poppins(
                color: ThemeHelper.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      _showLoadingDialog();

      for (var form in validForms) {
        final data = form.getData();
        print('createSections: Saving data: $data');
        await _supabaseService.createSection(widget.premiseId, data);
      }

      Navigator.of(context).pop();

      setState(() {
        _sectionForms.clear();
        _isCreating = false;
        _isNumberInput = false;
        _numberOfSectionsController.clear();
      });

      _animationController.reverse();
      await _loadSections();

      if (!mounted) return;
      _showSnackBar('${validForms.length} sections created successfully!', isSuccess: true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PremiseDetailsScreen(premise: widget.premise),
        ),
      );
    } on PostgrestException catch (e) {
      Navigator.of(context).pop();
      _showSnackBar(e.code == '23514'
          ? 'Invalid section name. Please ensure it starts with a capital letter.'
          : 'Error creating sections: ${e.message}');
    } catch (e) {
      Navigator.of(context).pop();
      _showSnackBar('Error creating sections: $e');
    }
  }

  Future<void> _updateSection(Section section, SectionForm form) async {
    try {
      final data = form.getData();
      print('updateSection: Updating section ${section.id} with data: $data');

      // Check for changes in name or data
      final hasNameChanged = data['name'] != section.name;
      final hasDataChanged = !_areDataEqual(data['data'] as Map<String, dynamic>?, section.data);

      if (!hasNameChanged && !hasDataChanged) {
        _showSnackBar('No changes detected');
        return;
      }

      final response = await _supabaseService.updateSection(section.id, data);
      print('updateSection: Response: $response');

      if (response != null) {
        _showSnackBar('Section updated successfully!', isSuccess: true);
        await _loadSections();
      } else {
        _showSnackBar('Update failed, please try again');
      }
    } on PostgrestException catch (e) {
      print('updateSection: PostgrestException - Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
      _showSnackBar(e.code == '23505'
          ? 'Section name already exists. Please choose a unique name.'
          : 'Error updating section: ${e.message}');
    } catch (e) {
      print('updateSection: Error - $e');
      _showSnackBar('Error updating section: $e');
    }
  }

  bool _areDataEqual(Map<String, dynamic>? newData, Map<String, dynamic>? oldData) {
    final newDataMap = newData ?? {};
    final oldDataMap = oldData ?? {};
    if (newDataMap.length != oldDataMap.length) return false;
    return newDataMap.entries.every((entry) => oldDataMap[entry.key] == entry.value);
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
                Text(
                  'Creating sections...',
                  style: GoogleFonts.poppins(),
                ),
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

  void _generateSectionForms() {
    if (_sectionForms.isEmpty || !_sectionForms[0].isValid()) {
      _showSnackBar('Please fill the first section form correctly');
      return;
    }

    final numberText = _numberOfSectionsController.text;
    final number = int.tryParse(numberText) ?? 0;
    if (number < 0) {
      _showSnackBar('Please enter a valid number of additional sections');
      return;
    }

    final templateForm = _sectionForms[0];
    setState(() {
      _sectionForms = [
        templateForm,
        ...List.generate(
          number,
              (_) => SectionForm(
            name: templateForm.nameController.text,
            keyValuePairs: templateForm.keyValuePairs,
          ),
        ),
      ];
      _isNumberInput = false;
      _isCreating = true;
      _animationController.forward();
      print('generateSectionForms: Generated ${_sectionForms.length} forms');
    });
  }

  void _removeSectionForm(int index) {
    if (_sectionForms.length > 1) {
      setState(() {
        _sectionForms[index].dispose();
        _sectionForms.removeAt(index);
        print('removeSectionForm: Removed form at index $index, ${_sectionForms.length} forms remain');
      });
    } else {
      setState(() {
        _sectionForms.clear();
        _isCreating = false;
        _isNumberInput = false;
        _numberOfSectionsController.clear();
        _animationController.reverse();
        print('removeSectionForm: Cleared all forms, _isCreating=$_isCreating');
      });
    }
  }

  void _toggleCreateForm() {
    setState(() {
      _isCreating = !_isCreating;
      _isNumberInput = false;
      if (_isCreating) {
        _sectionForms = [SectionForm()];
        _animationController.forward();
        print('toggleCreateForm: Started creating, _sectionForms.length=${_sectionForms.length}');
      } else {
        _animationController.reverse();
        for (var form in _sectionForms) {
          form.dispose();
        }
        _sectionForms.clear();
        _numberOfSectionsController.clear();
        print('toggleCreateForm: Stopped creating, _sectionForms cleared');
      }
    });
  }

  void _showNumberInputDialog() {
    if (_sectionForms.isEmpty || !_sectionForms[0].isValid()) {
      _showSnackBar('Please fill the first section form correctly');
      return;
    }

    setState(() {
      _isNumberInput = true;
      _animationController.forward();
      print('showNumberInputDialog: Showing number input, _isNumberInput=$_isNumberInput');
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredSections = _sections
        .where((section) => section.name.toLowerCase().contains(_searchController.text.toLowerCase()))
        .toList();

    print('build: _isCreating=$_isCreating, _isNumberInput=$_isNumberInput, _sectionForms.length=${_sectionForms.length}');

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
          : SingleChildScrollView(
        child: Column(
          children: [
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
            if (_isCreating && !_isNumberInput)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) => FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildCreateForm(),
                ),
              ),
            if (_isCreating && _isNumberInput)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) => FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildNumberInputForm(),
                ),
              ),
            if (!_isCreating)
              Column(
                children: [
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
                  filteredSections.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredSections.length,
                    itemBuilder: (context, index) => _buildSectionCard(filteredSections[index]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberInputForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create Additional Sections',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: ThemeHelper.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'How many additional sections do you want to create using the first section as a template?',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: ThemeHelper.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _numberOfSectionsController,
                decoration: InputDecoration(
                  labelText: 'Number of Additional Sections *',
                  hintText: 'e.g., 2',
                  prefixIcon: Icon(Icons.numbers, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => setState(() {}),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isNumberInput = false;
                          _numberOfSectionsController.clear();
                          print('buildNumberInputForm: Cancelled number input');
                        });
                      },
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
                      onPressed: _generateSectionForms,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Generate',
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
    );
  }

  Widget _buildSectionCard(Section section) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SectionDetailsScreen(
              section: section,
              premise: widget.premise,
            ),
          ),
        ).then((_) => _loadSections());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.layers, color: Colors.green),
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
                        if (section.data != null && section.data!.isNotEmpty)
                          Text(
                            '${section.data!.length} properties',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: ThemeHelper.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade400,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/ember_logo.png',
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),
          Text(
            'No Sections Found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: ThemeHelper.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchController.text.isNotEmpty
                ? 'No sections match your search criteria.'
                : 'Start by creating sections for ${widget.premise.name}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: ThemeHelper.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _toggleCreateForm,
            icon: const Icon(Icons.add),
            label: Text(
              'Create Section',
              style: GoogleFonts.poppins(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.layers, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Sections',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: ThemeHelper.textPrimary,
                          ),
                        ),
                        Text(
                          'Add multiple sections to ${widget.premise.name}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: ThemeHelper.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  ..._sectionForms.asMap().entries.map((entry) {
                    int index = entry.key;
                    var form = entry.value;
                    return form.buildForm(
                      context,
                      index: index,
                      onRemove: () => _removeSectionForm(index),
                      onUpdate: () => setState(() {}),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showNumberInputDialog,
                          icon: const Icon(Icons.copy),
                          label: Text(
                            ' Create Multiples ',
                            style: GoogleFonts.poppins(),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _createSections,
                          icon: const Icon(Icons.save),
                          label: Text(
                            'Save Sections',
                            style: GoogleFonts.poppins(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}
