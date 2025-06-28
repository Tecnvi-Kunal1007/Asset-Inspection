  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:pump_management_system/screens/section_product_screen.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import '../models/premise.dart';
  import '../models/section.dart';
  import '../models/subsection.dart';
  import '../models/subsection_product.dart';
  import '../utils/responsive_helper.dart';
  import '../utils/theme_helper.dart';
  import '../services/supabase_service.dart';
  import 'CreateSubsectionScreen.dart';
  import 'subsection_selection_screen.dart';
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
      super.dispose();
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit feature coming soon!')),
                );
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
                _buildSubsectionsList(),
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
                    padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
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
                        if (widget.section.additionalData?['location'] != null) ...[
                          SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: ResponsiveHelper.getIconSize(context, 16),
                                color: ThemeHelper.textSecondary,
                              ),
                              SizedBox(width: ResponsiveHelper.getSpacing(context, 4)),
                              Text(
                                widget.section.additionalData!['location'].toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: ResponsiveHelper.getFontSize(context, 14),
                                  color: ThemeHelper.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
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
                padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
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
              padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 2),
              decoration: BoxDecoration(
                color: isActive ? Colors.green : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: ResponsiveHelper.getIconSize(context, 20)),
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
        margin: EdgeInsets.symmetric(vertical: ResponsiveHelper.getSpacing(context, 8)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
              child: Column(
                children: [
                  _buildActionButton(
                    context: context,
                    title: 'Create Subsection',
                    subtitle: 'Add rooms, shops, or specific spaces',
                    icon: Icons.room,
                    color: Colors.orange,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubsectionListScreen(
                          premise: widget.premise,
                          section: widget.section,
                          sectionId: widget.section.id, // ✅ Pass the actual section ID
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
                      // Fetch subsections for the current section
                      // final subsections = await _supabaseService.getSubsections(widget.section.id);
                      // if (subsections.isEmpty) {
                      //   ScaffoldMessenger.of(context).showSnackBar(
                      //     const SnackBar(content: Text('No subsections available. Please create a subsection first.')),
                      //   );
                      //   return;
                      // }
                      // Navigate to SubsectionSelectionScreen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SectionProductsScreen(
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

    Widget _buildSubsectionsList() {
      return FutureBuilder<List<Subsection>>(
        future: _supabaseService.getSubsections(widget.section.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading subsections',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveHelper.getFontSize(context, 16),
                  color: ThemeHelper.textSecondary,
                ),
              ),
            );
          }
          final subsections = snapshot.data ?? [];
          if (subsections.isEmpty) {
            return Center(
              child: Column(
                children: [
                  Icon(
                    Icons.room_outlined,
                    size: ResponsiveHelper.getIconSize(context, 64),
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context, 24)),
                  Text(
                    'No Subsections Available',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.getFontSize(context, 20),
                      fontWeight: FontWeight.w600,
                      color: ThemeHelper.textPrimary,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.getSpacing(context, 8)),
                  Text(
                    'Create a subsection to organize your section.',
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
                        builder: (context) => CreateSubsectionScreen(
                          premise: widget.premise,
                          sectionId: widget.section.id,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.getUniformPadding(context),
                        vertical: ResponsiveHelper.getUniformPadding(context) / 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Create Subsection',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 16),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subsections',
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
                itemCount: subsections.length,
                itemBuilder: (context, index) {
                  final subsection = subsections[index];
                  return _buildSubsectionCard(subsection);
                },
              ),
            ],
          );
        },
      );
    }

    Widget _buildSubsectionCard(Subsection subsection) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubsectionListScreen(
                  premise: widget.premise,
                  section: widget.section,
                  sectionId: '',
                ),
              ),
            );
          },
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
                      Text(
                        'In ${widget.section.name}',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 14),
                          color: ThemeHelper.textSecondary,
                        ),
                      ),
                      if (subsection.additionalData?['location'] != null)
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: ResponsiveHelper.getIconSize(context, 14),
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: ResponsiveHelper.getSpacing(context, 4)),
                            Text(
                              subsection.additionalData!['location'].toString(),
                              style: GoogleFonts.poppins(
                                fontSize: ResponsiveHelper.getFontSize(context, 12),
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
                  size: ResponsiveHelper.getIconSize(context, 16),
                  color: Colors.grey.shade400,
                ),
              ],
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
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 1.5),
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
                        'In Subsection', // Replace with actual subsection name if available
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 14),
                          color: ThemeHelper.textSecondary,
                        ),
                      ),
                      // if (product.additionalData?['location'] != null)
                      //   Row(
                      //     children: [
                      //       Icon(
                      //         Icons.location_on,
                      //         size: ResponsiveHelper.getIconSize(context, 14),
                      //         color: Colors.grey.shade600,
                      //       ),
                      //       SizedBox(width: ResponsiveHelper.getSpacing(context, 4)),
                      //       Text(
                      //         product.additionalData!['location'].toString(),
                      //         style: GoogleFonts.poppins(
                      //           fontSize: ResponsiveHelper.getFontSize(context, 12),
                      //           color: Colors.grey.shade600,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
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

    // Widget _buildDetailsCard() {
    //   final additionalData = widget.section.additionalData != null
    //       ? Map<String, dynamic>.from(widget.section.additionalData!.cast<String, dynamic>())
    //       : <String, dynamic>{};
    //   additionalData.remove('name');
    //   additionalData.remove('location');
    //
    //   if (additionalData.isEmpty) {
    //     return const SizedBox.shrink();
    //   }

      // return Column(
      //   crossAxisAlignment: CrossAxisAlignment.start,
      //   children: [
      //     Text(
      //       'Additional Details',
      //       style: GoogleFonts.poppins(
      //         fontSize: ResponsiveHelper.getFontSize(context, 20),
      //         fontWeight: FontWeight.w600,
      //         color: ThemeHelper.textPrimary,
      //       ),
      //     ),
      //     SizedBox(height: ResponsiveHelper.getSpacing(context, 12)),
      //     Card(
      //       elevation: 4,
      //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      //       child: Padding(
      //         padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
      //         child: Column(
      //           children: additionalData.entries.map((entry) {
      //             return Container(
      //               margin: EdgeInsets.only(bottom: ResponsiveHelper.getSpacing(context, 12)),
      //               padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context)),
      //               decoration: BoxDecoration(
      //                 color: Colors.grey.shade50,
      //                 borderRadius: BorderRadius.circular(12),
      //                 border: Border.all(color: Colors.grey.shade200),
      //               ),
      //               child: Row(
      //                 crossAxisAlignment: CrossAxisAlignment.start,
      //                 children: [
      //                   Container(
      //                     padding: EdgeInsets.all(ResponsiveHelper.getUniformPadding(context) / 2),
      //                     decoration: BoxDecoration(
      //                       color: Colors.green.withOpacity(0.1),
      //                       borderRadius: BorderRadius.circular(8),
      //                     ),
      //                     child: Icon(
      //                       Icons.info_outline,
      //                       color: Colors.green,
      //                       size: ResponsiveHelper.getIconSize(context, 16),
      //                     ),
      //                   ),
      //                   SizedBox(width: ResponsiveHelper.getSpacing(context, 12)),
      //                   Expanded(
      //                     child: Column(
      //                       crossAxisAlignment: CrossAxisAlignment.start,
      //                       children: [
      //                         Text(
      //                           entry.key.toUpperCase(),
      //                           style: GoogleFonts.poppins(
      //                             fontSize: ResponsiveHelper.getFontSize(context, 12),
      //                             fontWeight: FontWeight.w600,
      //                             color: ThemeHelper.textSecondary,
      //                             letterSpacing: 0.5,
      //                           ),
      //                         ),
      //                         SizedBox(height: ResponsiveHelper.getSpacing(context, 4)),
      //                         Text(
      //                           entry.value?.toString() ?? 'N/A',
      //                           style: GoogleFonts.poppins(
      //                             fontSize: ResponsiveHelper.getFontSize(context, 16),
      //                             fontWeight: FontWeight.w500,
      //                             color: ThemeHelper.textPrimary,
      //                           ),
      //                         ),
      //                       ],
      //                     ),
      //                   ),
      //                 ],
      //               ),
      //             );
      //           }).toList(),
      //         ),
      //       ),
      //     ),
      //   ],
      // );
    }

    // void _showComingSoonDialog(String feature) {
    //   showDialog(
    //     context: context,
    //     builder: (BuildContext context) {
    //       return AlertDialog(
    //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    //         title: Row(
    //           children: [
    //             Icon(Icons.construction, color: Colors.orange),
    //             SizedBox(width: ResponsiveHelper.getSpacing(context, 12)),
    //             Text(
    //               'Coming Soon',
    //               style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
    //             ),
    //           ],
    //         ),
    //         content: Text(
    //           '$feature functionality is currently under development and will be available soon!',
    //           style: GoogleFonts.poppins(),
    //         ),
    //         actions: [
    //           TextButton(
    //             onPressed: () => Navigator.of(context).pop(),
    //             child: Text(
    //               'Got it',
    //               style: GoogleFonts.poppins(
    //                 color: Colors.green,
    //                 fontWeight: FontWeight.w600,
    //               ),
    //             ),
    //           ),
    //         ],
    //       );
    //     },
    //   );
    // }
