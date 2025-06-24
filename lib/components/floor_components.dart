import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/floor.dart';
import '../models/hydrant_valve.dart';
import '../models/hydrant_ug.dart';
import '../models/hydrant_wheel.dart';
import '../models/hydrant_cap.dart';
import '../models/hydrant_mouth_gasket.dart';
import '../models/canvas_hose.dart';
import '../models/branch_pipe.dart';
import '../models/fireman_axe.dart';
import '../models/hose_reel.dart';
import '../models/shut_off_nozzle.dart';
import '../models/key_glass.dart';
import '../models/pressure_gauge.dart';
import '../models/abc_extinguisher.dart';
import '../models/sprinkler_zcv.dart';
import '../models/smoke_detector.dart';
import '../models/heat_detector.dart';
import '../models/flasher_hooter_alarm.dart';
import '../models/control_module.dart';
import '../models/flow_switch.dart';
import '../models/monitor_module.dart';
import '../models/telephone_jack.dart';
import '../models/speaker.dart';
import '../models/booster_pump.dart';
import '../services/supabase_service.dart';
import 'component_item.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class FloorComponents extends StatefulWidget {
  final Floor floor;
  final Function() onFloorUpdated;
  final SupabaseService supabaseService;

  const FloorComponents({
    super.key,
    required this.floor,
    required this.onFloorUpdated,
    required this.supabaseService,
  });

  @override
  State<FloorComponents> createState() => _FloorComponentsState();
}

