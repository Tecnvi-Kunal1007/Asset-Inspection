import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class UhfBleScanner extends StatefulWidget {
  final Function(String) onTagScanned;
  const UhfBleScanner({Key? key, required this.onTagScanned}) : super(key: key);

  @override
  State<UhfBleScanner> createState() => _UhfBleScannerState();
}

class _UhfBleScannerState extends State<UhfBleScanner> {
  String _status = "Scanning for UHF Reader...";
  BluetoothDevice? _device;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  void _startScan() async {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.name.contains("UHF")) { // 👈 yaha apne reader ka name filter lagana hoga
          setState(() => _status = "Found UHF Reader: ${r.device.name}");
          _device = r.device;
          await FlutterBluePlus.stopScan();
          _connectToDevice();
          break;
        }
      }
    });
  }

  void _connectToDevice() async {
    if (_device == null) return;

    await _device!.connect();
    setState(() => _status = "Connected to ${_device!.name}");

    // Services discover karo
    List<BluetoothService> services = await _device!.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          // listen to notifications (tag UID)
          characteristic.setNotifyValue(true);
          characteristic.lastValueStream.listen((value) {
            String uid = value.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
            setState(() => _status = "Scanned Tag: $uid");
            widget.onTagScanned(uid);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(_status));
  }
}