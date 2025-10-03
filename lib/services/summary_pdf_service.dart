import 'dart:io';
import 'dart:typed_data';

// ✅ Only available on web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';

class EnhancedSummaryPdfService {
  // Theme configurations
  static const Map<String, Map<String, dynamic>> themes = {
    'default': {
      'primaryColor': '#1E40AF', // Deep Blue
      'secondaryColor': '#06B6D4', // Cyan
      'accentColor': '#10B981', // Green
      'warningColor': '#F59E0B', // Amber
      'errorColor': '#EF4444', // Red
      'lightBackground': '#F8FAFC', // Light gray
      'cardBackground': '#FFFFFF', // White
      'fontFamily': 'Helvetica',
    },
    'dark': {
      'primaryColor': '#3B82F6', // Royal Blue
      'secondaryColor': '#22D3EE', // Light Cyan
      'accentColor': '#34D399', // Light Green
      'warningColor': '#FBBF24', // Light Amber
      'errorColor': '#F87171', // Light Red
      'lightBackground': '#1F2937', // Dark Gray
      'cardBackground': '#374151', // Darker Gray
      'fontFamily': 'Times',
    },
    'vibrant': {
      'primaryColor': '#9333EA', // Purple
      'secondaryColor': '#F472B6', // Pink
      'accentColor': '#FCD34D', // Yellow
      'warningColor': '#F59E0B', // Amber
      'errorColor': '#EF4444', // Red
      'lightBackground': '#F3E8FF', // Light Purple
      'cardBackground': '#FFFFFF', // White
      'fontFamily': 'Arial',
    },
  };

  // Dynamic color and font based on theme
  late PdfColor primaryColor;
  late PdfColor secondaryColor;
  late PdfColor accentColor;
  late PdfColor warningColor;
  late PdfColor errorColor;
  late PdfColor lightBackground;
  late PdfColor cardBackground;
  late String fontFamily;

  // Initialize theme
  void setTheme(String themeName) {
    final theme = themes[themeName] ?? themes['default']!;
    primaryColor = PdfColor.fromHex(theme['primaryColor']);
    secondaryColor = PdfColor.fromHex(theme['secondaryColor']);
    accentColor = PdfColor.fromHex(theme['accentColor']);
    warningColor = PdfColor.fromHex(theme['warningColor']);
    errorColor = PdfColor.fromHex(theme['errorColor']);
    lightBackground = PdfColor.fromHex(theme['lightBackground']);
    cardBackground = PdfColor.fromHex(theme['cardBackground']);
    fontFamily = theme['fontFamily'];
  }

