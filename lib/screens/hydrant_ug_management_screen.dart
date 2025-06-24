import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hydrant_ug.dart';
import '../services/supabase_service.dart';

class HydrantUGManagementScreen extends StatefulWidget {
  final String floorId;
  final String floorType;

  const HydrantUGManagementScreen({
    super.key,
    required this.floorId,
    required this.floorType,
  });

  @override
  State<HydrantUGManagementScreen> createState() =>
      _HydrantUGManagementScreenState();
}

class _HydrantUGManagementScreenState extends State<HydrantUGManagementScreen> {
  final _supabaseService = SupabaseService();
  List<HydrantUG> _ugs = [];
  bool _isLoading = true;
  String _selectedStatus = 'Working';
  bool _isAddingUG = false;

  @override
  void initState() {
    super.initState();
    _loadUGs();
  }

  Future<void> _loadUGs() async {
    try {
      final ugs = await _supabaseService.getHydrantUGsByFloorId(widget.floorId);
      setState(() {
        _ugs = ugs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading UGs: $e')));
      }
    }
  }

  Future<void> _addUG() async {
    setState(() {
      _isAddingUG = true;
    });

    try {
      await _supabaseService.createHydrantUG(widget.floorId, _selectedStatus);
      await _loadUGs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hydrant UG added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding UG: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingUG = false;
        });
      }
    }
  }

  Future<void> _deleteUG(String ugId) async {
    try {
      await _supabaseService.deleteHydrantUG(ugId);
      await _loadUGs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hydrant UG deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting UG: $e')));
      }
    }
  }

  Future<void> _updateUG(String ugId, String status) async {
    try {
      await _supabaseService.updateHydrantUG(ugId, status);
      await _loadUGs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hydrant UG updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating UG: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hydrant UGs - ${widget.floorType}',
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
                              'Add New Hydrant UG',
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
                                onPressed: _isAddingUG ? null : _addUG,
                                icon:
                                    _isAddingUG
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
                                  _isAddingUG ? 'Adding...' : 'Add Hydrant UG',
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
                      itemCount: _ugs.length,
                      itemBuilder: (context, index) {
                        final ug = _ugs[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Icon(
                              ug.status == 'Working'
                                  ? Icons.check_circle
                                  : ug.status == 'Not Working'
                                  ? Icons.error
                                  : Icons.remove_circle,
                              color:
                                  ug.status == 'Working'
                                      ? Colors.green
                                      : ug.status == 'Not Working'
                                      ? Colors.red
                                      : Colors.orange,
                            ),
                            title: Text(
                              'Hydrant UG',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Status: ${ug.status}',
                              style: GoogleFonts.poppins(
                                color:
                                    ug.status == 'Working'
                                        ? Colors.green
                                        : ug.status == 'Not Working'
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteUG(ug.id);
                                } else {
                                  _updateUG(ug.id, value);
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
