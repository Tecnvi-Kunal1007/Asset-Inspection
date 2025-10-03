import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CameraScanner extends StatelessWidget {
  final Function(String) onScanned;
  const CameraScanner({super.key, required this.onScanned});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Tag UID")),
      body: MobileScanner(
        onDetect: (capture) {
          if (capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
            final String uid = capture.barcodes.first.rawValue!;
            onScanned(uid);
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}