import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TestPdfService {
  static Future<void> testPdfGeneration() async {
    try {
      print('Starting PDF generation test...');
      
      // Create a simple PDF document
      final pdf = pw.Document();
      
      // Test font loading
      print('Loading fonts...');
      final fontRegular = await PdfGoogleFonts.openSansRegular();
      print('Font loaded successfully');
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text(
                'Test PDF Generation',
                style: pw.TextStyle(font: fontRegular, fontSize: 24),
              ),
            );
          },
        ),
      );
      
      print('Generating PDF bytes...');
      final bytes = await pdf.save();
      print('PDF bytes generated: ${bytes.length} bytes');
      
      if (kIsWeb) {
        print('Running on web - using Printing.sharePdf');
        await Printing.sharePdf(
          bytes: bytes, 
          filename: 'test_pdf.pdf'
        );
        print('PDF shared successfully on web');
      } else {
        print('Running on mobile/desktop');
        await Printing.sharePdf(
          bytes: bytes, 
          filename: 'test_pdf.pdf'
        );
        print('PDF shared successfully');
      }
      
    } catch (e, stackTrace) {
      print('PDF Generation Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
}