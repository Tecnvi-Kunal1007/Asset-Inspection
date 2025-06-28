import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/premise.dart';
import '../models/section.dart';
import '../models/subsection.dart';
import '../models/subsection_product.dart';
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
          SnackBar(content: Text('Error loading products: ${e.toString()}')),
        );
      }
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.room,
                      color: Colors.white,
                      size: 28,
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
  //         children: [
  //           Text(
  //             'Location Hierarchy',
  //             style: GoogleFonts.poppins(
  //               fontSize: ResponsiveHelper.getFontSize(context, 18),
  //               fontWeight: FontWeight.w600,
  //               color: ThemeHelper.textPrimary,
  //             ),
  //           ),
  //           SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
  //           SingleChildScrollView(
  //             scrollDirection: Axis.horizontal,
  //             child: Row(
  //               children: [
  //                 _buildHierarchyItem(
  //                   icon: Icons.business,
  //                   title: 'Premise',
  //                   subtitle: 'Main building or property',
  //                   example: 'Office Building, Mall, Warehouse',
  //                 ),
  //                 _buildHierarchyArrow(),
  //                 _buildHierarchyItem(
  //                   icon: Icons.layers,
  //                   title: 'Sections',
  //                   subtitle: 'Major divisions within premise',
  //                   example: 'Floors, Wings, Parking Areas',
  //                 ),
  //                 _buildHierarchyArrow(),
  //                 _buildHierarchyItem(
  //                   icon: Icons.room,
  //                   title: 'Subsections',
  //                   subtitle: 'Specific areas within sections',
  //                   example: 'Rooms, Shops, Office Spaces',
  //                   isActive: true,
  //                 ),
  //                 _buildHierarchyArrow(),
  //                 _buildHierarchyItem(
  //                   icon: Icons.inventory,
  //                   title: 'Products',
  //                   subtitle: 'Items or devices in subsections',
  //                   example: 'Furniture, Equipment, Assets',
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildHierarchyArrow() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.getSpacing(context, 8),
      ),
      child: Icon(
        Icons.arrow_forward,
        color: Colors.grey.shade400,
        size: ResponsiveHelper.getIconSize(context, 20),
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
  //                 onPressed: () => Navigator.push(
  //                   context,
  //                   MaterialPageRoute(
  //                     builder: (context) => SubsectionProductsScreen(
  //                       premise: widget.premise,
  //                       subsectionId: widget.subsection.id,
  //                       subsectionName: widget.subsection.name,
  //                     ),
  //                   ),
  //                 ).then((_) => _loadProducts()),
  //               ),
  //               SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
  //               _buildActionButton(
  //                 context: context,
  //                 title: 'Edit Subsection',
  //                 subtitle: 'Modify subsection details',
  //                 icon: Icons.edit,
  //                 color: Colors.amber,
  //                 onPressed: () {
  //                   // TODO: Implement edit subsection functionality
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

  Widget _buildActionButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 2),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 1.5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: ResponsiveHelper.getIconSize(context, 24),
              ),
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
                  SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
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
              color: Colors.grey.shade400,
              size: ResponsiveHelper.getIconSize(context, 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsSection() {
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
        padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory,
              size: ResponsiveHelper.getIconSize(context, 48),
              color: Colors.grey.shade400,
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
            Text(
              'No Products Yet',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 18),
                fontWeight: FontWeight.w600,
                color: ThemeHelper.textPrimary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 8)),
            Text(
              'Add products to this subsection to manage them.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 14),
                color: ThemeHelper.textSecondary,
              ),
            ),
            SizedBox(height: ResponsiveHelper.getSpacing(context, 16)),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubsectionProductsScreen(
                    premise: widget.premise,
                    subsectionId: widget.subsection.id,
                    subsectionName: widget.subsection.name,
                  ),
                ),
              ).then((_) => _loadProducts()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.getUniformPadding(context),
                  vertical: ResponsiveHelper.getUniformPadding(context) / 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Add Product',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.getFontSize(context, 16),
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
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
          // TODO: Navigate to product details screen
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
                      product.name,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: ThemeHelper.textPrimary,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                    Text(
                      'Quantity: ${product.quantity}',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 14),
                        color: ThemeHelper.textSecondary,
                      ),
                    ),
                    if (product.data != null && product.data.isNotEmpty)
                      Text(
                        product.data.toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                color: Colors.grey.shade400,
                size: ResponsiveHelper.getIconSize(context, 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}