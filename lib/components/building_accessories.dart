import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/building_accessories.dart';
import '../services/supabase_service.dart';
import 'dart:async';

class BuildingAccessoriesWidget extends StatefulWidget {
  final String siteId;
  final SupabaseService supabaseService;
  final Function() onUpdated;

  const BuildingAccessoriesWidget({
    super.key,
    required this.siteId,
    required this.supabaseService,
    required this.onUpdated,
  });

  @override
  State<BuildingAccessoriesWidget> createState() =>
      _BuildingAccessoriesWidgetState();
}

class _BuildingAccessoriesWidgetState extends State<BuildingAccessoriesWidget> {
  final List<String> _statusOptions = ['Working', 'Not Working', 'Missing'];
  BuildingAccessories? _buildingAccessories;
  bool _isLoading = true;
  late TextEditingController _notesController;
  late FocusNode _notesFocusNode;
  Timer? _debounceTimer;
  bool _isSavingNotes = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _notesFocusNode = FocusNode();
    _loadBuildingAccessories();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBuildingAccessories() async {
    setState(() => _isLoading = true);
    try {
      final accessories = await widget.supabaseService
          .getBuildingAccessoriesBySiteId(widget.siteId);
      if (accessories == null) {
        await widget.supabaseService.createBuildingAccessories(widget.siteId);
        _loadBuildingAccessories();
      } else {
        setState(() {
          _buildingAccessories = accessories;
          _isLoading = false;
        });
        if (_notesController.text != accessories.notes) {
          _notesController.text = accessories.notes ?? '';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading building accessories: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String field, String status) async {
    if (_buildingAccessories == null) return;

    try {
      await widget.supabaseService.updateBuildingAccessories(
        _buildingAccessories!.id,
        {field: status},
      );
      await _loadBuildingAccessories();
      widget.onUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  Future<void> _updateStatusWithoutRefresh(String field, String status) async {
    if (_buildingAccessories == null) return;

    try {
      await widget.supabaseService.updateBuildingAccessories(
        _buildingAccessories!.id,
        {field: status},
      );

      // Update the local state without full refresh
      setState(() {
        switch (field) {
          case 'fire_alarm_panel_status':
            _buildingAccessories!.fireAlarmPanelStatus = status;
            break;
          case 'repeater_panel_status':
            _buildingAccessories!.repeaterPanelStatus = status;
            break;
          case 'battery_status':
            _buildingAccessories!.batteryStatus = status;
            break;
          case 'lift_integration_relay_status':
            _buildingAccessories!.liftIntegrationRelayStatus = status;
            break;
          case 'access_integration_status':
            _buildingAccessories!.accessIntegrationStatus = status;
            break;
          case 'press_fan_integration_status':
            _buildingAccessories!.pressFanIntegrationStatus = status;
            break;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $status'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      widget.onUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  Future<void> _updateNotes(String notes) async {
    if (_buildingAccessories == null) return;

    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Set a new timer to save after 1 second of no typing
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      if (mounted) {
        setState(() {
          _isSavingNotes = true;
        });

        try {
          await widget.supabaseService.updateBuildingAccessories(
            _buildingAccessories!.id,
            {'notes': notes},
          );

          // Update the local model without triggering a full reload
          if (_buildingAccessories != null) {
            _buildingAccessories!.notes = notes;
          }

          // Unfocus the text field after successful save
          _notesFocusNode.unfocus();

          widget.onUpdated();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error updating notes: $e')));
          }
        } finally {
          if (mounted) {
            setState(() {
              _isSavingNotes = false;
            });
          }
        }
      }
    });
  }

  Widget _buildStatusToggleButtons(
    String title,
    String currentStatus,
    String fieldName,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title above the buttons
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            // Toggle buttons below
            Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  // Animated background
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color:
                          currentStatus == 'Working'
                              ? Colors.green.shade400
                              : currentStatus == 'Not Working'
                              ? Colors.red.shade400
                              : Colors.orange.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  // Toggle buttons
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                            ),
                            onTap:
                                () => _updateStatusWithoutRefresh(
                                  fieldName,
                                  'Working',
                                ),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Working',
                                  style: GoogleFonts.poppins(
                                    color:
                                        currentStatus == 'Working'
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap:
                                () => _updateStatusWithoutRefresh(
                                  fieldName,
                                  'Not Working',
                                ),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Not\nWorking',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    color:
                                        currentStatus == 'Not Working'
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            onTap:
                                () => _updateStatusWithoutRefresh(
                                  fieldName,
                                  'Missing',
                                ),
                            child: Center(
                              child: Text(
                                'Missing',
                                style: GoogleFonts.poppins(
                                  color:
                                      currentStatus == 'Missing'
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_buildingAccessories == null) {
      return const Center(child: Text('No building accessories found'));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fire Alarm Checks',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusToggleButtons(
            'Fire Alarm Panel',
            _buildingAccessories!.fireAlarmPanelStatus,
            'fire_alarm_panel_status',
          ),
          const SizedBox(height: 8),
          _buildStatusToggleButtons(
            'Repeater Panel',
            _buildingAccessories!.repeaterPanelStatus,
            'repeater_panel_status',
          ),
          const SizedBox(height: 8),
          _buildStatusToggleButtons(
            'Battery',
            _buildingAccessories!.batteryStatus,
            'battery_status',
          ),
          const SizedBox(height: 8),
          _buildStatusToggleButtons(
            'Lift Integration Relay',
            _buildingAccessories!.liftIntegrationRelayStatus,
            'lift_integration_relay_status',
          ),
          const SizedBox(height: 8),
          _buildStatusToggleButtons(
            'Access Integration',
            _buildingAccessories!.accessIntegrationStatus,
            'access_integration_status',
          ),
          const SizedBox(height: 8),
          _buildStatusToggleButtons(
            'Press Fan Integration',
            _buildingAccessories!.pressFanIntegrationStatus,
            'press_fan_integration_status',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notes',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _notesController,
                          focusNode: _notesFocusNode,
                          decoration: const InputDecoration(
                            hintText: 'Add notes here...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          onChanged: (value) {
                            _updateNotes(value);
                          },
                        ),
                      ),
                      if (_isSavingNotes) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
