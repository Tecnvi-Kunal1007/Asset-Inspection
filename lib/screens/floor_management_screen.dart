import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/floor.dart';
import '../services/supabase_service.dart';
import 'hydrant_valve_management_screen.dart';
import 'hydrant_ug_management_screen.dart';
import 'hydrant_wheel_management_screen.dart';

class FloorManagementScreen extends StatefulWidget {
  final String siteId;

  const FloorManagementScreen({super.key, required this.siteId});

  @override
  State<FloorManagementScreen> createState() => _FloorManagementScreenState();
}

class _FloorManagementScreenState extends State<FloorManagementScreen> {
  final _supabaseService = SupabaseService();
  List<Floor> _floors = [];
  bool _isLoading = true;
  final _floorTypeController = TextEditingController();
  bool _isAddingFloor = false;

  @override
  void initState() {
    super.initState();
    _loadFloors();
  }

  @override
  void dispose() {
    _floorTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadFloors() async {
    try {
      final floors = await _supabaseService.getFloorsBySiteId(widget.siteId);
      setState(() {
        _floors = floors;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading floors: $e')));
      }
    }
  }

  Future<void> _addFloor() async {
    if (_floorTypeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter floor type')));
      return;
    }

    setState(() {
      _isAddingFloor = true;
    });

    try {
      await _supabaseService.createFloor(
        widget.siteId,
        _floorTypeController.text.trim(),
      );
      _floorTypeController.clear();
      await _loadFloors();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Floor added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding floor: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingFloor = false;
        });
      }
    }
  }

  Future<void> _deleteFloor(String floorId) async {
    try {
      await _supabaseService.deleteFloor(floorId);
      await _loadFloors();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Floor deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting floor: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Floor Management', style: GoogleFonts.poppins()),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _floorTypeController,
                            decoration: InputDecoration(
                              hintText:
                                  'Enter floor type (e.g., Parking, Floor 1)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _isAddingFloor ? null : _addFloor,
                          icon:
                              _isAddingFloor
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : const Icon(Icons.add),
                          label: Text(
                            _isAddingFloor ? 'Adding...' : 'Add Floor',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _floors.length,
                      itemBuilder: (context, index) {
                        final floor = _floors[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.layers),
                            title: Text(
                              floor.floorType,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.plumbing,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                HydrantValveManagementScreen(
                                                  floorId: floor.id,
                                                  floorType: floor.floorType,
                                                ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.water_drop,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                HydrantUGManagementScreen(
                                                  floorId: floor.id,
                                                  floorType: floor.floorType,
                                                ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.settings,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                HydrantWheelManagementScreen(
                                                  floorId: floor.id,
                                                  floorType: floor.floorType,
                                                ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _deleteFloor(floor.id),
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
