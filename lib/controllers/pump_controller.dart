import 'package:flutter/foundation.dart';
import '../services/voice_service.dart';
import '../services/supabase_service.dart';
import '../models/pump.dart';

class PumpController extends ChangeNotifier {
  final VoiceService _voiceService = VoiceService();
  final SupabaseService _supabaseService = SupabaseService();
  final String pumpId;
  final String siteId;
  bool _isVoiceEnabled = false;
  String _lastVoiceCommand = '';

  Pump? get pump => _pump;

  // Pump details
  String _status = 'Not Working';
  String _mode = 'Manual';
  num _startPressure = 0;
  String _stopPressure = '0';
  String _suctionValve = 'Closed';
  String _deliveryValve = 'Closed';
  String _pressureGauge = 'Not Working';
  String _operationalStatus = 'Non-Operating';
  String? _comments;

  // Static fields
  int _capacity = 0;
  int _head = 0;
  int _ratedPower = 0;

  PumpController({required this.pumpId, required this.siteId}) {
    initializeVoice();
    setupVoiceListeners();
    _loadPumpDetails();
  }

  bool get isVoiceEnabled => _isVoiceEnabled;
  String get lastVoiceCommand => _lastVoiceCommand;

  // Getters for pump details
  String get status => _status;
  String get mode => _mode;
  num get startPressure => _startPressure;
  String get stopPressure => _stopPressure;
  String get suctionValve => _suctionValve;
  String get deliveryValve => _deliveryValve;
  String get pressureGauge => _pressureGauge;
  String get operationalStatus => _operationalStatus;
  String? get comments => _comments;

  // Getters for static fields
  int get capacity => _capacity;
  int get head => _head;
  int get ratedPower => _ratedPower;

  Pump? _pump;

  Future<void> _loadPumpDetails() async {
    try {
      final pumpDetails = await _supabaseService.getPumpDetails(pumpId);
      _pump = Pump.fromJson(pumpDetails);
      _status = _pump?.status ?? 'Not Working';
      _mode = _pump?.mode ?? 'Manual';
      _startPressure = _pump?.startPressure ?? 0;
      _stopPressure = _pump?.stopPressure ?? '0';
      _suctionValve = _pump?.suctionValve ?? 'Closed';
      _deliveryValve = _pump?.deliveryValve ?? 'Closed';
      _pressureGauge = _pump?.pressureGauge ?? 'Not Working';
      _capacity = _pump?.capacity ?? 0;
      _head = _pump?.head ?? 0;
      _ratedPower = _pump?.ratedPower ?? 0;
      _comments = _pump?.comments ?? 'Please enter comments';
      _updateOperationalStatus();
      notifyListeners();
    } catch (e) {
      print('Error loading pump details: $e');
    }
  }

  void _updateOperationalStatus() {
    if (_suctionValve.toLowerCase() == 'opened' &&
        _deliveryValve.toLowerCase() == 'opened' &&
        _pressureGauge.toLowerCase() == 'working') {
      _operationalStatus = 'Operating';
    } else {
      _operationalStatus = 'Non-Operating';
    }
  }

  Future<void> initializeVoice() async {
    _isVoiceEnabled = await _voiceService.initialize();
    notifyListeners();
  }

  void setupVoiceListeners() {
    _voiceService.commandStream.listen(handleVoiceCommand);
    _voiceService.responseStream.listen((response) {
      _extractPumpDetails(response);
      _savePumpDetails();
    });
  }

  Future<void> startVoiceListening() async {
    if (_isVoiceEnabled) {
      await _voiceService.startListening();
    }
  }

  Future<void> stopVoiceListening() async {
    await _voiceService.stopListening();
  }

  void handleVoiceCommand(String command) {
    _lastVoiceCommand = command;
    _voiceService.processCommand(command);
  }

