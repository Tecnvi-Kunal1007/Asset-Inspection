import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/pump_controller.dart';
import '../models/pump.dart';
import 'voice_chat_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';

class PumpScreen extends StatefulWidget {
  final String pumpId;
  final String siteId;
  final Function(Pump)? onPumpUpdated;

  const PumpScreen({
    super.key,
    required this.pumpId,
    required this.siteId,
    this.onPumpUpdated,
  });

  @override
  State<PumpScreen> createState() => _PumpScreenState();
}

class _PumpScreenState extends State<PumpScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _headController = TextEditingController();
  final TextEditingController _ratedPowerController = TextEditingController();
  final TextEditingController _startPressureController =
      TextEditingController();
  final TextEditingController _stopPressureController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  bool _isEditing = false;
  late AnimationController _animationController;
  late PumpController _pumpController;

  @override
  void initState() {
    super.initState();
    _pumpController = PumpController(
      pumpId: widget.pumpId,
      siteId: widget.siteId,
    );
    _pumpController.addListener(_onPumpControllerChanged);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
    });
  }

  void _onPumpControllerChanged() {
    if (!_isEditing) {
      _initializeControllers();
    }
    if (widget.onPumpUpdated != null && _pumpController.pump != null) {
      widget.onPumpUpdated!(_pumpController.pump!);
    }
  }

  void _initializeControllers() {
    if (_pumpController.pump != null) {
      _capacityController.text = _pumpController.capacity.toString();
      _headController.text = _pumpController.head.toString();
      _ratedPowerController.text = _pumpController.ratedPower.toString();
      _startPressureController.text = _pumpController.startPressure.toString();
      _stopPressureController.text = _pumpController.stopPressure.toString();
      _commentsController.text =
          _pumpController.comments ?? 'Please enter comments';
    }
  }

  @override
  void dispose() {
    _capacityController.dispose();
    _headController.dispose();
    _ratedPowerController.dispose();
    _startPressureController.dispose();
    _stopPressureController.dispose();
    _commentsController.dispose();
    _animationController.dispose();
    _pumpController.removeListener(_onPumpControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChangeNotifierProvider.value(
        value: _pumpController,
        child: Consumer<PumpController>(
          builder: (context, controller, _) {
            final isWorking = controller.status.toLowerCase() == 'working';
            return CustomScrollView(
              slivers: [
                _buildAppBar(isWorking, controller),
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatusCard(isWorking, controller),
                        const SizedBox(height: 20),
                        _buildSpecificationsCard(controller),
                        const SizedBox(height: 20),
                        _buildOperationalCard(controller),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () async {
        if (_isEditing) {
          await _saveChanges();
        } else {
          setState(() {
            _isEditing = true;
            _animationController.forward();
          });
        }
      },
      backgroundColor: _isEditing ? Colors.green : Colors.blue,
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_close,
        progress: _animationController,
      ),
      label: Text(
        _isEditing ? 'Save Changes' : 'Edit Pump',
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAppBar(bool isWorking, PumpController controller) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      stretch: true,
      backgroundColor: isWorking ? Colors.green.shade100 : Colors.red.shade100,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Pump Configuration',
          style: GoogleFonts.poppins(
            color: isWorking ? Colors.green.shade900 : Colors.red.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    isWorking ? Colors.green.shade200 : Colors.red.shade200,
                    isWorking ? Colors.green.shade50 : Colors.red.shade50,
                  ],
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.addchart,
                size: 80,
                color: isWorking ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isWorking, PumpController controller) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isWorking ? Colors.green.shade50 : Colors.red.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Status',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color:
                      isWorking ? Colors.green.shade800 : Colors.red.shade800,
                ),
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Status',
                controller.status,
                ['Working', 'Not Working'],
                (value) => controller.updateStatus(value),
                Icons.power_settings_new,
                _isEditing,
              ),
              _buildDropdownField(
                'Mode',
                controller.mode,
                ['Auto', 'Manual'],
                (value) => controller.updateMode(value),
                Icons.mode,
                _isEditing,
              ),
              _buildDropdownField(
                'Suction Valve',
                controller.suctionValve,
                ['Open', 'Closed'],
                (value) => controller.updateSuctionValve(value),
                Icons.settings_input_component,
                _isEditing,
              ),
              _buildDropdownField(
                'Delivery Valve',
                controller.deliveryValve,
                ['Open', 'Closed'],
                (value) => controller.updateDeliveryValve(value),
                Icons.settings_input_component,
                _isEditing,
              ),
              _buildDropdownField(
                'Pressure Gauge',
                controller.pressureGauge,
                ['Working', 'Not Working'],
                (value) => controller.updatePressureGauge(value),
                Icons.speed,
                _isEditing,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecificationsCard(PumpController controller) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Specifications',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 16),
              _buildEditableField(
                'Capacity',
                _capacityController,
                'LPM',
                Icons.speed,
              ),
              _buildEditableField(
                'Head',
                _headController,
                'meters',
                Icons.height,
              ),
              _buildEditableField(
                'Rated Power',
                _ratedPowerController,
                'kW',
                Icons.power,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationalCard(PumpController controller) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Operational Parameters',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                ),
              ),
              const SizedBox(height: 16),
              _buildEditableField(
                'Start Pressure',
                _startPressureController,
                'kg/cm²',
                Icons.arrow_upward,
              ),
              _buildEditableField(
                'Stop Pressure',
                _stopPressureController,
                'kg/cm²',
                Icons.arrow_downward,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String currentValue,
    List<String> items,
    Function(String) onChanged,
    IconData icon,
    bool isEditing,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                if (isEditing)
                  DropdownButtonFormField<String>(
                    value: currentValue,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items:
                        items.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, style: GoogleFonts.poppins()),
                          );
                        }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(value);
                      }
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      currentValue,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    String unit,
    IconData icon,
  ) {
    final isDecimalField = unit == 'kg/cm²';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_isEditing)
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: isDecimalField,
                        signed: false,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 0,
                        ),
                        border: InputBorder.none,
                        suffixText: unit,
                        suffixStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        hintText: '0',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                        errorStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.red,
                        ),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          isDecimalField
                              ? RegExp(r'^\d*\.?\d*$')
                              : RegExp(r'^\d*$'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          String? errorText;
                          bool isValid = false;

                          if (isDecimalField) {
                            final pressure = double.tryParse(value);
                            if (pressure == null) {
                              errorText = 'Please enter a valid number';
                            } else if (pressure < 0) {
                              errorText = 'Please enter a positive number';
                            } else {
                              isValid = true;
                            }
                          } else {
                            final intValue = int.tryParse(value);
                            if (intValue == null) {
                              errorText = 'Please enter a valid integer';
                            } else if (intValue < 0) {
                              errorText = 'Please enter a positive integer';
                            } else {
                              isValid = true;
                            }
                          }

                          if (!isValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorText ?? 'Invalid input'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      },
                    )
                  else
                    Text(
                      '${controller.text} $unit',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isEditing = true);
    try {
      await _pumpController.updateCapacity(int.parse(_capacityController.text));
      await _pumpController.updateHead(int.parse(_headController.text));
      await _pumpController.updateRatedPower(
        int.parse(_ratedPowerController.text),
      );
      await _pumpController.updateStartPressure(
        double.parse(_startPressureController.text),
      );
      await _pumpController.updateStopPressure(_stopPressureController.text);
      await _pumpController.updateComments(_commentsController.text);
      await _pumpController.saveToDatabase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving changes: $e')));
      }
    } finally {
      setState(() => _isEditing = false);
    }
  }
}
