import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/area_inspection_service.dart';

class AreaInspectionStatusScreen extends StatefulWidget {
  const AreaInspectionStatusScreen({super.key});

  @override
  State<AreaInspectionStatusScreen> createState() =>
      _AreaInspectionStatusScreenState();
}

class _AreaInspectionStatusScreenState
    extends State<AreaInspectionStatusScreen> {
  final _areaInspectionService = AreaInspectionService();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _areas = [];
  bool _isLoading = true;
  String _selectedStatus = 'all';
  String _selectedSection = 'all';

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      print('Current user email: ${user.email}'); // Debug print

      // Get contractor ID
      final contractorResponse =
          await _supabase
              .from('contractor')
              .select('id, email, name')
              .eq('email', user.email!)
              .maybeSingle();

      print('Contractor response: $contractorResponse'); // Debug print

      if (contractorResponse == null) {
        // Try to get all contractors to see what's in the table
        final allContractors = await _supabase
            .from('contractor')
            .select('id, email, name')
            .limit(5);
        print('First 5 contractors: $allContractors'); // Debug print
        throw Exception(
          'Contractor not found. Please ensure you are logged in as a contractor.',
        );
      }

      final contractorId = contractorResponse['id'];
      print('Found contractor ID: $contractorId'); // Debug print

      final areas = await _areaInspectionService.getAreasWithInspectionStatus(
        contractorId,
      );

      print('Found ${areas.length} areas'); // Debug print

      setState(() {
        _areas = areas;
        _isLoading = false;
      });
    } catch (e) {
      print('Error in _loadAreas: $e'); // Debug print
      setState(() {
        _isLoading = false;
        _areas = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading areas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredAreas {
    return _areas.where((area) {
      final assignments = (area['area_assignments'] as List?) ?? [];
      if (assignments.isEmpty) return false;

      if (_selectedStatus != 'all') {
        final hasMatchingStatus = assignments.any((assignment) {
          final inspectionStatus =
              assignment['inspection_status'] as String? ?? 'pending';
          final assignmentType = assignment['assignment_type'] as String? ?? '';

          if (_selectedSection == 'all') {
            return inspectionStatus == _selectedStatus;
          } else {
            return assignmentType == _selectedSection &&
                inspectionStatus == _selectedStatus;
          }
        });

        if (!hasMatchingStatus) return false;
      }

      if (_selectedSection != 'all') {
        final hasMatchingSection = assignments.any((assignment) {
          final assignmentType = assignment['assignment_type'] as String? ?? '';
          return assignmentType == _selectedSection;
        });

        if (!hasMatchingSection) return false;
      }

      return true;
    }).toList();
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required String selectedValue,
    required Function(String) onSelected,
  }) {
    final isSelected = value == selectedValue;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onSelected(value);
        }
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Area Inspection Status',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter by Status',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip(
                              label: 'All',
                              value: 'all',
                              selectedValue: _selectedStatus,
                              onSelected: (value) {
                                setState(() {
                                  _selectedStatus = value;
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: 'Completed',
                              value: 'completed',
                              selectedValue: _selectedStatus,
                              onSelected: (value) {
                                setState(() {
                                  _selectedStatus = value;
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: 'Pending',
                              value: 'pending',
                              selectedValue: _selectedStatus,
                              onSelected: (value) {
                                setState(() {
                                  _selectedStatus = value;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Filter by Section',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip(
                              label: 'All Sections',
                              value: 'all',
                              selectedValue: _selectedSection,
                              onSelected: (value) {
                                setState(() {
                                  _selectedSection = value;
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: 'Pump Floor',
                              value: 'pumps_floor',
                              selectedValue: _selectedSection,
                              onSelected: (value) {
                                setState(() {
                                  _selectedSection = value;
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: 'Building Fire',
                              value: 'building_fire',
                              selectedValue: _selectedSection,
                              onSelected: (value) {
                                setState(() {
                                  _selectedSection = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
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
                                    Icons.assignment_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No Areas Found',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your filters',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : RefreshIndicator(
                              onRefresh: _loadAreas,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _filteredAreas.length,
                                itemBuilder: (context, index) {
                                  final area = _filteredAreas[index];
                                  final assignments =
                                      (area['area_assignments'] as List?) ?? [];

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ExpansionTile(
                                      title: Text(
                                        area['name'] ?? 'Unnamed Area',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(
                                        area['description'] ?? 'No description',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      children:
                                          assignments.map((assignment) {
                                            final freelancer =
                                                assignment['freelancers']
                                                    as Map<String, dynamic>?;
                                            return ListTile(
                                              title: Text(
                                                freelancer?['name'] ??
                                                    'Unknown Freelancer',
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              subtitle: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Assignment Type: ${assignment['assignment_type'] ?? 'Unknown'}',
                                                    style: GoogleFonts.poppins(
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Inspection Status',
                                                              style: GoogleFonts.poppins(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors
                                                                        .grey[600],
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            _buildStatusChip(
                                                              assignment['inspection_status'] ??
                                                                  'pending',
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                    ),
                                  );
                                },
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}
