import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({Key? key}) : super(key: key);

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _freelancers = [];
  List<Map<String, dynamic>> _employees = [];
  final _taskController = TextEditingController();
  String? _selectedPersonId;
  String? _selectedPersonType;
  String? _selectedPersonName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

      // Load all people from freelancers table
      final peopleResponse = await _supabase
          .from('freelancers')
          .select('id, name, email, role')
          .eq('contractor_id', contractorId);

      // Separate into freelancers and employees based on role
      _freelancers =
          (peopleResponse as List)
              .where((person) => person['role'] == 'freelancer')
              .map((person) => person as Map<String, dynamic>)
              .toList();
      _employees =
          (peopleResponse as List)
              .where((person) => person['role'] == 'employee')
              .map((person) => person as Map<String, dynamic>)
              .toList();

      // Load tasks
      final tasksResponse = await _supabase
          .from('tasks')
          .select('''
            *,
            freelancers!assigned_to_id (
              id,
              name,
              role
            ),
            work_reports (
              id,
              equipment_name,
              work_description,
              replaced_parts,
              repair_date,
              next_due_date,
              work_photo_url,
              finished_photo_url,
              geotagged_photo_url,
              location_address,
              latitude,
              longitude,
              created_at,
              updated_at,
              qr_code_data
            )
          ''')
          .eq('contractor_id', contractorId)
          .order('created_at', ascending: false);
      _tasks = List<Map<String, dynamic>>.from(tasksResponse);

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _assignTask() async {
    if (_taskController.text.isEmpty ||
        _selectedPersonId == null ||
        _selectedPersonType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a person and enter task description'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final contractorResponse =
          await _supabase
              .from('contractor')
              .select('id')
              .eq('email', user.email!)
              .maybeSingle();

      if (contractorResponse == null) throw Exception('Contractor not found');
      final contractorId = contractorResponse['id'];

      await _supabase.from('tasks').insert({
        'id': const Uuid().v4(),
        'contractor_id': contractorId,
        'assigned_to_id': _selectedPersonId,
        'assigned_to_type': _selectedPersonType,
        'task_description': _taskController.text,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      _taskController.clear();
      _selectedPersonId = null;
      _selectedPersonType = null;
      _selectedPersonName = null;
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task assigned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error assigning task: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPersonSelectionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            title: Text(
              'Select Person',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_freelancers.isNotEmpty) ...[
                      Text(
                        'Freelancers',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._freelancers.map(
                        (freelancer) => ListTile(
                          title: Text(freelancer['name']),
                          subtitle: Text(freelancer['email']),
                          onTap: () {
                            setState(() {
                              _selectedPersonId = freelancer['id'];
                              _selectedPersonType = 'freelancer';
                              _selectedPersonName = freelancer['name'];
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const Divider(),
                    ],
                    if (_employees.isNotEmpty) ...[
                      Text(
                        'Employees',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._employees.map(
                        (employee) => ListTile(
                          title: Text(employee['name']),
                          subtitle: Text(employee['email']),
                          onTap: () {
                            setState(() {
                              _selectedPersonId = employee['id'];
                              _selectedPersonType = 'employee';
                              _selectedPersonName = employee['name'];
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Task Management',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.blue.shade700,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assign New Task',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: _showPersonSelectionDialog,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedPersonName ?? 'Select Person',
                                        style: GoogleFonts.poppins(
                                          color:
                                              _selectedPersonName != null
                                                  ? Colors.black
                                                  : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: Colors.grey.shade600,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _taskController,
                              decoration: InputDecoration(
                                labelText: 'Task Description',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _assignTask,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Assign Task',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Assigned Tasks',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        final assigneeName = task['freelancers']['name'];
                        final assigneeRole = task['freelancers']['role'];
                        final workReport =
                            task['work_reports'] != null &&
                                    (task['work_reports'] as List).isNotEmpty
                                ? (task['work_reports'] as List).first
                                : null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            title: Text(
                              task['task_description'],
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned to: $assigneeName (${assigneeRole})',
                                ),
                                Text(
                                  'Status: ${task['status']}',
                                  style: TextStyle(
                                    color:
                                        task['status'] == 'completed'
                                            ? Colors.green
                                            : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Created: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(task['created_at']))}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (task['completed_at'] != null)
                                  Text(
                                    'Completed: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(task['completed_at']))}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                              ],
                            ),
                            trailing:
                                task['status'] == 'pending'
                                    ? IconButton(
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      color: Colors.green,
                                      onPressed: () async {
                                        await _supabase
                                            .from('tasks')
                                            .update({
                                              'status': 'completed',
                                              'completed_at':
                                                  DateTime.now()
                                                      .toIso8601String(),
                                            })
                                            .eq('id', task['id']);
                                        await _loadData();
                                      },
                                    )
                                    : const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Divider(),
                                    const SizedBox(height: 16),
                                    if (workReport != null) ...[
                                      Text(
                                        'Work Report',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildInfoRow(
                                        'Equipment',
                                        workReport['equipment_name'],
                                      ),
                                      const SizedBox(height: 8),
                                      _buildInfoRow(
                                        'Work Description',
                                        workReport['work_description'],
                                      ),
                                      const SizedBox(height: 8),
                                      _buildInfoRow(
                                        'Replaced Parts',
                                        workReport['replaced_parts'],
                                      ),
                                      const SizedBox(height: 8),
                                      _buildInfoRow(
                                        'Repair Date',
                                        DateFormat('MMM dd, yyyy').format(
                                          DateTime.parse(
                                            workReport['repair_date'],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildInfoRow(
                                        'Next Due Date',
                                        DateFormat('MMM dd, yyyy').format(
                                          DateTime.parse(
                                            workReport['next_due_date'],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildInfoRow(
                                        'Report Created',
                                        DateFormat('MMM dd, yyyy HH:mm').format(
                                          DateTime.parse(
                                            workReport['created_at'],
                                          ),
                                        ),
                                      ),
                                      if (workReport['updated_at'] != null) ...[
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                          'Report Updated',
                                          DateFormat(
                                            'MMM dd, yyyy HH:mm',
                                          ).format(
                                            DateTime.parse(
                                              workReport['updated_at'],
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (workReport['qr_code_data'] !=
                                          null) ...[
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                          'QR Code Data',
                                          workReport['qr_code_data'],
                                        ),
                                      ],
                                      if (workReport['work_photo_url'] !=
                                          null) ...[
                                        const SizedBox(height: 16),
                                        _buildPhotoSection(
                                          'Work Photo',
                                          workReport['work_photo_url'],
                                        ),
                                      ],
                                      if (workReport['finished_photo_url'] !=
                                          null) ...[
                                        const SizedBox(height: 16),
                                        _buildPhotoSection(
                                          'Finished Photo',
                                          workReport['finished_photo_url'],
                                        ),
                                      ],
                                      if (workReport['geotagged_photo_url'] !=
                                          null) ...[
                                        const SizedBox(height: 16),
                                        _buildPhotoSection(
                                          'Geotagged Photo',
                                          workReport['geotagged_photo_url'],
                                          locationAddress:
                                              workReport['location_address'],
                                          latitude: workReport['latitude'],
                                          longitude: workReport['longitude'],
                                        ),
                                      ],
                                    ] else ...[
                                      Text(
                                        'Task Details',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        task['status'] == 'pending'
                                            ? 'This task is still pending. Work report will be available once the task is completed.'
                                            : 'No work report available for this task.',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(child: Text(value, style: GoogleFonts.poppins())),
      ],
    );
  }

  Widget _buildPhotoSection(
    String label,
    String url, {
    String? locationAddress,
    double? latitude,
    double? longitude,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Icon(Icons.error),
              );
            },
          ),
        ),
        if (locationAddress != null ||
            (latitude != null && longitude != null)) ...[
          const SizedBox(height: 8),
          if (locationAddress != null)
            Text(
              'Location: $locationAddress',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          if (latitude != null && longitude != null)
            Text(
              'Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }
}
