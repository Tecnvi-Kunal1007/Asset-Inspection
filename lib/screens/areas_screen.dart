import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/area.dart';
import '../services/supabase_service.dart';
import 'create_area_screen.dart';
import 'area_details_screen.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import 'dart:math' as math;

class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> with SingleTickerProviderStateMixin {
  final _supabaseService = SupabaseService();
  List<Area> _areas = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  List<Area> _filteredAreas = [];
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadAreas();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _filterAreas(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAreas = List.from(_areas);
      } else {
        _filteredAreas =
            _areas
                .where(
                  (area) =>
                      area.name.toLowerCase().contains(query.toLowerCase()) ||
                      area.description.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
      }
    });
  }

  Future<void> _loadAreas() async {
    try {
      final areas = await _supabaseService.getAreas();
      setState(() {
        _areas = areas;
        _filteredAreas = List.from(areas);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeHelper.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ThemeHelper.primaryBlue,
        title: Text(
          'Areas',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.getFontSize(context, 24),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: ThemeHelper.blueGradient,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateAreaScreen(),
                ),
              );
              if (result == true) {
                _loadAreas();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background decorations
          Positioned(
            top: -50,
            left: -30,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animationController.value * 2 * math.pi,
                  child: ThemeHelper.floatingElement(
                    size: 150,
                    color: ThemeHelper.primaryBlue,
                    opacity: 0.05,
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 100,
            right: -20,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: -_animationController.value * 2 * math.pi,
                  child: ThemeHelper.floatingElement(
                    size: 180,
                    color: ThemeHelper.purple,
                    opacity: 0.04,
                  ),
                );
              },
            ),
          ),
          
          // Main content
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                ),
              )
              : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search areas...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: ThemeHelper.primaryBlue),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: ThemeHelper.primaryBlue,
                            width: 1,
                          ),
                        ),
                      ),
                      onChanged: _filterAreas,
                    ),
                  ),
                  Expanded(
                    child:
                        _filteredAreas.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: ResponsiveHelper.getFontSize(context, 64),
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No areas found',
                                    style: GoogleFonts.poppins(
                                      fontSize: ResponsiveHelper.getFontSize(context, 18),
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ResponsiveHelper.responsiveWidget(
                                context: context,
                                mobile: _buildAreasList(),
                                tablet: _buildAreasGrid(2),
                                desktop: _buildAreasGrid(3),
                              ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
  
  Widget _buildAreasList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredAreas.length,
      itemBuilder: (context, index) {
        return _buildAreaCard(_filteredAreas[index], index);
      },
    );
  }
  
  Widget _buildAreasGrid(int crossAxisCount) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: _filteredAreas.length,
      itemBuilder: (context, index) {
        return _buildAreaCard(_filteredAreas[index], index);
      },
    );
  }
  
  Widget _buildAreaCard(Area area, int index) {
    final color = ThemeHelper.getColorByIndex(index);
    final gradient = ThemeHelper.getGradientByIndex(index);
    final iconData = _getIconForArea(area);
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      shadowColor: color.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AreaDetailsScreen(area: area),
            ),
          ).then((_) => _loadAreas());
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.white.withOpacity(0.9)],
            ),
          ),
          child: Stack(
            children: [
              // Background accent icon
              Positioned(
                right: -15,
                bottom: -15,
                child: Icon(
                  iconData,
                  size: 100,
                  color: color.withOpacity(0.07),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Title with icon
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: gradient,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: ThemeHelper.coloredShadow(color),
                              ),
                              child: Icon(
                                iconData,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                area.name,
                                style: GoogleFonts.poppins(
                                  fontSize: ResponsiveHelper.getFontSize(context, 18),
                                  fontWeight: FontWeight.w600,
                                  color: ThemeHelper.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        
                        // Menu button
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: ThemeHelper.textSecondary,
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: ThemeHelper.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Edit',
                                    style: GoogleFonts.poppins(),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red[400],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: GoogleFonts.poppins(
                                      color: Colors.red[400],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'edit') {
                              // TODO: Implement edit functionality
                            } else if (value == 'delete') {
                              _showDeleteConfirmation(area);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      area.description,
                      style: GoogleFonts.poppins(
                        color: ThemeHelper.textSecondary,
                        fontSize: ResponsiveHelper.getFontSize(context, 14),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    
                    // Explore button
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AreaDetailsScreen(area: area),
                            ),
                          ).then((_) => _loadAreas());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Explore',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: ResponsiveHelper.getFontSize(context, 14),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward, size: 16),
                          ],
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
  
  IconData _getIconForArea(Area area) {
    // Generate a consistent icon based on the area name
    final nameHash = area.name.hashCode.abs();
    final icons = [
      Icons.location_city,
      Icons.apartment,
      Icons.business,
      Icons.home_work,
      Icons.domain,
      Icons.landscape,
      Icons.location_on,
      Icons.map,
    ];
    
    return icons[nameHash % icons.length];
  }
  
  Future<void> _showDeleteConfirmation(Area area) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Delete Area',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete this area?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: ThemeHelper.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabaseService.deleteArea(area.id);
        _loadAreas();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting area: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}
