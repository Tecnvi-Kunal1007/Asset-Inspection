import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/area_assignment_service.dart';

class AreaAssignmentHistoryScreen extends StatefulWidget {
  const AreaAssignmentHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AreaAssignmentHistoryScreen> createState() =>
      _AreaAssignmentHistoryScreenState();
}

class _AreaAssignmentHistoryScreenState
    extends State<AreaAssignmentHistoryScreen> {
  final _areaAssignmentService = AreaAssignmentService();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _assignments = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Active', 'Inactive'];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get contractor ID
      final contractorResponse =
          await _supabase
              .from('contractor')
              .select('id')
              .eq('email', user.email!)
              .maybeSingle();

      if (contractorResponse == null) throw Exception('Contractor not found');
      final contractorId = contractorResponse['id'];

      // Get all areas for this contractor
      final areasResponse = await _supabase
          .from('areas')
          .select('id')
          .eq('contractor_id', contractorId);

      if (areasResponse == null || areasResponse.isEmpty) {
        setState(() {
          _assignments = [];
          _isLoading = false;
        });
        return;
      }

      final areaIds =
          (areasResponse as List).map((area) => area['id'] as String).toList();

      // Get current assignments for all areas
      final assignments = await _supabase
          .from('area_assignments')
          .select('''
            *,
            areas (
              id,
              name,
              site_location
            )
          ''')
          .filter('area_id', 'in', areaIds)
          .order('assigned_at', ascending: false);

      if (assignments == null || assignments.isEmpty) {
        setState(() {
          _assignments = [];
          _isLoading = false;
        });
        return;
      }

      // Process assignments to ensure correct status and fetch additional details
      final processedAssignments = await Future.wait(
        (assignments as List).map((assignment) async {
          final Map<String, dynamic> processedAssignment =
              Map<String, dynamic>.from(assignment);

          // Set status based on the status field from the database
          processedAssignment['status'] =
              processedAssignment['status'] ?? 'inactive';

          // Get assigned user details
          if (processedAssignment['assigned_to_id'] != null) {
            try {
              final assignedToId = processedAssignment['assigned_to_id'];

              // Fetch user details from freelancers table
              final userDetails =
                  await _supabase
                      .from('freelancers')
                      .select('name, email, phone, role')
                      .eq('id', assignedToId)
                      .maybeSingle();

              if (userDetails != null) {
                processedAssignment['assigned_to_details'] = userDetails;
                // Set the type based on the role from freelancers table
                processedAssignment['assigned_to_type'] =
                    userDetails['role'] ?? 'freelancer';
              }
            } catch (e) {
              print('Error fetching assigned user details: $e');
            }
          }

          // Get assigned by (contractor) details
          if (processedAssignment['assigned_by_id'] != null) {
            try {
              final contractorDetails =
                  await _supabase
                      .from('contractor')
                      .select('name, email')
                      .eq('id', processedAssignment['assigned_by_id'])
                      .maybeSingle();

              if (contractorDetails != null) {
                processedAssignment['assigned_by_details'] = contractorDetails;
              }
            } catch (e) {
              print('Error fetching contractor details: $e');
            }
          }

          return processedAssignment;
        }),
      );

      setState(() {
        _assignments = List<Map<String, dynamic>>.from(processedAssignments);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading assignments: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      setState(() {
        _isLoading = false;
        _assignments = []; // Clear assignments on error
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredAssignments() {
    var filtered = _assignments;

    // Apply status filter
    if (_selectedFilter != 'All') {
      filtered =
          filtered.where((assignment) {
            return _selectedFilter == 'Active'
                ? assignment['status'] == 'active'
                : assignment['status'] == 'inactive';
          }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((assignment) {
            final areaName =
                (assignment['areas'] as Map<String, dynamic>)['name']
                    ?.toString()
                    .toLowerCase() ??
                '';
            return areaName.contains(_searchQuery.toLowerCase());
          }).toList();
    }

    return filtered;
  }

  String _getAssignmentTypeText(String type) {
    switch (type) {
      case 'pumps_floor':
        return 'Pumps & Floor Management';
      case 'building_fire':
        return 'Building Accessories & Fire Alarm Management';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAssignments = _getFilteredAssignments();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Area Assignment History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by area name...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.blue.shade700,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.blue.shade700),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      // Status Filter
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              _filters.map((filter) {
                                final isSelected = _selectedFilter == filter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(
                                      filter,
                                      style: GoogleFonts.poppins(
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : Colors.grey.shade700,
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedFilter = filter;
                                      });
                                    },
                                    backgroundColor: Colors.white,
                                    selectedColor: Colors.blue.shade700,
                                    checkmarkColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color:
                                            isSelected
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredAssignments.isEmpty
                      ? Center(
                        child: Text(
                          'No assignments found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredAssignments.length,
                        itemBuilder: (context, index) {
                          final assignment = filteredAssignments[index];
                          final area =
                              assignment['areas'] as Map<String, dynamic>;

                          return _buildAssignmentCard(assignment);
                        },
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadAssignments,
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildAssignmentCard(Map<String, dynamic> assignment) {
    final isActive = assignment['status'] == 'active';
    final assignedToDetails = assignment['assigned_to_details'];
    final assignedByDetails = assignment['assigned_by_details'];
    final areaDetails = assignment['areas'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? Colors.green.shade200 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isActive ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: GoogleFonts.poppins(
                      color:
                          isActive
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat(
                    'MMM dd, yyyy',
                  ).format(DateTime.parse(assignment['assigned_at'])),
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.location_on,
              'Area',
              areaDetails['name'] ?? 'Unknown Area',
              isActive ? Colors.green.shade700 : Colors.grey.shade700,
            ),
            _buildInfoRow(
              Icons.business,
              'Location',
              areaDetails['site_location'] ?? 'No location specified',
              isActive ? Colors.green.shade700 : Colors.grey.shade700,
            ),
            _buildInfoRow(
              Icons.assignment,
              'Assignment Type',
              assignment['assignment_type'] == 'pumps_floor'
                  ? 'Pumps & Floor Management'
                  : 'Building Accessories & Fire Alarm Management',
              isActive ? Colors.green.shade700 : Colors.grey.shade700,
            ),
            if (assignedToDetails != null) ...[
              const Divider(height: 24),
              Text(
                'Assigned To',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.person,
                'Name',
                assignedToDetails['name'] ?? 'Unknown',
                isActive ? Colors.green.shade700 : Colors.grey.shade700,
              ),
              _buildInfoRow(
                Icons.email,
                'Email',
                assignedToDetails['email'] ?? 'No email',
                isActive ? Colors.green.shade700 : Colors.grey.shade700,
              ),
              _buildInfoRow(
                Icons.phone,
                'Phone',
                assignedToDetails['phone'] ?? 'No phone',
                isActive ? Colors.green.shade700 : Colors.grey.shade700,
              ),
            ],
            if (assignedByDetails != null) ...[
              const Divider(height: 24),
              Text(
                'Assigned By',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.person,
                'Name',
                assignedByDetails['name'] ?? 'Unknown',
                isActive ? Colors.green.shade700 : Colors.grey.shade700,
              ),
              _buildInfoRow(
                Icons.email,
                'Email',
                assignedByDetails['email'] ?? 'No email',
                isActive ? Colors.green.shade700 : Colors.grey.shade700,
              ),
            ],
            const Divider(height: 24),
            _buildInfoRow(
              Icons.calendar_today,
              'Assigned',
              DateFormat(
                'MMM dd, yyyy HH:mm',
              ).format(DateTime.parse(assignment['assigned_at'])),
              isActive ? Colors.green.shade700 : Colors.grey.shade700,
            ),
            if (assignment['unassigned_at'] != null)
              _buildInfoRow(
                Icons.calendar_today,
                'Unassigned',
                DateFormat(
                  'MMM dd, yyyy HH:mm',
                ).format(DateTime.parse(assignment['unassigned_at'])),
                isActive ? Colors.green.shade700 : Colors.grey.shade700,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
