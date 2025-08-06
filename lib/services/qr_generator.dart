import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';

Future<String> generateAndUploadQrImage(
  String premiseId, {
  String? premiseName,
}) async {
  try {
    print('Starting QR code generation for premise: $premiseId');
    // Create a data object that includes both the ID and name
    final Map<String, dynamic> qrData = {
      'id': premiseId,
      'name': premiseName ?? 'Unknown Premise',
    };

    // Convert to JSON string for QR code
    final String qrDataString = jsonEncode(qrData);

    print('QR data: $qrDataString');

    final qrValidationResult = QrValidator.validate(
      data: qrDataString,
      version: QrVersions.auto,
      errorCorrectionLevel:
          QrErrorCorrectLevel
              .M, // Medium error correction for better readability
    );

    if (qrValidationResult.status != QrValidationStatus.valid) {
      throw Exception("Invalid QR data for premise: $premiseId");
    }

    final qrCode = qrValidationResult.qrCode!;
    final painter = QrPainter.withQr(
      qr: qrCode,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
      gapless: true,
    );

    print('Generating QR image...');
    final image = await painter.toImage(300);
    final ByteData? byteData = await image.toByteData(
      format: ImageByteFormat.png,
    );
    if (byteData == null)
      throw Exception(
        'Failed to generate QR code image for premise: $premiseId',
      );
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final fileName = 'public/$premiseId.png';
    print('Uploading QR code to Supabase storage: $fileName');
    await Supabase.instance.client.storage
        .from('qr-codes')
        .uploadBinary(
          fileName,
          pngBytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );

    print('Upload completed successfully');
    final qrurl = Supabase.instance.client.storage
        .from('qr-codes')
        .getPublicUrl(fileName);
    print('Generated QR code URL: $qrurl');

    return qrurl;
  } catch (e) {
    print('Error in generateAndUploadQrImage for premise $premiseId: $e');
    rethrow; // Rethrow to ensure the error is caught in createPremise
  }
}
