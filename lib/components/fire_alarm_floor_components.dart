import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/floor.dart';
import '../models/smoke_detector.dart';
import '../models/heat_detector.dart';
import '../models/flasher_hooter_alarm.dart';
import '../models/control_module.dart';
import '../models/flow_switch.dart';
import '../models/monitor_module.dart';
import '../models/telephone_jack.dart';
import '../models/speaker.dart';
import '../services/supabase_service.dart';
import 'component_item.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FireAlarmFloorComponents extends StatefulWidget {
  final Floor floor;
  final Function() onFloorUpdated;
  final SupabaseService supabaseService;
  final bool showAddButtons;

  const FireAlarmFloorComponents({
    super.key,
    required this.floor,
    required this.onFloorUpdated,
    required this.supabaseService,
    this.showAddButtons = false,
  });

  @override
  State<FireAlarmFloorComponents> createState() =>
      _FireAlarmFloorComponentsState();
}

class _FireAlarmFloorComponentsState extends State<FireAlarmFloorComponents> {
  final ScrollController _scrollController = ScrollController();
  Map<String, List<dynamic>> _componentCache = {};
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onComponentUpdated(String componentType) {
    if (!_isUpdating) {
      setState(() {
        _isUpdating = true;
      });

      _componentCache.remove(componentType);

      setState(() {
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Floor Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Floor: ${widget.floor.floorType}',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.floor.remarks != null &&
                        widget.floor.remarks!.isNotEmpty)
                      Text(
                        'Remarks: ${widget.floor.remarks}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                    onPressed: () => _showEditFloorDialog(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteFloor(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
          const SizedBox(height: 4),

          // Fire Alarms & Building Accessories Section
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fire Alarms & Building Accessories',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 8),

                // Smoke Detector Component
                _buildGenericComponentSection<SmokeDetector>(
                  context,
                  'Smoke Detector',
                  () => widget.supabaseService.getSmokeDetectorsByFloorId(
                    widget.floor.id,
                  ),
                  (detector) => widget.supabaseService.updateSmokeDetector(
                    detector.id,
                    detector.status,
                    note: detector.note,
                  ),
                  (detector) =>
                      widget.supabaseService.deleteSmokeDetector(detector.id),
                  (status, note) => widget.supabaseService.createSmokeDetector(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated:
                      () => _onComponentUpdated('Smoke Detector'),
                ),

                // Heat Detector Component
                _buildGenericComponentSection<HeatDetector>(
                  context,
                  'Heat Detector',
                  () => widget.supabaseService.getHeatDetectorsByFloorId(
                    widget.floor.id,
                  ),
                  (detector) => widget.supabaseService.updateHeatDetector(
                    detector.id,
                    detector.status,
                    note: detector.note,
                  ),
                  (detector) =>
                      widget.supabaseService.deleteHeatDetector(detector.id),
                  (status, note) => widget.supabaseService.createHeatDetector(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated:
                      () => _onComponentUpdated('Heat Detector'),
                ),

                // Flasher Hooter Alarm Component
                _buildGenericComponentSection<FlasherHooterAlarm>(
                  context,
                  'Flasher Hooter Alarm',
                  () => widget.supabaseService.getFlasherHooterAlarmsByFloorId(
                    widget.floor.id,
                  ),
                  (alarm) => widget.supabaseService.updateFlasherHooterAlarm(
                    alarm.id,
                    alarm.status,
                    note: alarm.note,
                  ),
                  (alarm) =>
                      widget.supabaseService.deleteFlasherHooterAlarm(alarm.id),
                  (status, note) =>
                      widget.supabaseService.createFlasherHooterAlarm(
                        widget.floor.id,
                        status,
                        note: note,
                      ),
                  onComponentUpdated:
                      () => _onComponentUpdated('Flasher Hooter Alarm'),
                ),

                // Control Module Component
                _buildGenericComponentSection<ControlModule>(
                  context,
                  'Control Module',
                  () => widget.supabaseService.getControlModulesByFloorId(
                    widget.floor.id,
                  ),
                  (module) => widget.supabaseService.updateControlModule(
                    module.id,
                    module.status,
                    note: module.note,
                  ),
                  (module) =>
                      widget.supabaseService.deleteControlModule(module.id),
                  (status, note) => widget.supabaseService.createControlModule(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated:
                      () => _onComponentUpdated('Control Module'),
                ),

                // Flow Switch Component
                _buildGenericComponentSection<FlowSwitch>(
                  context,
                  'Flow Switch',
                  () => widget.supabaseService.getFlowSwitchesByFloorId(
                    widget.floor.id,
                  ),
                  (flowSwitch) => widget.supabaseService.updateFlowSwitch(
                    flowSwitch.id,
                    flowSwitch.status,
                    note: flowSwitch.note,
                  ),
                  (flowSwitch) =>
                      widget.supabaseService.deleteFlowSwitch(flowSwitch.id),
                  (status, note) => widget.supabaseService.createFlowSwitch(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated: () => _onComponentUpdated('Flow Switch'),
                ),

                // Monitor Module Component
                _buildGenericComponentSection<MonitorModule>(
                  context,
                  'Monitor Module',
                  () => widget.supabaseService.getMonitorModulesByFloorId(
                    widget.floor.id,
                  ),
                  (module) => widget.supabaseService.updateMonitorModule(
                    module.id,
                    module.status,
                    note: module.note,
                  ),
                  (module) =>
                      widget.supabaseService.deleteMonitorModule(module.id),
                  (status, note) => widget.supabaseService.createMonitorModule(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated:
                      () => _onComponentUpdated('Monitor Module'),
                ),

                // Telephone Jack Component
                _buildGenericComponentSection<TelephoneJack>(
                  context,
                  'Telephone Jack',
                  () => widget.supabaseService.getTelephoneJacksByFloorId(
                    widget.floor.id,
                  ),
                  (jack) => widget.supabaseService.updateTelephoneJack(
                    jack.id,
                    jack.status,
                    note: jack.note,
                  ),
                  (jack) => widget.supabaseService.deleteTelephoneJack(jack.id),
                  (status, note) => widget.supabaseService.createTelephoneJack(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated:
                      () => _onComponentUpdated('Telephone Jack'),
                ),

                // Speaker Component
                _buildGenericComponentSection<Speaker>(
                  context,
                  'Speaker',
                  () => widget.supabaseService.getSpeakersByFloorId(
                    widget.floor.id,
                  ),
                  (speaker) => widget.supabaseService.updateSpeaker(
                    speaker.id,
                    speaker.status,
                    note: speaker.note,
                  ),
                  (speaker) => widget.supabaseService.deleteSpeaker(speaker.id),
                  (status, note) => widget.supabaseService.createSpeaker(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated: () => _onComponentUpdated('Speaker'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericComponentSection<T extends dynamic>(
    BuildContext context,
    String title,
    Future<List<T>> Function() getItems,
    Future<void> Function(T) updateItem,
    Future<void> Function(T) deleteItem,
    Future<void> Function(String, String?) createItem, {
    List<String>? statusOptions,
    required Function() onComponentUpdated,
  }) {
    final defaultStatusOptions = ['Working', 'Not Working', 'Missing'];
    final availableStatusOptions = statusOptions ?? defaultStatusOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade800,
          ),
        ),
        const SizedBox(height: 4),
        if (widget.showAddButtons)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      () => _showAddGenericDialog(
                        context,
                        title,
                        createItem,
                        availableStatusOptions,
                        () {
                          _onComponentUpdated(title);
                        },
                      ),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    'Add $title',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 4),
        FutureBuilder<List<T>>(
          future: getItems(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text(
                'Error loading items: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              );
            }

            final items = snapshot.data ?? [];
            return Column(
              children:
                  items.map((item) {
                    return ComponentItem(
                      title: title,
                      status: item.status,
                      note: item.note,
                      statusOptions: availableStatusOptions,
                      onStatusChanged: (value) async {
                        try {
                          final updatedItem = item;
                          updatedItem.status = value;
                          await updateItem(updatedItem);
                          _onComponentUpdated(title);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating status: $e'),
                              ),
                            );
                          }
                        }
                      },
                      onNoteChanged: (note) async {
                        try {
                          final updatedItem = item;
                          updatedItem.note = note;
                          await updateItem(updatedItem);
                          _onComponentUpdated(title);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error updating note: $e'),
                              ),
                            );
                          }
                        }
                      },
                      onDelete: () async {
                        try {
                          await deleteItem(item);
                          _onComponentUpdated(title);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting item: $e'),
                              ),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showAddGenericDialog(
    BuildContext context,
    String title,
    Future<void> Function(String, String?) createItem,
    List<String> statusOptions,
    Function() onComponentUpdated,
  ) {
    final statusController = TextEditingController();
    final noteController = TextEditingController();
    MobileScannerController? scannerController;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            title: Text('Add $title', style: GoogleFonts.poppins()),
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
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        statusOptions.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        statusController.text = value;
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            scannerController = MobileScannerController();
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    title: Text(
                                      'Scan Barcode',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    content: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.blue.shade50,
                                            Colors.blue.shade100,
                                          ],
                                        ),
                                      ),
                                      child: SizedBox(
                                        height: 200,
                                        child: MobileScanner(
                                          controller: scannerController!,
                                          onDetect: (capture) {
                                            final List<Barcode> barcodes =
                                                capture.barcodes;
                                            for (final barcode in barcodes) {
                                              noteController.text =
                                                  barcode.rawValue ?? '';
                                            }
                                            scannerController?.dispose();
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          scannerController?.dispose();
                                          Navigator.pop(context);
                                        },
                                        child: Text(
                                          'Cancel',
                                          style: GoogleFonts.poppins(),
                                        ),
                                      ),
                                    ],
                                  ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(
                            'Scan Barcode',
                            style: GoogleFonts.poppins(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
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
                  if (statusController.text.isNotEmpty) {
                    await createItem(
                      statusController.text,
                      noteController.text,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      onComponentUpdated();
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  Future<void> _showEditFloorDialog(BuildContext context) async {
    final floorTypeController = TextEditingController(
      text: widget.floor.floorType,
    );
    final remarksController = TextEditingController(
      text: widget.floor.remarks ?? '',
    );

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            title: Text('Edit Floor', style: GoogleFonts.poppins()),
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
                    decoration: const InputDecoration(
                      labelText: 'Floor Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: remarksController,
                    decoration: const InputDecoration(
                      labelText: 'Remarks (Optional)',
                      border: OutlineInputBorder(),
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
                onPressed:
                    () => Navigator.pop(context, {
                      'floorType': floorTypeController.text,
                      'remarks': remarksController.text.trim(),
                    }),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (result != null) {
      try {
        await widget.supabaseService.updateFloor(
          widget.floor.id,
          result['floorType']!,
          remarks: result['remarks']!.isEmpty ? null : result['remarks'],
        );
        widget.onFloorUpdated();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating floor: $e')));
        }
      }
    }
  }

  Future<void> _deleteFloor(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            title: const Text('Delete Floor'),
            content: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
              ),
              child: const Text('Are you sure you want to delete this floor?'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await widget.supabaseService.deleteFloor(widget.floor.id);
        widget.onFloorUpdated();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting floor: $e')));
        }
      }
    }
  }
}
