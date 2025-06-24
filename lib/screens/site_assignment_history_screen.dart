import 'package:flutter/material.dart';
import '../services/site_assignment_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class SiteAssignmentHistoryScreen extends StatefulWidget {
  final String siteId;
  final String siteName;

  const SiteAssignmentHistoryScreen({
    super.key,
    required this.siteId,
    required this.siteName,
  });

  @override
  State<SiteAssignmentHistoryScreen> createState() =>
      _SiteAssignmentHistoryScreenState();
}

class _SiteAssignmentHistoryScreenState
    extends State<SiteAssignmentHistoryScreen> {
  final _siteAssignmentService = SiteAssignmentService();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    try {
      // Get the current contractor's ID
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      List<Map<String, dynamic>> assignments;

      if (widget.siteId.isEmpty) {
        // Get all assignments for the contractor's sites
        assignments = await _siteAssignmentService.getAssignmentsByContractor(
          user.id,
        );
      } else {
        // Get assignments for specific site (after verifying ownership)
        final site =
            await _supabase
                .from('sites')
                .select()
                .eq('id', widget.siteId)
                .eq('contractor_id', user.id)
                .single();

        if (site == null) {
          throw Exception('Site not found or not owned by current contractor');
        }

        assignments = await _siteAssignmentService.getSiteAssignmentHistory(
          widget.siteId,
        );
      }

      // Fetch additional details for each assignment
      for (var assignment in assignments) {
        // Get freelancer details including role
        final freelancer =
            await _supabase
                .from('freelancers')
                .select('name, email, phone, role')
                .eq('id', assignment['assigned_to_id'])
                .single();

        assignment['assigned_to_details'] = freelancer;
        // Set the type based on the role from freelancers table
        assignment['assigned_to_type'] = freelancer['role'] ?? 'freelancer';

        // Get site details if viewing all assignments
        if (widget.siteId.isEmpty) {
          final site =
              await _supabase
                  .from('sites')
                  .select('site_name')
                  .eq('id', assignment['site_id'])
                  .single();
          assignment['site_details'] = site;
        }
      }

      setState(() {
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading assignments: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      setState(() {
        _isLoading = false;
        _assignments = []; // Clear assignments on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Assignment History - ${widget.siteName}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAssignments,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _assignments.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No assignment history found',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _assignments.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final assignment = _assignments[index];
                  final assignedToDetails =
                      assignment['assigned_to_details']
                          as Map<String, dynamic>?;
                  final siteDetails =
                      assignment['site_details'] as Map<String, dynamic>?;
                  final isActive = assignment['status'] == 'active';

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            isActive
                                ? Colors.green.shade50
                                : Colors.grey.shade50,
                            Colors.white,
                          ],
                        ),
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
                                    'Assigned to: ${assignedToDetails?['name'] ?? 'Unknown'}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isActive
                                            ? Colors.green.shade100
                                            : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color:
                                          isActive
                                              ? Colors.green.shade300
                                              : Colors.grey.shade400,
                                    ),
                                  ),
                                  child: Text(
                                    assignment['status'].toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color:
                                          isActive
                                              ? Colors.green.shade700
                                              : Colors.grey.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.badge,
                              'Type',
                              assignment['assigned_to_type'] == 'employee'
                                  ? 'Employee'
                                  : 'Freelancer',
                              isActive
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                            ),
                            if (assignedToDetails != null) ...[
                              _buildInfoRow(
                                Icons.email,
                                'Email',
                                assignedToDetails['email'],
                                isActive
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                              ),
                              _buildInfoRow(
                                Icons.phone,
                                'Phone',
                                assignedToDetails['phone'],
                                isActive
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                              ),
                            ],
                            const Divider(height: 24),
                            _buildInfoRow(
                              Icons.calendar_today,
                              'Assigned',
                              DateFormat('MMM dd, yyyy HH:mm').format(
                                DateTime.parse(assignment['assigned_at']),
                              ),
                              isActive
                                  ? Colors.green.shade700
                                  : Colors.grey.shade700,
                            ),
                            if (assignment['unassigned_at'] != null)
                              _buildInfoRow(
                                Icons.event_busy,
                                'Unassigned',
                                DateFormat('MMM dd, yyyy HH:mm').format(
                                  DateTime.parse(assignment['unassigned_at']),
                                ),
                                Colors.red.shade700,
                              ),
                            if (assignment['notes'] != null)
                              _buildInfoRow(
                                Icons.note,
                                'Notes',
                                assignment['notes'],
                                isActive
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.grey[800],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
