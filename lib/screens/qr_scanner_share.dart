import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

// filepath: lib/share_qr.dart

Future<void> sharePremiseQrCode(BuildContext context, String premiseId) async {
  final qrData = jsonEncode({'premiseId': premiseId});
  final painter = QrPainter(
    data: qrData,
    version: QrVersions.auto,
    gapless: true,
    color: const Color(0xFF000000),
    emptyColor: const Color(0xFFFFFFFF),
  );
  final picData = await painter.toImageData(300);
  final bytes = picData!.buffer.asUint8List();

  final tempDir = await getTemporaryDirectory();
  final file = await File('${tempDir.path}/premise_qr.png').create();
  await file.writeAsBytes(bytes);

  await Share.shareXFiles([XFile(file.path)], text: 'Scan this QR to get premise details!');
}

class ShareQrPage extends StatelessWidget {
  final String premiseId;

  ShareQrPage({required this.premiseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share Premise QR Code'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () => sharePremiseQrCode(context, premiseId),
          child: Text('Share Premise QR'),
        ),
      ),
    );
  }
}