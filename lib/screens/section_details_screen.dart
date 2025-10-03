import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pump_management_system/screens/section_product_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../models/premise.dart';
import '../models/section.dart';
import '../models/subsection.dart';
import '../models/subsection_product.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import '../services/supabase_service.dart';
import 'CreateSubsectionScreen.dart';
// import 'subsection_selection_screen.dart';
import 'create_subsection_product_screen.dart';
import 'subsection_details_screen.dart';

class SectionDetailsScreen extends StatefulWidget {
  final Premise premise;
  final Section section;
  final Subsection? subsection;
  final Product? product;


  const SectionDetailsScreen({
    super.key,
    required this.premise,
    required this.section,
    this.subsection,
    this.product,
  });

  @override
  State<SectionDetailsScreen> createState() => _SectionDetailsScreenState();
}

class _SectionDetailsScreenState extends State<SectionDetailsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _supabaseService = SupabaseService();
  final TextEditingController _sectionNameController = TextEditingController();
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _sectionNameController.dispose();
    super.dispose();
  }

  void _showEditSectionDialog(Section section) {
    // Initialize controllers with current values
    _sectionNameController.text = section.name;
    _keyValuePairs.clear();

    if (section.data != null) {
      section.data!.forEach((key, value) {
        _keyValuePairs.add({'key': key, 'value': value.toString()});
      });
    }

    // Add an empty pair for new entries
    if (_keyValuePairs.isEmpty) {
      _keyValuePairs.add({});
    }

    showDialog(
      context: context,
      builder: (context) =>
          StatefulBuilder(
            builder: (context, setState) =>
                AlertDialog(
                  title: Text(
                    'Edit Section',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _sectionNameController,
                          decoration: InputDecoration(
                            labelText: 'Section Name *',
                            hintText: 'e.g., Ground Floor, East Wing',
                            prefixIcon: Icon(Icons.layers, color: Colors.green),
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
                                    controller: TextEditingController(
                                        text: pair['key'] ?? ''),
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
                                    controller: TextEditingController(
                                        text: pair['value'] ?? ''),
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
                                    icon: const Icon(
                                        Icons.remove_circle, color: Colors.red),
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
                        style: GoogleFonts.poppins(
                            color: ThemeHelper.primaryBlue),
                      ),
                    ),
                    TextButton(
                      onPressed: _isUpdating
                          ? null
                          : () async {
                        if (_sectionNameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Section name cannot be empty')),
                          );
                          return;
                        }

                        setState(() => _isUpdating = true);

                        try {
                          // Prepare data for update
                          final dataMap = <String, dynamic>{};
                          for (var pair in _keyValuePairs) {
                            if (pair['key']?.isNotEmpty == true &&
                                pair['value']?.isNotEmpty == true) {
                              dataMap[pair['key']!] = pair['value'];
                            }
                          }

                          final data = {
                            'name': _sectionNameController.text,
                            'data': dataMap.isNotEmpty ? dataMap : null,
                          };

                          // Update section
                          final response = await _supabaseService.updateSection(
                              section.id, data);

                          if (response != null) {
                            // Update successful
                            Navigator.pop(context);

                            // Refresh the screen with updated data
                            final updatedSection = Section(
                              id: section.id,
                              name: _sectionNameController.text,
                              premiseId: section.premiseId,
                              data: dataMap.isNotEmpty ? dataMap : null,
                            );

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SectionDetailsScreen(
                                      premise: widget.premise,
                                      section: updatedSection,
                                    ),
                              ),
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Section updated successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            // Update failed
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Failed to update section. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          // Error occurred
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
                          color: _isUpdating ? Colors.grey : ThemeHelper
                              .primaryBlue,
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
        backgroundColor: Colors.green,
        title: Text(
          widget.section.name,
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.getFontSize(context, 20),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.green.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {
              _showEditSectionDialog(widget.section);
            },
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
              // Section Overview Card
              _buildOverviewCard(),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),

              // Hierarchy Explanation Card
              _buildHierarchyCard(),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),

              // Management Actions
              _buildManagementSection(),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),

              // Subsections List
              // _buildSubsectionsList(),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),

              // Products List
              _buildProductsList(),
              SizedBox(height: ResponsiveHelper.getSpacing(context, 20)),

              // Details Card
              // _buildDetailsCard(),
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
            colors: [Colors.white, Colors.green.shade50],
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
                  padding: EdgeInsets.all(
                      ResponsiveHelper.getUniformPadding(context)),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.layers,
                    color: Colors.green,
                    size: ResponsiveHelper.getIconSize(context, 32),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.getSpacing(context, 20)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.section.name,
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
                          SizedBox(width: ResponsiveHelper.getSpacing(context,
                              4)),
                          Text(
                            'In ${widget.premise.name}',
                            style: GoogleFonts.poppins(
                              fontSize: ResponsiveHelper.getFontSize(
                                  context, 16),
                              fontWeight: FontWeight.w500,
                              color: ThemeHelper.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // QR Code Section - Add this after the existing content
                if (widget.section.sectionQrUrl != null &&
                    widget.section.sectionQrUrl!.isNotEmpty &&
                    widget.section.sectionQrUrl != 'pending')
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.section.sectionQrUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    ThemeHelper.primaryBlue,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading QR code: $error');
                              print('QR URL: ${widget.section.sectionQrUrl}');
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_2,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'QR Error',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('WhatsApp'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () => _shareQrCode(widget.section.sectionQrUrl!, 'whatsapp'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.email, size: 16),
                            label: const Text('Email'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onPressed: () => _shareQrCode(widget.section.sectionQrUrl!, 'email'),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
            // QR Code Info Banner - Add this after the main card content
            if (widget.section.sectionQrUrl != null &&
                widget.section.sectionQrUrl!.isNotEmpty &&
                widget.section.sectionQrUrl != 'pending') ...[  
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QR Code Available',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This section has a QR code that includes its name and ID. Scan it for quick access or download it for offline use.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ],
        ),
      ),
    );
  }

  Widget _buildHierarchyCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
            Container(
              padding: EdgeInsets.all(
                  ResponsiveHelper.getUniformPadding(context)),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),

            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String example,
    bool isActive = false,
  }) {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(
                ResponsiveHelper.getUniformPadding(context) / 2),
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white,
                size: ResponsiveHelper.getIconSize(context, 20)),
          ),
          SizedBox(width: ResponsiveHelper.getSpacing(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.green : ThemeHelper.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 12),
                    color: ThemeHelper.textSecondary,
                  ),
                ),
                Text(
                  'e.g., $example',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 11),
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyArrow() {
    return Container(
      margin: EdgeInsets.symmetric(
          vertical: ResponsiveHelper.getSpacing(context, 8)),
      child: Icon(
        Icons.keyboard_arrow_down,
        color: Colors.green,
        size: ResponsiveHelper.getIconSize(context, 24),
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(
                ResponsiveHelper.getUniformPadding(context)),
            child: Column(
              children: [
                _buildActionButton(
                  context: context,
                  title: 'Create Subsection',
                  subtitle: 'Add rooms, shops, or specific spaces',
                  icon: Icons.room,
                  color: Colors.orange,
                  onPressed: () =>
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CreateSubsectionScreen(
                                premise: widget.premise,
                                section: widget.section,
                                sectionId: widget.section
                                    .id, // ✅ Pass the actual section ID
                                // Don't pass subsection here since we're creating a new one
                              ),
                        ),
                      ),
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
                _buildActionButton(
                  context: context,
                  title: 'Create Section Product',
                  subtitle: 'Add items, equipment, or assets',
                  icon: Icons.inventory,
                  color: Colors.purple,
                  onPressed: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SectionProductsScreen(
                              premise: widget.premise,
                              section: widget.section,
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
            padding: EdgeInsets.all(
                ResponsiveHelper.getUniformPadding(context)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(
                      ResponsiveHelper.getUniformPadding(context) / 1.5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color,
                      size: ResponsiveHelper.getIconSize(context, 24)),
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

  Widget _buildProductsList() {
    return FutureBuilder<List<Product>>(
      future: _supabaseService.getProductsBySection(widget.section.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading products',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 16),
                color: ThemeHelper.textSecondary,
              ),
            ),
          );
        }
        final products = snapshot.data ?? [];
        if (products.isEmpty) {
          return Center(
            child: Column(
              children: [
                Icon(
                  Icons.inventory_outlined,
                  size: ResponsiveHelper.getIconSize(context, 64),
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
                Text(
                  'No Products Available',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 20),
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.textPrimary,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context, 8)),
                Text(
                  'Create  product to directly  add items to a Section.',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 14),
                    color: ThemeHelper.textSecondary,
                  ),
                ),
                SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),

              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Products',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 20),
                fontWeight: FontWeight.w600,
                color: ThemeHelper.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return _buildProductCard(product);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Navigate to ProductDetailsScreen when implemented
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product details coming soon!')),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
          child: Row(
            children: [
              product.photoUrl != null && product.photoUrl!.isNotEmpty
                  ? Container(
                width: ResponsiveHelper.getIconSize(context, 50),
                height: ResponsiveHelper.getIconSize(context, 50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: NetworkImage(product.photoUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
                  : Container(
                padding: EdgeInsets.all(
                    ResponsiveHelper.getUniformPadding(context) / 1.5),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.inventory,
                  color: Colors.purple,
                  size: ResponsiveHelper.getIconSize(context, 24),
                ),
              ),
              SizedBox(width: ResponsiveHelper.getSpacing(context, 16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.textPrimary,
                      ),
                    ),
                    Text(
                      'In Subsection',
                      // Replace with actual subsection name if available
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
                size: ResponsiveHelper.getIconSize(context, 16),
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }


// Place the _shareQrCode function HERE, BEFORE the closing brace
  Future<void> _shareQrCode(String qrUrl, String shareType) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Text('Preparing QR code...', style: GoogleFonts.poppins()),
                ],
              ),
            ),
          );
        },
      );

      // Download the QR code image
      final response = await http.get(Uri.parse(qrUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download QR code');
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Share the QR code
      final String shareText = 'QR Code for ${widget.section.name}';

      if (shareType == 'whatsapp') {
        await Share.share(
          'Check out the QR Code for ${widget.section.name}: $qrUrl',
          subject: 'QR Code for Section',
        );
      } else if (shareType == 'email') {
        await Share.share(
          'Check out the QR Code for ${widget.section.name}: $qrUrl',
          subject: 'QR Code for Section: ${widget.section.name}',
        );
      }
    } catch (e) {
      // Close loading dialog if it's still open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing QR code: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
}
// This should be the ONLY closing brace for the _SectionDetailsScreenState class

