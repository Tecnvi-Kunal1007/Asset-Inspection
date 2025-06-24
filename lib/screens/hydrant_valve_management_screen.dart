import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hydrant_valve.dart';
import '../services/supabase_service.dart';

class HydrantValveManagementScreen extends StatefulWidget {
  final String floorId;
  final String floorType;

  const HydrantValveManagementScreen({
    super.key,
    required this.floorId,
    required this.floorType,
  });

  @override
  State<HydrantValveManagementScreen> createState() =>
      _HydrantValveManagementScreenState();
}

class _HydrantValveManagementScreenState
    extends State<HydrantValveManagementScreen> {
  final _supabaseService = SupabaseService();
  List<HydrantValve> _valves = [];
  bool _isLoading = true;
  String _selectedValveType = 'Single';
  String _selectedStatus = 'Working';
  bool _isAddingValve = false;

  @override
  void initState() {
    super.initState();
    _loadValves();
  }

  Future<void> _loadValves() async {
    try {
      final valves = await _supabaseService.getHydrantValvesByFloorId(
        widget.floorId,
      );
      setState(() {
        _valves = valves;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading valves: $e')));
      }
    }
  }

  Future<void> _addValve() async {
    setState(() {
      _isAddingValve = true;
    });

    try {
      await _supabaseService.createHydrantValve(
        widget.floorId,
        _selectedValveType,
        _selectedStatus,
      );
      await _loadValves();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valve added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding valve: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingValve = false;
        });
      }
    }
  }

  Future<void> _deleteValve(String valveId) async {
    try {
      await _supabaseService.deleteHydrantValve(valveId);
      await _loadValves();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valve deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting valve: $e')));
      }
    }
  }

  Future<void> _updateValve(
    String valveId,
    String valveType,
    String status,
  ) async {
    try {
      await _supabaseService.updateHydrantValve(valveId, valveType, status);
      await _loadValves();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Valve updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating valve: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hydrant Valves - ${widget.floorType}',
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
                              'Add New Valve',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedValveType,
                                    decoration: InputDecoration(
                                      labelText: 'Valve Type',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    items:
                                        ['Single', 'Double']
                                            .map(
                                              (type) => DropdownMenuItem(
                                                value: type,
                                                child: Text(type),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedValveType = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
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
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isAddingValve ? null : _addValve,
                                icon:
                                    _isAddingValve
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
                                  _isAddingValve ? 'Adding...' : 'Add Valve',
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
                      itemCount: _valves.length,
                      itemBuilder: (context, index) {
                        final valve = _valves[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: Icon(
                              valve.status == 'Working'
                                  ? Icons.check_circle
                                  : valve.status == 'Not Working'
                                  ? Icons.error
                                  : Icons.remove_circle,
                              color:
                                  valve.status == 'Working'
                                      ? Colors.green
                                      : valve.status == 'Not Working'
                                      ? Colors.red
                                      : Colors.orange,
                            ),
                            title: Text(
                              '${valve.valveType} Hydrant Valve',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Status: ${valve.status}',
                              style: GoogleFonts.poppins(
                                color:
                                    valve.status == 'Working'
                                        ? Colors.green
                                        : valve.status == 'Not Working'
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  _deleteValve(valve.id);
                                } else {
                                  _updateValve(
                                    valve.id,
                                    valve.valveType,
                                    value,
                                  );
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