  // Enhanced text style creation with theme support
  pw.TextStyle _createTextStyle({
    double fontSize = 12,
    PdfColor? color,
    pw.FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    return pw.TextStyle(
      font: pw.Font.helvetica(),
      fontSize: fontSize,
      color: color ?? PdfColors.black,
      fontWeight: fontWeight ?? pw.FontWeight.normal,
      letterSpacing: letterSpacing,
    );
  }

  // Enhanced info row builder with icons and better styling
  pw.Widget _buildInfoRow(String label, String value, {String? icon}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: cardBackground,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: lightBackground, width: 1),
        boxShadow: [
          pw.BoxShadow(
              color: PdfColors.grey300,
              offset: const PdfPoint(0, 2),
              blurRadius: 4,
            ),
        ],
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (icon != null)
            pw.Container(
              width: 20,
              height: 20,
              margin: const pw.EdgeInsets.only(right: 12),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Center(
                child: pw.Text(
                  icon,
                  style: _createTextStyle(
                    fontSize: 10,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          pw.Container(
            width: 120,
            child: pw.Text(
              "$label:",
              style: _createTextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: primaryColor,
                ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value.isNotEmpty ? value : "N/A",
              style: _createTextStyle(
                fontSize: 11,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Web download method
  void _downloadPdfWeb(Uint8List bytes, String fileName) {
    try {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = fileName
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      print('Error downloading PDF on web: $e');
      rethrow;
    }
  }

  // Updated summary parsing method for new paragraph format
  List<pw.Widget> _buildFormattedSummary(String summary) {
    List<pw.Widget> widgets = [];

    print('=== Enhanced Summary Parsing Debug ===');
    print('Summary length: ${summary.length}');

    if (summary.isEmpty || summary.trim().isEmpty) {
      widgets.add(_buildErrorWidget('No summary content available.'));
      return widgets;
    }

    try {
      // Parse paragraphs using regex for the new structure
      final paragraphs = {
        'premise': _parseParagraph(summary, r'\[Premise Summary\](.*?)(?=\[Section Analysis\]|\Z)'),
        'section': _parseParagraph(summary, r'\[Section Analysis\](.*?)(?=\[Subsection Analysis\]|\Z)'),
        'subsection': _parseParagraph(summary, r'\[Subsection Analysis\](.*?)(?=\[Products Analysis\]|\Z)'),
        'products': _parseParagraph(summary, r'\[Products Analysis\](.*?)(?=\Z)'),
      };

      // Build each paragraph section
      if (paragraphs['premise'] != null) {
        widgets.add(_buildParagraphSection('Premise Summary', paragraphs['premise']!));
      }
      if (paragraphs['section'] != null) {
        widgets.add(_buildParagraphSection('Section Analysis', paragraphs['section']!));
      }
      if (paragraphs['subsection'] != null) {
        widgets.add(_buildParagraphSection('Subsection Analysis', paragraphs['subsection']!));
      }
      if (paragraphs['products'] != null) {
        widgets.add(_buildParagraphSection('Products Analysis', paragraphs['products']!));
      }

      if (widgets.isEmpty) {
        widgets.add(_buildFallbackContent(summary));
      }
    } catch (e) {
      print('Error parsing enhanced summary: $e');
      widgets.clear();
      widgets.add(_buildFallbackContent(summary));
    }

    return widgets;
  }

  // Parse a single paragraph section
  String? _parseParagraph(String summary, String pattern) {
    final match = RegExp(pattern, multiLine: true, dotAll: true).firstMatch(summary);
    return match?.group(1)?.trim().replaceAll('\n', ' ');
  }

  // Build paragraph section widget with gradient
  pw.Widget _buildParagraphSection(String title, String content) {
    final lines = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [accentColor, primaryColor],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(8),
        boxShadow: [
          pw.BoxShadow(
            color: PdfColors.grey200,
            offset: const PdfPoint(0, 4),
            blurRadius: 6,
          ),
        ],
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: _createTextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: cardBackground,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: lines.take(3).map((line) => pw.Text(
                line.trim(),
                style: _createTextStyle(fontSize: 11, color: primaryColor),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Error widget
  pw.Widget _buildErrorWidget(String message) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.red100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: errorColor),
      ),
      child: pw.Text(
        message,
        style: _createTextStyle(fontSize: 12, color: errorColor),
      ),
    );
  }

  // Fallback content builder
  pw.Widget _buildFallbackContent(String summary) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: lightBackground),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      width: double.infinity,
      child: pw.Text(
        summary.length > 2000 ? '${summary.substring(0, 2000)}...' : summary,
        style: _createTextStyle(fontSize: 11),
      ),
    );
  }

  // MAIN PDF GENERATION METHOD (Enhanced) with theme support
  Future<void> generateSummaryReport({
    required String summary,
    required String premiseName,
    required Map<String, dynamic> originalData,
    String theme = 'default', // Default theme, can be 'default', 'dark', or 'vibrant'
  }) async {
    // Set the selected theme
    setTheme(theme);

    try {
      print('=== Enhanced PDF Service Debug ===');
      print('Starting enhanced PDF generation with theme: $theme');
      print('Summary length: ${summary.length}');
      print('Premise name: $premiseName');

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            try {
              return [
                // Enhanced Header with gradient
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(24),
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                    ),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "INSPECTION SUMMARY REPORT",
                        style: _createTextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        "AI-Generated Analysis & Insights",
                        style: _createTextStyle(
                          fontSize: 14,
                          color: PdfColors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(20),
                        ),
                        child: pw.Text(
                          "Generated on ${DateTime.now().toString().split(' ')[0]}",
                          style: _createTextStyle(
                            fontSize: 12,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                // Enhanced Premise Information with gradient
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [lightBackground, cardBackground],
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                    ),
                    borderRadius: pw.BorderRadius.circular(12),
                    boxShadow: [
                      pw.BoxShadow(
                        color: PdfColors.grey200,
                        offset: const PdfPoint(0, 4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 4,
                            height: 24,
                            decoration: pw.BoxDecoration(
                              color: primaryColor,
                              borderRadius: pw.BorderRadius.circular(2),
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Text(
                            "Premise Information",
                            style: _createTextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 16),
                      _buildInfoRow("Premise Name", premiseName.isNotEmpty ? premiseName : "Not specified", icon: "🏢"),
                      _buildInfoRow("Report Generated", DateTime.now().toString().split(' ')[0], icon: "📅"),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                // Main AI Summary Section with enhanced styling
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [accentColor, primaryColor],
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                    ),
                    borderRadius: pw.BorderRadius.circular(12),
                    boxShadow: [
                      pw.BoxShadow(
                        color: PdfColors.grey200,
                        offset: const PdfPoint(0, 6),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 6,
                            height: 30,
                            decoration: pw.BoxDecoration(
                              color: accentColor,
                              borderRadius: pw.BorderRadius.circular(3),
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Text(
                            "AI Analysis Summary",
                            style: _createTextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),

                      pw.SizedBox(height: 20),

                      // Summary content with enhanced error handling
                      ...(() {
                        try {
                          final summaryWidgets = _buildFormattedSummary(summary);
                          print('Generated ${summaryWidgets.length} enhanced summary widgets');
                          return summaryWidgets.isNotEmpty ? summaryWidgets : [
                            _buildErrorWidget('Summary content is being processed...'),
                          ];
                        } catch (e) {
                          print('Error building enhanced summary widgets: $e');
                          return [
                            _buildErrorWidget('Error processing summary content. Please try again.'),
                            pw.SizedBox(height: 12),
                            _buildFallbackContent(summary),
                          ];
                        }
                      })(),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                // Enhanced Footer with gradient
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [lightBackground, secondaryColor],
                      begin: pw.Alignment.topCenter,
                      end: pw.Alignment.bottomCenter,
                    ),
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: lightBackground),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        "This comprehensive report was automatically generated using advanced AI analysis",
                        style: _createTextStyle(
                          fontSize: 11,
                          color: primaryColor,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        "Generated by Tecnvirons AI • ${DateTime.now().toString().split(' ')[0]} • Report ID: ${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}",
                        style: _createTextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ];
            } catch (e) {
              print('Error building enhanced page content: $e');
              return [
                pw.Center(
                  child: _buildErrorWidget('Error generating report content: $e'),
                ),
              ];
            }
          },
        ),
      );

      print('Generating enhanced PDF bytes...');
      final bytes = await pdf.save();
      print('Enhanced PDF bytes generated successfully: ${bytes.length} bytes');

      if (bytes.isEmpty) {
        throw Exception('Generated PDF is empty - no bytes were created');
      }

      if (kIsWeb) {
        print('Downloading enhanced PDF on web...');
        _downloadPdfWeb(bytes, 'tecnvirons_enhanced_ai_summary_report_$theme.pdf');
      } else {
        print('Saving enhanced PDF on mobile/desktop...');
        final dir = await getTemporaryDirectory();
        final file = File("${dir.path}/tecnvirons_enhanced_ai_summary_report_$theme.pdf");
        await file.writeAsBytes(bytes);
        await Printing.sharePdf(bytes: bytes, filename: 'tecnvirons_enhanced_ai_summary_report_$theme.pdf');
      }

      print('Enhanced PDF generation completed successfully');
    } catch (e, stackTrace) {
      print('Enhanced PDF Generation Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Enhanced test method
  Future<void> generateEnhancedTestPdf({String theme = 'default'}) async {
    setTheme(theme);

    try {
      print('Generating enhanced test PDF with theme: $theme...');

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (context) => pw.Container(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(24),
                  decoration: pw.BoxDecoration(
                    gradient: pw.LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: pw.Alignment.topLeft,
                      end: pw.Alignment.bottomRight,
                    ),
                    borderRadius: pw.BorderRadius.circular(12),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Enhanced PDF Test',
                        style: _createTextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Testing enhanced styling and layout',
                        style: _createTextStyle(fontSize: 14, color: PdfColors.white),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                _buildQuickStatsSection('Test Stats', {
                  'Total Sections': '3',
                  'Total Items': '15',
                  'Overall Condition': 'Good',
                  'Last Updated': DateTime.now().toString().split(' ')[0],
                }),

                pw.SizedBox(height: 24),

                _buildSectionWidget({
                  'name': 'Test Section',
                  'summary': 'This is a test section to verify the enhanced PDF generation with better styling and layout.',
                  'stats': {
                    'Items': '5',
                    'Condition': 'Good',
                    'Issues': '0',
                  },
                  'subsections': [
                    {
                      'name': 'Test Subsection',
                      'summary': 'This is a test subsection',
                      'stats': {'Items': '2', 'Status': 'Active'},
                    }
                  ],
                }),
              ],
            ),
          ),
        ),
      );

      final bytes = await pdf.save();
      print('Enhanced test PDF bytes: ${bytes.length}');

      if (kIsWeb) {
        _downloadPdfWeb(bytes, 'enhanced_test_pdf_$theme.pdf');
      } else {
        final dir = await getTemporaryDirectory();
        final file = File("${dir.path}/enhanced_test_pdf_$theme.pdf");
        await file.writeAsBytes(bytes);
        await Printing.sharePdf(bytes: bytes, filename: 'enhanced_test_pdf_$theme.pdf');
      }

      print('Enhanced test PDF generated successfully');
    } catch (e) {
      print('Enhanced test PDF generation failed: $e');
      rethrow;
    }
  }

  // Placeholder methods for completeness (to be implemented as needed)
  pw.Widget _buildQuickStatsSection(String title, Map<String, String> stats) {
    return pw.Container(); // Implement as needed
  }

  pw.Widget _buildSectionWidget(Map<String, dynamic> section) {
    return pw.Container(); // Implement as needed
  }
}

extension on pw.Font {
  // Removed the invalid family setter extension
}