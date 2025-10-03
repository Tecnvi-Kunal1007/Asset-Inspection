import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PdfService {
  PdfColor get textColor => PdfColor.fromHex('#2C2C2C');

  Future<void> generatePremiseReport(Map<String, dynamic> data) async {
    // Debug: Print the received data to console
    print('=== DEBUG: Received premise data ===');
    print('Full data: $data');
    print('Premise data column: ${data['data']}');
    print('Data type: ${data['data'].runtimeType}');
    print('=====================================');

    final pdf = pw.Document();

    // Load custom fonts (optional - you can add your own fonts)
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontItalic = await PdfGoogleFonts.openSansItalic();

    // Define color scheme
    final primaryColor = PdfColor.fromHex('#2E86AB'); // Professional blue
    final accentColor = PdfColor.fromHex('#A23B72'); // Accent color
    final lightGray = PdfColor.fromHex('#F5F5F5');
    final darkGray = PdfColor.fromHex('#333333');
    final textColor = PdfColor.fromHex('#2C2C2C');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(fontBold, primaryColor),
        footer: (context) => _buildFooter(fontRegular, fontItalic, primaryColor, accentColor, context),
        build: (context) => [
          // Main content
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Report title section
              pw.Container(
                width: double.infinity,
                padding: pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    colors: [primaryColor, accentColor],
                    begin: pw.Alignment.centerLeft,
                    end: pw.Alignment.centerRight,
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "PREMISE REPORT",
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 28,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      "Comprehensive Analysis & Documentation",
                      style: pw.TextStyle(
                        font: fontItalic,
                        fontSize: 14,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Premise basic information
              _buildInfoCard(
                "Premise Information",
                [
                  _buildInfoRow("Premise Name", data['name'] ?? 'N/A', fontRegular, fontBold, textColor),
                  _buildInfoRow("Created At", data['created_at'] ?? 'N/A', fontRegular, fontBold, textColor),
                ],
                lightGray,
                primaryColor,
                fontBold,
              ),

              pw.SizedBox(height: 20),

              // Premise details
              if (data['data'] != null && data['data'] is Map) ...[
                _buildInfoCard(
                  "Premise Details",
                  _buildFormattedSectionData(data['data'], fontRegular, fontBold, textColor),
                  lightGray,
                  primaryColor,
                  fontBold,
                ),
                pw.SizedBox(height: 20),
              ],

              // Premise Products
              if ((data['premise_products'] as List? ?? []).isNotEmpty) ...[
                _buildProductSection(
                  "Premise Products",
                  data['premise_products'] as List,
                  lightGray,
                  primaryColor,
                  accentColor,
                  fontRegular,
                  fontBold,
                ),
                pw.SizedBox(height: 20),
              ],

              // Sections
              ...((data['sections'] as List? ?? []).map((section) =>
                  _buildSectionCard(
                    section,
                    lightGray,
                    primaryColor,
                    accentColor,
                    fontRegular,
                    fontBold,
                  ))),
            ],
          )
        ],
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: 'tecnvirons_premise_report.pdf');
    } else {
      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/tecnvirons_premise_report.pdf");
      await file.writeAsBytes(bytes);
      await Printing.sharePdf(bytes: bytes, filename: 'tecnvirons_premise_report.pdf');
    }
  }

  // Header builder
  pw.Widget _buildHeader(pw.Font fontBold, PdfColor primaryColor) {
    return pw.Container(
      padding: pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: primaryColor, width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "TECNVIRONS",
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 24,
                  color: primaryColor,
                ),
              ),
              pw.Text(
                "You Build it, We Perfect it",
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 10,
                  color: PdfColor.fromHex('#666666'),
                ),
              ),
            ],
          ),
          pw.Text(
            "Report Generated: ${DateTime.now().toString().split(' ')[0]}",
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 10,
              color: PdfColor.fromHex('#666666'),
            ),
          ),
        ],
      ),
    );
  }

  // Footer builder
  pw.Widget _buildFooter(pw.Font fontRegular, pw.Font fontItalic, PdfColor primaryColor, PdfColor accentColor, pw.Context context) {
    return pw.Container(
      padding: pw.EdgeInsets.only(top: 20),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: primaryColor, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "TECNVIRONS",
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 16,
                  color: primaryColor,
                ),
              ),
              pw.Text(
                "You Build it, We Perfect it",
                style: pw.TextStyle(
                  font: fontItalic,
                  fontSize: 12,
                  color: accentColor,
                ),
              ),
            ],
          ),
          pw.Text(
            "Page ${context.pageNumber} of ${context.pagesCount}",
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 10,
              color: PdfColor.fromHex('#666666'),
            ),
          ),
        ],
      ),
    );
  }

  // Info card builder
  pw.Widget _buildInfoCard(String title, List<pw.Widget> children, PdfColor lightGray, PdfColor primaryColor, pw.Font fontBold) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: lightGray,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: primaryColor.shade(0.3), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 16,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: pw.EdgeInsets.all(15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // Info row builder
  pw.Widget _buildInfoRow(String label, String value, pw.Font fontRegular, pw.Font fontBold, PdfColor textColor) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              "$label:",
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
          pw.Expanded(
            flex: 5,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 12,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Product section builder
  pw.Widget _buildProductSection(String title, List products, PdfColor lightGray, PdfColor primaryColor, PdfColor accentColor, pw.Font fontRegular, pw.Font fontBold) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        color: lightGray,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: accentColor.shade(0.3), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: accentColor,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 16,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: pw.EdgeInsets.all(15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: products.map((product) => pw.Container(
                margin: pw.EdgeInsets.only(bottom: 15),
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: primaryColor.shade(0.2), width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "• ${product['name'] ?? 'Unnamed Product'}",
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 12,
                        color: primaryColor,
                      ),
                    ),
                    if (product['data'] != null && product['data'] is Map)
                      ..._buildFormattedSectionData(
                        product['data'],
                        fontRegular,
                        fontBold,
                        textColor,
                      ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Section card builder - FIXED VERSION with proper formatting
  pw.Widget _buildSectionCard(Map section, PdfColor lightGray, PdfColor primaryColor, PdfColor accentColor, pw.Font fontRegular, pw.Font fontBold) {
    return pw.Container(
      width: double.infinity,
      margin: pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        color: lightGray,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: primaryColor.shade(0.3), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(15),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              "Section: ${section['name'] ?? 'Unnamed'}",
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 16,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.Container(
            padding: pw.EdgeInsets.all(15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Section data - IMPROVED FORMATTING
                if (section['data'] != null) ...[
                  pw.Container(
                    width: double.infinity,
                    padding: pw.EdgeInsets.all(12),
                    margin: pw.EdgeInsets.only(bottom: 15),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: primaryColor.shade(0.2), width: 1),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          "Section Details:",
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 12,
                            color: primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        // FIXED: Proper parsing and formatting of section data
                        ..._buildFormattedSectionData(
                          section['data'],
                          fontRegular,
                          fontBold,
                          textColor,
                        ),
                      ],
                    ),
                  ),
                ],

                // Section Products
                if ((section['section_products'] as List? ?? []).isNotEmpty) ...[
                  pw.Text(
                    "Section Products:",
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 12,
                      color: accentColor,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  ...((section['section_products'] as List).map((product) =>
                      pw.Container(
                        margin: pw.EdgeInsets.only(bottom: 8),
                        padding: pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              "• ${product['name'] ?? 'Unnamed'}",
                              style: pw.TextStyle(font: fontBold, fontSize: 10),
                            ),
                            if (product['data'] != null && product['data'] is Map)
                              ..._buildFormattedSectionData(
                                product['data'],
                                fontRegular,
                                fontBold,
                                textColor,
                              ),
                          ],
                        ),
                      ))),
                  pw.SizedBox(height: 15),
                ],

                // Subsections
                ...((section['subsections'] as List? ?? []).map((subsection) =>
                    pw.Container(
                      margin: pw.EdgeInsets.only(bottom: 15),
                      padding: pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: accentColor.shade(0.2), width: 1),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Subsection: ${subsection['name'] ?? 'Unnamed'}",
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 12,
                              color: accentColor,
                            ),
                          ),
                          pw.SizedBox(height: 5),

                          // Subsection data with proper formatting
                          if (subsection['data'] != null) ...[
                            pw.SizedBox(height: 8),
                            ..._buildFormattedSectionData(
                              subsection['data'],
                              fontRegular,
                              fontBold,
                              textColor,
                            ),
                          ],

                          // Subsection Products
                          if ((subsection['subsection_products'] as List? ?? []).isNotEmpty) ...[
                            pw.SizedBox(height: 8),
                            pw.Text(
                              "Subsection Products:",
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: 10,
                                color: primaryColor,
                              ),
                            ),
                            ...((subsection['subsection_products'] as List).map((product) =>
                                pw.Container(
                                  margin: pw.EdgeInsets.only(top: 5, left: 10),
                                  child: pw.Column(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Text(
                                        "• ${product['name'] ?? 'Unnamed'}",
                                        style: pw.TextStyle(font: fontBold, fontSize: 9),
                                      ),
                                      if (product['data'] != null && product['data'] is Map)
                                        ..._buildFormattedSectionData(
                                          product['data'],
                                          fontRegular,
                                          fontBold,
                                          textColor,
                                        ),
                                    ],
                                  ),
                                ))),
                          ],
                        ],
                      ),
                    ))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced helper method for formatting section data with proper key-value pairs
  List<pw.Widget> _buildFormattedSectionData(
      dynamic data,
      pw.Font fontRegular,
      pw.Font fontBold,
      PdfColor textColor,
      ) {
    List<pw.Widget> widgets = [];
    Map<String, dynamic> dataMap = {};

    try {
      if (data is Map) {
        // Direct map from backend
        dataMap = Map<String, dynamic>.from(data);
      } else if (data is String) {
        String dataStr = data.toString().trim();

        // Remove surrounding brackets if present
        if (dataStr.startsWith('{') && dataStr.endsWith('}')) {
          dataStr = dataStr.substring(1, dataStr.length - 1).trim();
        }

        // Split by commas and parse key-value pairs more carefully
        List<String> pairs = [];
        String currentPair = '';
        int braceCount = 0;
        
        for (int i = 0; i < dataStr.length; i++) {
          String char = dataStr[i];
          if (char == '{') braceCount++;
          if (char == '}') braceCount--;
          
          if (char == ',' && braceCount == 0) {
            pairs.add(currentPair.trim());
            currentPair = '';
          } else {
            currentPair += char;
          }
        }
        if (currentPair.trim().isNotEmpty) {
          pairs.add(currentPair.trim());
        }

        // Parse each key-value pair
        for (String pair in pairs) {
          int colonIndex = pair.indexOf(':');
          if (colonIndex > 0) {
            String key = pair.substring(0, colonIndex).trim().replaceAll('"', '');
            String value = pair.substring(colonIndex + 1).trim().replaceAll('"', '');
            
            // Clean up key formatting
            key = key.replaceAll('_', ' ');
            key = key.split(' ').map((word) => 
              word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : word
            ).join(' ');
            
            dataMap[key] = value;
          }
        }
      }

      // Build clean formatted rows from map
      dataMap.forEach((key, value) {
        widgets.add(
          pw.Container(
            margin: pw.EdgeInsets.only(bottom: 8),
            padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F8F9FA'),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColor.fromHex('#E9ECEF'), width: 0.5),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    "$key:",
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 11,
                      color: PdfColor.fromHex('#495057'),
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    value.toString(),
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 11,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      });

      if (widgets.isEmpty && data != null) {
        widgets.add(
          pw.Container(
            padding: pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#FFF3CD'),
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColor.fromHex('#FFEAA7'), width: 1),
            ),
            child: pw.Text(
              "No valid data available",
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 11,
                color: PdfColor.fromHex('#856404'),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      widgets.add(
        pw.Container(
          padding: pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F8D7DA'),
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColor.fromHex('#F5C6CB'), width: 1),
          ),
          child: pw.Text(
            "Error parsing data: ${data.toString()}",
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 11,
              color: PdfColor.fromHex('#721C24'),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  // Additional product section builder
  pw.Widget _buildAdditionalProductSection(
      Map<String, dynamic> section,
      pw.Font fontRegular,
      pw.Font fontBold,
      ) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFFFFF'),
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0'), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Section header
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#4A90A4'),
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Text(
              'Section: ${section['name'] ?? 'Unknown'}',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 14,
                color: PdfColors.white,
              ),
            ),
          ),
          // Section details
          pw.Container(
            padding: pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Section Details:',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 12,
                    color: PdfColor.fromHex('#4A90A4'),
                  ),
                ),
                pw.SizedBox(height: 8),
                ...(_buildFormattedSectionData(
                  section['data'],
                  fontRegular,
                  fontBold,
                  textColor,
                )),
                pw.SizedBox(height: 12),
                // Subsections
                if (section['subsections'] != null && section['subsections'].isNotEmpty)
                  ...section['subsections'].map<pw.Widget>((subsection) =>
                      _buildAdditionalSectionCard(subsection, fontRegular, fontBold)).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Additional section card builder for subsections
  pw.Widget _buildAdditionalSectionCard(
      Map<String, dynamic> subsection,
      pw.Font fontRegular,
      pw.Font fontBold,
      ) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 12),
      padding: pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8F9FA'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColor.fromHex('#E9ECEF'), width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#E91E63'),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'Subsection: ${subsection['name'] ?? 'Unknown'}',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 11,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          ...(_buildFormattedSectionData(
            subsection,
            fontRegular,
            fontBold,
            textColor,
          )),
        ],
      ),
    );
  }
}