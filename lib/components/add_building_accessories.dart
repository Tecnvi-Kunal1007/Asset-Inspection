import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';

class AddBuildingAccessories extends StatefulWidget {
  final String siteId;
  final SupabaseService supabaseService;
  final Function() onUpdated;

  const AddBuildingAccessories({
    super.key,
    required this.siteId,
    required this.supabaseService,
    required this.onUpdated,
  });

  @override
  State<AddBuildingAccessories> createState() => _AddBuildingAccessoriesState();
}

class _AddBuildingAccessoriesState extends State<AddBuildingAccessories> {
  List<Map<String, dynamic>> _accessories = [];
  bool _isLoading = true;
  final Map<String, TextEditingController> _notesControllers = {};
  final Map<String, Timer> _debounceTimers = {};

  @override
  void initState() {
    super.initState();
    _loadAccessories();
  }

  @override
  void dispose() {
    for (var controller in _notesControllers.values) {
      controller.dispose();
    }
    for (var timer in _debounceTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _loadAccessories() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('custom_building_accessories')
          .select()
          .eq('site_id', widget.siteId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _accessories = List<Map<String, dynamic>>.from(response);
        // Initialize controllers for notes
        for (var accessory in _accessories) {
          _notesControllers[accessory['id']] = TextEditingController(
            text: accessory['notes']?.toString() ?? '',
          );
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading accessories: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateAccessory(String id, String field, dynamic value) async {
    try {
      await Supabase.instance.client
          .from('custom_building_accessories')
          .update({field: value})
          .eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Updated successfully')));
      }

      await _loadAccessories();
      widget.onUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating: $e')));
      }
    }
  }

  Future<void> _deleteAccessory(String id) async {
    try {
      await Supabase.instance.client
          .from('custom_building_accessories')
          .delete()
          .eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accessory deleted successfully')),
        );
      }

      await _loadAccessories();
      widget.onUpdated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting accessory: $e')));
      }
    }
  }

  void _showAccessoryDialog() {
    final _formKey = GlobalKey<FormState>();
    final _accessoryNameController = TextEditingController();
    final _notesController = TextEditingController();
    String _selectedStatus = 'Working';

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Accessory',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _accessoryNameController,
                      decoration: InputDecoration(
                        labelText: 'Accessory Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter accessory name';
                        }
                        return null;
                      },
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
                          ['Working', 'Not Working', 'Missing'].map((
                            String status,
                          ) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          _selectedStatus = newValue;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _notesController,
                            decoration: InputDecoration(
                              labelText: 'Notes',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 3,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: () => _showScannerDialog(_notesController),
                          tooltip: 'Scan QR/Barcode',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (!_formKey.currentState!.validate()) return;

                            try {
                              await Supabase.instance.client
                                  .from('custom_building_accessories')
                                  .insert({
                                    'site_id': widget.siteId,
                                    'accessory_name':
                                        _accessoryNameController.text,
                                    'status': _selectedStatus,
                                    'notes': _notesController.text,
                                  });

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Accessory added successfully',
                                    ),
                                  ),
                                );
                              }

                              await _loadAccessories();
                              widget.onUpdated();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _showScannerDialog(TextEditingController controller) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Scan QR/Barcode',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 300,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: MobileScanner(
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null) {
                              controller.text = barcode.rawValue!;
                              Navigator.pop(context);
                              break;
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Building Accessories',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_accessories.isEmpty)
              const Center(child: Text('No accessories added yet'))
            else
              SizedBox(
                height: 400, // Fixed height for the list
                child: RefreshIndicator(
                  onRefresh: _loadAccessories,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _accessories.length,
                    itemBuilder: (context, index) {
                      final accessory = _accessories[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      accessory['accessory_name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed:
                                        () => _deleteAccessory(accessory['id']),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Status',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Background bar
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          margin: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color:
                                                accessory['status'] == 'Working'
                                                    ? Colors.green.shade400
                                                    : accessory['status'] ==
                                                        'Not Working'
                                                    ? Colors.red.shade400
                                                    : Colors.orange.shade400,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        // Status buttons
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  onTap:
                                                      () =>
                                                          _updateStatusWithoutRefresh(
                                                            accessory['id'],
                                                            'status',
                                                            'Working',
                                                          ),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        right: BorderSide(
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade300,
                                                          width: 1,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        'Working',
                                                        style: GoogleFonts.poppins(
                                                          color:
                                                              accessory['status'] ==
                                                                      'Working'
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .grey
                                                                      .shade700,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 13,
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
                                                      () =>
                                                          _updateStatusWithoutRefresh(
                                                            accessory['id'],
                                                            'status',
                                                            'Not Working',
                                                          ),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      border: Border(
                                                        right: BorderSide(
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade300,
                                                          width: 1,
                                                        ),
                                                      ),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        'Not\nWorking',
                                                        textAlign:
                                                            TextAlign.center,
                                                        style: GoogleFonts.poppins(
                                                          color:
                                                              accessory['status'] ==
                                                                      'Not Working'
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .grey
                                                                      .shade700,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 13,
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
                                                      () =>
                                                          _updateStatusWithoutRefresh(
                                                            accessory['id'],
                                                            'status',
                                                            'Missing',
                                                          ),
                                                  child: Center(
                                                    child: Text(
                                                      'Missing',
                                                      style: GoogleFonts.poppins(
                                                        color:
                                                            accessory['status'] ==
                                                                    'Missing'
                                                                ? Colors.white
                                                                : Colors
                                                                    .grey
                                                                    .shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 13,
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
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Notes: '),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller:
                                          _notesControllers[accessory['id']],
                                      decoration: InputDecoration(
                                        hintText: 'Add notes...',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                      ),
                                      maxLines: 3,
                                      onChanged: (value) {
                                        _updateAccessoryWithDebounce(
                                          accessory['id'],
                                          'notes',
                                          value,
                                        );
                                      },
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner),
                                    onPressed:
                                        () => _showScannerDialog(
                                          _notesControllers[accessory['id']]!,
                                        ),
                                    tooltip: 'Scan QR/Barcode',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showAccessoryDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add New Accessory'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this new method to handle status updates without refresh
  Future<void> _updateStatusWithoutRefresh(
    String id,
    String field,
    String value,
  ) async {
    try {
      await Supabase.instance.client
          .from('custom_building_accessories')
          .update({field: value})
          .eq('id', id);

      // Update the local state without refreshing
      setState(() {
        final index = _accessories.indexWhere((a) => a['id'] == id);
        if (index != -1) {
          _accessories[index][field] = value;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $value'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateAccessoryWithDebounce(
    String id,
    String field,
    dynamic value,
  ) async {
    // Cancel any existing timer for this field
    _debounceTimers[field]?.cancel();

    // Create a new timer
    _debounceTimers[field] = Timer(const Duration(milliseconds: 500), () async {
      try {
        await Supabase.instance.client
            .from('custom_building_accessories')
            .update({field: value})
            .eq('id', id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Updated successfully'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error updating: $e')));
        }
      }
    });
  }
}
