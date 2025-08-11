import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/premise.dart';
import 'PremiseDetailsScreen.dart';


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

// Call this in your QR scan callback
void onQrScanned(BuildContext context, String qrData) {
  try {
    final Map<String, dynamic> data = jsonDecode(qrData);
    
    // Log the data for debugging
    print('Scanned QR data: ${data.keys.join(', ')}');
    
    // Create Premise object directly from scanned data
    // The updated Premise model now handles sections, subsections, and products
    final premise = Premise.fromMap(data);
    
    // Show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully scanned premise: ${premise.name}')),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PremiseDetailsScreen(premise: premise),
      ),
    );
  } catch (e) {
    print('Error parsing QR code: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid or corrupted QR code')),
    );
  }
}