  void _extractPumpDetails(String response) {
    if (response.toLowerCase().contains('status is working')) {
      _status = 'Working';
      notifyListeners();
    } else if (response.toLowerCase().contains('status is not working')) {
      _status = 'Not Working';
      notifyListeners();
    }

    if (response.toLowerCase().contains('mode is auto')) {
      _mode = 'Auto';
      notifyListeners();
    } else if (response.toLowerCase().contains('mode is manual')) {
      _mode = 'Manual';
      notifyListeners();
    }

    final pressureMatch = RegExp(
      r'(\d+(\.\d+)?)\s*kg/cm²',
    ).firstMatch(response);
    if (pressureMatch != null) {
      final pressure = pressureMatch.group(1)!;
      if (response.toLowerCase().contains('start pressure')) {
        _startPressure = double.tryParse(pressure) ?? 0;
      } else if (response.toLowerCase().contains('stop pressure')) {
        _stopPressure = pressure;
      }
      notifyListeners();
    }

    if (response.toLowerCase().contains('suction valve is opened')) {
      _suctionValve = 'Opened';
      _updateOperationalStatus();
      notifyListeners();
    } else if (response.toLowerCase().contains('suction valve is closed')) {
      _suctionValve = 'Closed';
      _updateOperationalStatus();
      notifyListeners();
    }

    if (response.toLowerCase().contains('delivery valve is opened')) {
      _deliveryValve = 'Opened';
      _updateOperationalStatus();
      notifyListeners();
    } else if (response.toLowerCase().contains('delivery valve is closed')) {
      _deliveryValve = 'Closed';
      _updateOperationalStatus();
      notifyListeners();
    }

    if (response.toLowerCase().contains('pressure gauge is working')) {
      _pressureGauge = 'Working';
      _updateOperationalStatus();
      notifyListeners();
    } else if (response.toLowerCase().contains(
      'pressure gauge is not working',
    )) {
      _pressureGauge = 'Not Working';
      _updateOperationalStatus();
      notifyListeners();
    }
  }

  Future<void> _savePumpDetails() async {
    try {
      if (_pump == null) {
        print('No pump loaded to update.');
        return;
      }

      final updatedPump = await _supabaseService.updatePump(
        _pump!.copyWith(
          status: _status,
          mode: _mode,
          startPressure: _startPressure,
          stopPressure: _stopPressure,
          suctionValve: _suctionValve,
          deliveryValve: _deliveryValve,
          pressureGauge: _pressureGauge,
          operationalStatus: _operationalStatus,
          comments: _comments,
          capacity: _capacity,
          head: _head,
          ratedPower: _ratedPower,
        ),
      );
      _pump = updatedPump;
      notifyListeners();
    } catch (e) {
      print('Error saving pump details: $e');
      rethrow;
    }
  }

  // Methods to update static fields manually
  Future<void> updateCapacity(num value) async {
    _capacity = value.toInt();
    notifyListeners();
  }

  Future<void> updateHead(num value) async {
    _head = value.toInt();
    notifyListeners();
  }

  Future<void> updateRatedPower(num value) async {
    _ratedPower = value.toInt();
    notifyListeners();
  }

  Future<void> updateStatus(String value) async {
    _status = value;
    notifyListeners();
  }

  Future<void> updateMode(String value) async {
    _mode = value;
    notifyListeners();
  }

  Future<void> updatePressureGauge(String value) async {
    _pressureGauge = value;
    _updateOperationalStatus();
    notifyListeners();
  }

  Future<void> updateStartPressure(num value) async {
    _startPressure = value;
    notifyListeners();
  }

  Future<void> updateStopPressure(String value) async {
    _stopPressure = value;
    notifyListeners();
  }

  Future<void> updateSuctionValve(String value) async {
    _suctionValve = value;
    _updateOperationalStatus();
    notifyListeners();
  }

  Future<void> updateDeliveryValve(String value) async {
    _deliveryValve = value;
    _updateOperationalStatus();
    notifyListeners();
  }

  Future<void> updateComments(String? value) async {
    _comments = value;
    notifyListeners();
  }

  Future<void> saveToDatabase() async {
    try {
      if (_pump == null) {
        print('No pump loaded to update.');
        return;
      }

      final updatedPump = await _supabaseService.updatePump(
        _pump!.copyWith(
          status: _status,
          mode: _mode,
          startPressure: _startPressure,
          stopPressure: _stopPressure,
          suctionValve: _suctionValve,
          deliveryValve: _deliveryValve,
          pressureGauge: _pressureGauge,
          operationalStatus: _operationalStatus,
          comments: _comments,
          capacity: _capacity,
          head: _head,
          ratedPower: _ratedPower,
        ),
      );
      _pump = updatedPump;
      notifyListeners();
    } catch (e) {
      print('Error saving pump details: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }
}
