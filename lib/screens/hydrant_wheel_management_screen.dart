import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hydrant_wheel.dart';
import '../services/supabase_service.dart';

class HydrantWheelManagementScreen extends StatefulWidget {
  final String floorId;
  final String floorType;

  const HydrantWheelManagementScreen({
    super.key,
    required this.floorId,
    required this.floorType,
  });

  @override
  State<HydrantWheelManagementScreen> createState() =>
      _HydrantWheelManagementScreenState();
}

class _HydrantWheelManagementScreenState
    extends State<HydrantWheelManagementScreen> {
  final _supabaseService = SupabaseService();
  List<HydrantWheel> _wheels = [];
  bool _isLoading = true;
  String _selectedStatus = 'Working';
  bool _isAddingWheel = false;

  @override
  void initState() {
    super.initState();
    _loadWheels();
  }

  Future<void> _loadWheels() async {
    try {
      final wheels = await _supabaseService.getHydrantWheelsByFloorId(
        widget.floorId,
      );
      setState(() {
        _wheels = wheels;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading wheels: $e')));
      }
    }
  }

  Future<void> _addWheel() async {
    setState(() {
      _isAddingWheel = true;
    });

    try {
      await _supabaseService.createHydrantWheel(
        widget.floorId,
        _selectedStatus,
      );
      await _loadWheels();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hydrant Wheel added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding wheel: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingWheel = false;
        });
      }
    }
  }

  Future<void> _deleteWheel(String wheelId) async {
    try {
      await _supabaseService.deleteHydrantWheel(wheelId);
      await _loadWheels();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hydrant Wheel deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting wheel: $e')));
      }
    }
  }

  Future<void> _updateWheel(String wheelId, String status) async {
    try {
      await _supabaseService.updateHydrantWheel(wheelId, status);
      await _loadWheels();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hydrant Wheel updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating wheel: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hydrant Wheels - ${widget.floorType}',
          style: GoogleFonts.poppins(),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add New Hydrant Wheel',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              items:
                                  ['Working', 'Not Working', 'Missing']
                                      .map(
                                        (status) => DropdownMenuItem(
                                          value: status,
                                          child: Text(status),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedStatus = value;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isAddingWheel ? null : _addWheel,
                                icon:
                                    _isAddingWheel
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                        : const Icon(Icons.add),
                                label: Text(
                                  _isAddingWheel
                                      ? 'Adding...'
                                      : 'Add Hydrant Wheel',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _wheels.length,
                      itemBuilder: (context, index) {
                        final wheel = _wheels[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Icon(
                              wheel.status == 'Working'
                                  ? Icons.check_circle
                                  : wheel.status == 'Not Working'
                                  ? Icons.error
                                  : Icons.remove_circle,
                              color:
                                  wheel.status == 'Working'
                                      ? Colors.green
                                      : wheel.status == 'Not Working'
                                      ? Colors.red
                                      : Colors.orange,
                            ),
                            title: Text(
                              'Hydrant Wheel',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Status: ${wheel.status}',
                              style: GoogleFonts.poppins(
                                color:
                                    wheel.status == 'Working'
                                        ? Colors.green
                                        : wheel.status == 'Not Working'
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteWheel(wheel.id);
                                } else {
                                  _updateWheel(wheel.id, value);
                                }
                              },
                              itemBuilder:
                                  (context) => [
                                    const PopupMenuItem(
                                      value: 'Working',
                                      child: Text('Mark as Working'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'Not Working',
                                      child: Text('Mark as Not Working'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'Missing',
                                      child: Text('Mark as Missing'),
                                    ),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
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
