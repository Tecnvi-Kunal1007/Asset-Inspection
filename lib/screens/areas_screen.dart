import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/area.dart';
import '../services/supabase_service.dart';
import 'create_area_screen.dart';
import 'area_details_screen.dart';

class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  final _supabaseService = SupabaseService();
  List<Area> _areas = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  List<Area> _filteredAreas = [];

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Areas',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
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
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
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
                        hintText: 'Search sites...',
                        hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
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
                          borderSide: const BorderSide(
                            color: Colors.blue,
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
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No sites found',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredAreas.length,
                              itemBuilder: (context, index) {
                                final area = _filteredAreas[index];
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  AreaDetailsScreen(area: area),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  area.name,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                icon: Icon(
                                                  Icons.more_vert,
                                                  color: Colors.grey[600],
                                                ),
                                                itemBuilder:
                                                    (context) => [
                                                      PopupMenuItem(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons.edit,
                                                              size: 20,
                                                              color:
                                                                  Colors
                                                                      .grey[600],
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              'Edit',
                                                              style:
                                                                  GoogleFonts.poppins(),
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
                                                              color:
                                                                  Colors
                                                                      .red[400],
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Text(
                                                              'Delete',
                                                              style: GoogleFonts.poppins(
                                                                color:
                                                                    Colors
                                                                        .red[400],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                onSelected: (value) async {
                                                  if (value == 'edit') {
                                                    // TODO: Implement edit functionality
                                                  } else if (value ==
                                                      'delete') {
                                                    final confirm = await showDialog<
                                                      bool
                                                    >(
                                                      context: context,
                                                      builder:
                                                          (
                                                            context,
                                                          ) => AlertDialog(
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    16,
                                                                  ),
                                                            ),
                                                            title: Text(
                                                              'Delete Site',
                                                              style: GoogleFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                            content: Text(
                                                              'Are you sure you want to delete this site?',
                                                              style:
                                                                  GoogleFonts.poppins(),
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      false,
                                                                    ),
                                                                child: Text(
                                                                  'Cancel',
                                                                  style: GoogleFonts.poppins(
                                                                    color:
                                                                        Colors
                                                                            .grey[600],
                                                                  ),
                                                                ),
                                                              ),
                                                              ElevatedButton(
                                                                onPressed:
                                                                    () => Navigator.pop(
                                                                      context,
                                                                      true,
                                                                    ),
                                                                style: ElevatedButton.styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                                ),
                                                                child: Text(
                                                                  'Delete',
                                                                  style:
                                                                      GoogleFonts.poppins(),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                    );

                                                    if (confirm == true) {
                                                      try {
                                                        await _supabaseService
                                                            .deleteArea(
                                                              area.id,
                                                            );
                                                        _loadAreas();
                                                      } catch (e) {
                                                        if (!mounted) return;
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error deleting area: $e',
                                                            ),
                                                            behavior:
                                                                SnackBarBehavior
                                                                    .floating,
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    10,
                                                                  ),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            area.description,
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
