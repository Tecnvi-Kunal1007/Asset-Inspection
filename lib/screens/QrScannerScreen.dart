import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatelessWidget {
  final void Function(String scannedData) onScan;

  const QrScannerScreen({super.key, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        onDetect: (capture) {
          final barcode = capture.barcodes.first;
          if (barcode.rawValue != null) {
            onScan(barcode.rawValue!);
            Navigator.pop(context); // Go back after scanning
          }
        },
      ),
    );
  }
}
