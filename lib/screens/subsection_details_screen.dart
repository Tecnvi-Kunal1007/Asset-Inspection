import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/premise.dart';
import '../models/premise.dart';
import '../models/section.dart';
import '../models/subsection.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import '../services/supabase_service.dart';
import 'create_subsection_product_screen.dart';

class SubsectionDetailsScreen extends StatefulWidget {
  final Premise premise;
  final Section section;
  final Subsection subsection;

  const SubsectionDetailsScreen({
    super.key,
    required this.premise,
    required this.section,
    required this.subsection,
  });

  @override
  State<SubsectionDetailsScreen> createState() => _SubsectionDetailsScreenState();
}

class _SubsectionDetailsScreenState extends State<SubsectionDetailsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _supabaseService = SupabaseService();
  final TextEditingController _nameController = TextEditingController();
  final List<Map<String, String>> _keyValuePairs = [];
  bool _isUpdating = false;

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
    _nameController.text = widget.subsection.name;
    _initializeKeyValuePairs();
  }

  void _initializeKeyValuePairs() {
    _keyValuePairs.clear();
    if (widget.subsection.data != null) {
      widget.subsection.data!.forEach((key, value) {
        if (key != 'name') { // Exclude name since it's a separate field
          _keyValuePairs.add({'key': key, 'value': value.toString()});
        }
      });
    }
    if (_keyValuePairs.isEmpty) {
      _keyValuePairs.add({});
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showEditSubsectionDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Edit Subsection',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Subsection Name *',
                    hintText: 'e.g., Room A, Storage Area',
                    prefixIcon: Icon(Icons.room_outlined, color: Colors.green),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                ..._keyValuePairs
                    .asMap()
                    .entries
                    .map((entry) {
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
                            controller: TextEditingController(text: pair['key'] ?? ''),
                            onChanged: (value) {
                              pair['key'] = value;
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
                            controller: TextEditingController(text: pair['value'] ?? ''),
                            onChanged: (value) {
                              pair['value'] = value;
                            },
                          ),
                        ),
                        if (_keyValuePairs.length > 1)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _keyValuePairs.removeAt(pairIndex);
                              });
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
                    setState(() {
                      _keyValuePairs.add({});
                    });
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
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: ThemeHelper.primaryBlue),
              ),
            ),
            TextButton(
              onPressed: _isUpdating
                  ? null
                  : () async {
                if (_nameController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Subsection name cannot be empty')),
                  );
                  return;
                }

                setState(() => _isUpdating = true);

                try {
                  final dataMap = <String, dynamic>{};
                  for (var pair in _keyValuePairs) {
                    if (pair['key']?.isNotEmpty == true && pair['value']?.isNotEmpty == true) {
                      dataMap[pair['key']!] = pair['value'];
                    }
                  }

                  final data = {
                    'name': _nameController.text,
                    'data': dataMap.isNotEmpty ? dataMap : null,
                  };

                  final response = await _supabaseService.updateSubsection(widget.subsection.id, data);

                  if (response != null) {
                    Navigator.pop(context);

                    final updatedSubsection = Subsection(
                      id: widget.subsection.id,
                      sectionId: widget.subsection.sectionId,
                      name: _nameController.text,
                      data: dataMap.isNotEmpty ? dataMap : null,
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubsectionDetailsScreen(
                          premise: widget.premise,
                          section: widget.section,
                          subsection: updatedSubsection,
                        ),
                      ),
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Subsection updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to update subsection. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                } finally {
                  setState(() => _isUpdating = false);
                }
              },
              child: Text(
                'Update',
                style: GoogleFonts.poppins(
                  color: _isUpdating ? Colors.grey : ThemeHelper.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange,
        title: Text(
          widget.subsection.name,
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.getFontSize(context, 20),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Colors.orange.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: _showEditSubsectionDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewCard(),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),
              _buildManagementSection(),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),
              // _buildProductsList(),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.orange.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.room,
                    color: Colors.orange,
                    size: ResponsiveHelper.getIconSize(context, 32),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.getSpacing(context, 20)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subsection.name,
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 28),
                          fontWeight: FontWeight.w700,
                          color: ThemeHelper.textPrimary,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            size: ResponsiveHelper.getIconSize(context, 16),
                            color: ThemeHelper.textSecondary,
                          ),
                          SizedBox(width: ResponsiveHelper.getSpacing(context, 4)),
                          Text(
                            'In ${widget.premise.name}',
                            style: GoogleFonts.poppins(
                              fontSize: ResponsiveHelper.getFontSize(context, 16),
                              fontWeight: FontWeight.w500,
                              color: ThemeHelper.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                      Row(
                        children: [
                          Icon(
                            Icons.layers,
                            size: ResponsiveHelper.getIconSize(context, 16),
                            color: ThemeHelper.textSecondary,
                          ),
                          SizedBox(width: ResponsiveHelper.getSpacing(context, 4)),
                          Text(
                            'In ${widget.section.name}',
                            style: GoogleFonts.poppins(
                              fontSize: ResponsiveHelper.getFontSize(context, 16),
                              fontWeight: FontWeight.w500,
                              color: ThemeHelper.textSecondary,
                            ),
                          ),
                        ],
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





  Widget _buildManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Management Actions',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.getFontSize(context, 20),
            fontWeight: FontWeight.w600,
            color: ThemeHelper.textPrimary,
          ),
        ),
        SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
            child: Column(
              children: [
                SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
                _buildActionButton(
                  context: context,
                  title: 'Add Multiple Products',
                  subtitle: 'Create multiple products at once',
                  icon: Icons.inventory_2,
                  color: Colors.orange,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateMultipleSubsectionProductsScreen(
                          premise: widget.premise,
                          subsectionId: widget.subsection.id,
                          subsection: widget.subsection,
                          subsectionName: widget.subsection.name,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
                _buildActionButton(
                  context: context,
                  title: 'View and Edit Products',
                  subtitle: 'Manage existing products',
                  icon: Icons.edit_note,
                  color: Colors.blue,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateMultipleSubsectionProductsScreen(
                          premise: widget.premise,
                          subsectionId: widget.subsection.id,
                          subsection: widget.subsection,
                          subsectionName: widget.subsection.name,
                          isViewMode: true,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 1.5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: ResponsiveHelper.getIconSize(context, 24)),
                ),
                SizedBox(width: ResponsiveHelper.getSpacing(context, 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 16),
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 14),
                          color: ThemeHelper.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: ResponsiveHelper.getIconSize(context, 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
