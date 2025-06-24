import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/floor.dart';
import '../services/supabase_service.dart';
import 'fire_alarm_floor_components.dart';

class FireAlarmFloorManagement extends StatefulWidget {
  final String siteId;
  final SupabaseService supabaseService;

  const FireAlarmFloorManagement({
    super.key,
    required this.siteId,
    required this.supabaseService,
  });

  @override
  State<FireAlarmFloorManagement> createState() =>
      _FireAlarmFloorManagementState();
}

class _FireAlarmFloorManagementState extends State<FireAlarmFloorManagement> {
  List<Floor> _floors = [];
  Floor? _selectedFloor;
  bool _isLoading = true;
  bool _showAddButtons = false;

  @override
  void initState() {
    super.initState();
    _loadFloors();
  }

  Future<void> _loadFloors() async {
    try {
      final floors = await widget.supabaseService.getFloorsBySiteId(
        widget.siteId,
      );
      if (mounted) {
        setState(() {
          _floors = floors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading floors: $e')));
      }
    }
  }

  void _showAddFloorDialog() {
    final floorTypeController = TextEditingController();
    final remarksController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            title: Text('Add Floor', style: GoogleFonts.poppins()),
            content: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: floorTypeController,
                    decoration: InputDecoration(
                      hintText: 'Enter floor type (e.g., Parking, Floor 1)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: remarksController,
                    decoration: InputDecoration(
                      hintText: 'Enter remarks (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (floorTypeController.text.isNotEmpty) {
                    try {
                      await widget.supabaseService.createFloor(
                        widget.siteId,
                        floorTypeController.text,
                        remarks:
                            remarksController.text.isEmpty
                                ? null
                                : remarksController.text,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        _loadFloors();
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error creating floor: $e')),
                        );
                      }
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Show Add Buttons',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  Switch(
                    value: _showAddButtons,
                    onChanged: (value) {
                      setState(() {
                        _showAddButtons = value;
                      });
                    },
                    activeColor: Colors.red.shade700,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_showAddButtons)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddFloorDialog(),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          'Add Floor',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Column(
                  children: [
                    // Floor Selection
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Floor',
                        labelStyle: GoogleFonts.poppins(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      value: _selectedFloor?.id,
                      items:
                          _floors.map((floor) {
                            return DropdownMenuItem(
                              value: floor.id,
                              child: Text(
                                floor.floorType,
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
                            );
                          }).toList(),
                      onChanged: (String? value) {
                        setState(() {
                          _selectedFloor = _floors.firstWhere(
                            (floor) => floor.id == value,
                            orElse: () => _floors.first,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    // Display Selected Floor Components
                    if (_selectedFloor != null)
                      FireAlarmFloorComponents(
                        floor: _selectedFloor!,
                        onFloorUpdated: _loadFloors,
                        supabaseService: widget.supabaseService,
                        showAddButtons: _showAddButtons,
                      )
                    else
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Please select a floor to manage fire alarms',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
