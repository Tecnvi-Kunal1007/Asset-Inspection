import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/site.dart';
import '../services/supabase_service.dart';
import 'pump_details_screen.dart';

class QRScannerScreen extends StatefulWidget {
  final Site site;

  const QRScannerScreen({super.key, required this.site});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final _supabaseService = SupabaseService();
  final _scannerController = MobileScannerController();
  bool _isLoading = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(Barcode barcode) async {
    if (_isLoading) return;

    if (barcode.rawValue == null || barcode.rawValue!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR code. Please try again.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final pump = await _supabaseService.getPumpByUid(barcode.rawValue!);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => PumpDetailsScreen(pump: pump)),
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (BarcodeCapture capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                _handleBarcode(barcode);
              }
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