class _FloorComponentsState extends State<FloorComponents> {
  final ScrollController _scrollController = ScrollController();
  Map<String, List<dynamic>> _componentCache = {};
  bool _isUpdating = false;
  bool _showAddButtons = false;

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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.floor.remarks != null &&
                        widget.floor.remarks!.isNotEmpty)
                      Text(
                        'Remarks: ${widget.floor.remarks}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showEditFloorDialog(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteFloor(context),
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Pumps & Accessories Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pumps & Accessories',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                // Add Toggle Button
                Row(
                  children: [
                    Text(
                      'Show Add Buttons',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _showAddButtons,
                      onChanged: (value) {
                        setState(() {
                          _showAddButtons = value;
                        });
                      },
                      activeColor: Colors.blue.shade700,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Hydrant Valves Section
                _buildHydrantValvesSection(context),

                // Generic Components Sections for Pumps & Accessories
                _buildGenericComponentSection<HydrantUG>(
                  context,
                  'Hydrant LUG',
                  () => widget.supabaseService.getHydrantUGsByFloorId(
                    widget.floor.id,
                  ),
                  (ug) => widget.supabaseService.updateHydrantUG(
                    ug.id,
                    ug.status,
                    note: ug.note,
                  ),
                  (ug) => widget.supabaseService.deleteHydrantUG(ug.id),
                  (status, note) => widget.supabaseService.createHydrantUG(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated: () => _onComponentUpdated('Hydrant LUG'),
                ),

                _buildGenericComponentSection<HydrantWheel>(
                  context,
                  'Hydrant Wheel',
                  () => widget.supabaseService.getHydrantWheelsByFloorId(
                    widget.floor.id,
                  ),
                  (wheel) => widget.supabaseService.updateHydrantWheel(
                    wheel.id,
                    wheel.status,
                    note: wheel.note,
                  ),
                  (wheel) =>
                      widget.supabaseService.deleteHydrantWheel(wheel.id),
                  (status, note) => widget.supabaseService.createHydrantWheel(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated:
                      () => _onComponentUpdated('Hydrant Wheel'),
                ),

                _buildGenericComponentSection<HydrantCap>(
                  context,
                  'Hydrant Cap',
                  () => widget.supabaseService.getHydrantCapsByFloorId(
                    widget.floor.id,
                  ),
                  (cap) => widget.supabaseService.updateHydrantCap(
                    cap.id,
                    cap.status,
                    note: cap.note,
                  ),
                  (cap) => widget.supabaseService.deleteHydrantCap(cap.id),
                  (status, note) => widget.supabaseService.createHydrantCap(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated: () => _onComponentUpdated('Hydrant Cap'),
                ),

                _buildGenericComponentSection<HydrantMouthGasket>(
                  context,
                  'Hydrant Mouth Gasket',
                  () => widget.supabaseService.getHydrantMouthGasketsByFloorId(
                    widget.floor.id,
                  ),
                  (gasket) => widget.supabaseService.updateHydrantMouthGasket(
                    gasket.id,
                    gasket.status,
                    note: gasket.note,
                  ),
                  (gasket) => widget.supabaseService.deleteHydrantMouthGasket(
                    gasket.id,
                  ),
                  (status, note) =>
                      widget.supabaseService.createHydrantMouthGasket(
                        widget.floor.id,
                        status,
                        note: note,
                      ),
                  onComponentUpdated:
                      () => _onComponentUpdated('Hydrant Mouth Gasket'),
                ),

                _buildGenericComponentSection<CanvasHose>(
                  context,
                  'Canvas Hose',
                  () => widget.supabaseService.getCanvasHosesByFloorId(
                    widget.floor.id,
                  ),
                  (hose) => widget.supabaseService.updateCanvasHose(
                    hose.id,
                    hose.status,
                    note: hose.note,
                  ),
                  (hose) => widget.supabaseService.deleteCanvasHose(hose.id),
                  (status, note) => widget.supabaseService.createCanvasHose(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated: () => _onComponentUpdated('Canvas Hose'),
                ),

                _buildGenericComponentSection<BranchPipe>(
                  context,
                  'Branch Pipe',
                  () => widget.supabaseService.getBranchPipesByFloorId(
                    widget.floor.id,
                  ),
                  (pipe) => widget.supabaseService.updateBranchPipe(
                    pipe.id,
                    pipe.status,
                    note: pipe.note,
                  ),
                  (pipe) => widget.supabaseService.deleteBranchPipe(pipe.id),
                  (status, note) => widget.supabaseService.createBranchPipe(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated: () => _onComponentUpdated('Branch Pipe'),
                ),

                _buildGenericComponentSection<FiremanAxe>(
                  context,
                  'Fireman Axe',
                  () => widget.supabaseService.getFiremanAxesByFloorId(
                    widget.floor.id,
                  ),
                  (axe) => widget.supabaseService.updateFiremanAxe(
                    axe.id,
                    axe.status,
                    note: axe.note,
                  ),
                  (axe) => widget.supabaseService.deleteFiremanAxe(axe.id),
                  (status, note) => widget.supabaseService.createFiremanAxe(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated: () => _onComponentUpdated('Fireman Axe'),
                ),

                _buildGenericComponentSection<HoseReel>(
                  context,
                  'Hose Reel',
                  () => widget.supabaseService.getHoseReelsByFloorId(
                    widget.floor.id,
                  ),
                  (reel) => widget.supabaseService.updateHoseReel(
                    reel.id,
                    reel.status,
                    note: reel.note,
                  ),
                  (reel) => widget.supabaseService.deleteHoseReel(reel.id),
                  (status, note) => widget.supabaseService.createHoseReel(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated: () => _onComponentUpdated('Hose Reel'),
                ),

                _buildGenericComponentSection<ShutOffNozzle>(
                  context,
                  'Shut Off Nozzle',
                  () => widget.supabaseService.getShutOffNozzlesByFloorId(
                    widget.floor.id,
                  ),
                  (nozzle) => widget.supabaseService.updateShutOffNozzle(
                    nozzle.id,
                    nozzle.status,
                    note: nozzle.note,
                  ),
                  (nozzle) =>
                      widget.supabaseService.deleteShutOffNozzle(nozzle.id),
                  (status, note) => widget.supabaseService.createShutOffNozzle(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated:
                      () => _onComponentUpdated('Shut Off Nozzle'),
                ),

                _buildGenericComponentSection<KeyGlass>(
                  context,
                  'Key Glass',
                  () => widget.supabaseService.getKeyGlassesByFloorId(
                    widget.floor.id,
                  ),
                  (glass) => widget.supabaseService.updateKeyGlass(
                    glass.id,
                    glass.status,
                    note: glass.note,
                  ),
                  (glass) => widget.supabaseService.deleteKeyGlass(glass.id),
                  (status, note) => widget.supabaseService.createKeyGlass(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated: () => _onComponentUpdated('Key Glass'),
                ),

                _buildGenericComponentSection<PressureGauge>(
                  context,
                  'Pressure Gauge',
                  () => widget.supabaseService.getPressureGaugesByFloorId(
                    widget.floor.id,
                  ),
                  (gauge) => widget.supabaseService.updatePressureGauge(
                    gauge.id,
                    gauge.status,
                    note: gauge.note,
                  ),
                  (gauge) =>
                      widget.supabaseService.deletePressureGauge(gauge.id),
                  (status, note) => widget.supabaseService.createPressureGauge(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated:
                      () => _onComponentUpdated('Pressure Gauge'),
                ),

                _buildGenericComponentSection<ABCExtinguisher>(
                  context,
                  'ABC Extinguisher',
                  () => widget.supabaseService.getABCExtinguishersByFloorId(
                    widget.floor.id,
                  ),
                  (extinguisher) =>
                      widget.supabaseService.updateABCExtinguisher(
                        extinguisher.id,
                        extinguisher.status,
                        note: extinguisher.note,
                      ),
                  (extinguisher) => widget.supabaseService
                      .deleteABCExtinguisher(extinguisher.id),
                  (status, note) =>
                      widget.supabaseService.createABCExtinguisher(
                        widget.floor.id,
                        status,
                        note: note,
                      ),
                  onComponentUpdated:
                      () => _onComponentUpdated('ABC Extinguisher'),
                ),

                _buildGenericComponentSection<SprinklerZCV>(
                  context,
                  'Sprinkler ZCV',
                  () => widget.supabaseService.getSprinklerZCVsByFloorId(
                    widget.floor.id,
                  ),
                  (zcv) => widget.supabaseService.updateSprinklerZCV(
                    zcv.id,
                    zcv.status,
                    note: zcv.note,
                  ),
                  (zcv) => widget.supabaseService.deleteSprinklerZCV(zcv.id),
                  (status, note) => widget.supabaseService.createSprinklerZCV(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  statusOptions: const ['Open', 'Close'],
                  onComponentUpdated:
                      () => _onComponentUpdated('Sprinkler ZCV'),
                ),

                _buildGenericComponentSection<BoosterPump>(
                  context,
                  'Booster Pump',
                  () => widget.supabaseService.getBoosterPumps(widget.floor.id),
                  (pump) => widget.supabaseService.updateBoosterPump(
                    pump.id,
                    pump.status,
                    note: pump.note,
                  ),
                  (pump) => widget.supabaseService.deleteBoosterPump(pump.id),
                  (status, note) => widget.supabaseService.createBoosterPump(
                    widget.floor.id,
                    status,
                    note: note,
                  ),
                  onComponentUpdated: () => _onComponentUpdated('Booster Pump'),
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
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 8),
        if (_showAddButtons)
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
                  icon: const Icon(Icons.add),
                  label: Text('Add $title', style: GoogleFonts.poppins()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
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

  Widget _buildHydrantValvesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Hydrant Valve',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        const SizedBox(height: 8),
        if (_showAddButtons)
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddHydrantValveDialog(context),
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Add Hydrant Valve',
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
        const SizedBox(height: 8),
        FutureBuilder<List<HydrantValve>>(
          future: widget.supabaseService.getHydrantValvesByFloorId(
            widget.floor.id,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text(
                'Error loading valves: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              );
            }

            final valves = snapshot.data ?? [];
            return Column(
              children:
                  valves.map((valve) {
                    return ComponentItem(
                      title: 'Hydrant Valve',
                      subtitle: 'Type: ${valve.valveType}',
                      status: valve.status,
                      note: valve.note,
                      statusOptions: const [
                        'Working',
                        'Not Working',
                        'Missing',
                      ],
                      onStatusChanged: (value) async {
                        try {
                          await widget.supabaseService.updateHydrantValve(
                            valve.id,
                            valve.valveType,
                            value,
                            note: valve.note,
                          );
                          _onComponentUpdated('Hydrant Valve');
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
                          await widget.supabaseService.updateHydrantValve(
                            valve.id,
                            valve.valveType,
                            valve.status,
                            note: note,
                          );
                          _onComponentUpdated('Hydrant Valve');
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
                          await widget.supabaseService.deleteHydrantValve(
                            valve.id,
                          );
                          _onComponentUpdated('Hydrant Valve');
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting valve: $e'),
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

  void _showAddHydrantValveDialog(BuildContext context) {
    final valveTypeController = TextEditingController();
    final statusController = TextEditingController();
    final noteController = TextEditingController();
    MobileScannerController? scannerController;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add Hydrant Valve', style: GoogleFonts.poppins()),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Valve Type',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          ['Single', 'Double'].map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            );
                          }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          valveTypeController.text = value;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          ['Working', 'Not Working', 'Missing'].map((status) {
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: noteController,
                            decoration: const InputDecoration(
                              labelText: 'Note (Optional)',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.qr_code_scanner,
                            color: Colors.blue.shade700,
                          ),
                          onPressed: () {
                            scannerController = MobileScannerController();
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text(
                                      'Scan Barcode',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    content: SizedBox(
                                      height: 300,
                                      child: MobileScanner(
                                        controller: scannerController!,
                                        onDetect: (capture) {
                                          final List<Barcode> barcodes =
                                              capture.barcodes;
                                          for (final barcode in barcodes) {
                                            if (barcode.rawValue != null) {
                                              noteController.text =
                                                  barcode.rawValue!;
                                              scannerController?.dispose();
                                              Navigator.pop(context);
                                              break;
                                            }
                                          }
                                        },
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
                          tooltip: 'Scan Barcode',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (valveTypeController.text.isNotEmpty &&
                      statusController.text.isNotEmpty) {
                    await widget.supabaseService.createHydrantValve(
                      widget.floor.id,
                      valveTypeController.text,
                      statusController.text,
                      note:
                          noteController.text.isEmpty
                              ? null
                              : noteController.text,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      _onComponentUpdated('Hydrant Valve');
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }
}
