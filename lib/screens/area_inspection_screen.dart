import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/area_inspection_service.dart';

class AreaInspectionScreen extends StatefulWidget {
  const AreaInspectionScreen({super.key});

  @override
  State<AreaInspectionScreen> createState() => _AreaInspectionScreenState();
}

class _AreaInspectionScreenState extends State<AreaInspectionScreen> {
  final _areaInspectionService = AreaInspectionService();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _assignedAreas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedAreas();
  }

  Future<void> _loadAssignedAreas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final areas = await _areaInspectionService.getAssignedAreas(user.email!);
      setState(() {
        _assignedAreas = areas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _assignedAreas = [];
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

  Future<void> _markInspectionComplete(
    String areaId,
    String sectionType,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Get freelancer ID
      final freelancerResponse =
          await _supabase
              .from('freelancers')
              .select('id')
              .eq('email', user.email!)
              .maybeSingle();

      if (freelancerResponse == null) {
        throw Exception('Freelancer not found');
      }

      final freelancerId = freelancerResponse['id'];

      final success = await _areaInspectionService.markInspectionComplete(
        areaId,
        freelancerId,
        sectionType,
      );

      if (success) {
        // Refresh the list
        await _loadAssignedAreas();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inspection marked as complete'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to mark inspection as complete');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Area Inspections',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _assignedAreas.isEmpty
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
                      'No Areas Assigned',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have not been assigned any areas yet',
                      style: GoogleFonts.poppins(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadAssignedAreas,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _assignedAreas.length,
                  itemBuilder: (context, index) {
                    final area = _assignedAreas[index];
                    final areaData = area['areas'] as Map<String, dynamic>;
                    final assignmentType = area['assignment_type'] as String;
                    final inspectionStatus =
                        area['inspection_status'] as String? ?? 'pending';
                    final isCompleted = inspectionStatus == 'completed';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    areaData['name'] ?? 'Unnamed Area',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                _buildStatusChip(inspectionStatus),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              areaData['description'] ?? 'No description',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Assignment Type: ${assignmentType == 'pumps_floor' ? 'Pumps & Floor' : 'Building & Fire'}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (!isCompleted)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      () => _markInspectionComplete(
                                        areaData['id'],
                                        assignmentType,
                                      ),
                                  icon: const Icon(Icons.check_circle),
                                  label: Text(
                                    'Mark Inspection Complete',
                                    style: GoogleFonts.poppins(),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            if (isCompleted &&
                                area['inspection_completed_at'] != null)
                              Text(
                                'Completed on: ${DateTime.parse(area['inspection_completed_at']).toString().split('.')[0]}',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
