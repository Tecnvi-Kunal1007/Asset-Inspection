import 'dart:io';
import 'dart:ui';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
// Removed import: import 'package:image/image.dart' as img;

class QRService {
  Future<File> generateQRCode(String data) async {
    final qrCode = QrPainter(
      data: data,
      version: QrVersions.auto,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF000000),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF000000),
      ),
    );

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png';

    final qrImage = await qrCode.toImage(300);
    final byteData = await qrImage.toByteData(format: ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    final file = File(path);
    await file.writeAsBytes(buffer);

    return file;
  }

  // Removed optimizeQRCode method and its usage due to image package causing errors
/*
  Future<File> optimizeQRCode(File qrCodeFile) async {
    final image = img.decodeImage(await qrCodeFile.readAsBytes())!;
    final optimizedImage = img.copyResize(image, width: 300);

    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/qr_optimized_${DateTime.now().millisecondsSinceEpoch}.png';

    final file = File(path);
    await file.writeAsBytes(img.encodePng(optimizedImage));

    return file;
  }
*/
}
