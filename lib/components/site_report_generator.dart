import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site.dart';
import '../models/pump.dart';
import '../models/floor.dart';
import '../models/smoke_detector.dart';
import '../models/heat_detector.dart';
import '../models/flasher_hooter_alarm.dart';
import '../models/control_module.dart';
import '../models/flow_switch.dart';
import '../models/monitor_module.dart';
import '../models/telephone_jack.dart';
import '../models/speaker.dart';
import '../models/hydrant_valve.dart';
import '../models/hydrant_ug.dart';
import '../models/hydrant_wheel.dart';
import '../models/hydrant_cap.dart';
import '../models/hydrant_mouth_gasket.dart';
import '../models/canvas_hose.dart';
import '../models/branch_pipe.dart';
import '../models/fireman_axe.dart';
import '../models/hose_reel.dart';
import '../models/shut_off_nozzle.dart';
import '../models/key_glass.dart';
import '../models/pressure_gauge.dart';
import '../models/abc_extinguisher.dart';
import '../models/sprinkler_zcv.dart';
import '../services/supabase_service.dart';
import 'package:flutter/services.dart' show rootBundle;

class SiteReportGenerator {
  final Site site;
  final List<Pump> pumps;
  final List<Floor> floors;
  final String? siteDescription;
  final SupabaseService supabaseService;
  final String? assignedSection;

  SiteReportGenerator({
    required this.site,
    required this.pumps,
    required this.floors,
    required this.supabaseService,
    this.siteDescription,
    this.assignedSection,
  });

  @override
  Future<File> generateReport() async {
    // Pre-fetch data
    final tests = await supabaseService.getOperationalTests(site.id);
    final inspections = await supabaseService.getEngineInspections(site.id);
    final buildingAccessoriesTable = await _buildBuildingAccessoriesTable();
    final customBuildingAccessoriesTable =
        await _buildCustomBuildingAccessoriesTable();
    final fireAlarmTable = await _buildFireAlarmTable();
    final floorComponents = await _buildFloorComponents();

    // Load the logo image
    final logoImage = await rootBundle.load('assets/images/ember_logo.png');
    final logoImageBytes = logoImage.buffer.asUint8List();

    // Filter components based on assigned section
    final filteredComponents = _filterComponentsBySection(
      buildingAccessoriesTable,
      customBuildingAccessoriesTable,
      fireAlarmTable,
      floorComponents,
    );

    // Fetch site description
    final supabase = Supabase.instance.client;
    final descriptionResponse =
        await supabase
            .from('site_descriptions')
            .select('description')
            .eq('site_id', site.id)
            .maybeSingle();
    final siteDescription =
        descriptionResponse?['description'] as String? ??
        'No description available';

    // Create a PDF document
    final pdf = pw.Document();

    // Add site information to the document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header:
            (context) => pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#ffd03e'),
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.blue, width: 1),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Site Inspection Report',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.Image(
                    pw.MemoryImage(logoImageBytes),
                    width: 100,
                    height: 50,
                  ),
                ],
              ),
            ),
        footer: (context) {
          final now = DateTime.now();
          final formattedDate =
              '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#ffd03e'),
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.blue, width: 1),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  site.siteName,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
                pw.Text(
                  formattedDate,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
                pw.Text(
                  'Tecnvirons Pvt Ltd',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              ],
            ),
          );
        },
        build:
            (context) => [
              // Operational Test Section
              pw.Container(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Header(
                      level: 1,
                      text: 'Operational Test',
                      textStyle: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    _buildOperationalTestsTable(tests),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Engine Inspection Section
              pw.Container(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Header(
                      level: 1,
                      text: 'Engine Inspection',
                      textStyle: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    _buildEngineInspectionsTable(inspections),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Site Description Section
              pw.Container(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Header(
                      level: 1,
                      text: 'Site Description',
                      textStyle: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      siteDescription,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Only include pumps section if assigned to pumps_floor
              if (assignedSection == 'pumps_floor') ...[
                pw.Container(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Header(
                        level: 1,
                        text: 'Pumps Information',
                        textStyle: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      ..._buildPumpsTables(),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Add Floor Components Section right after Pumps Information
                if (floorComponents.isNotEmpty) ...[
                  pw.Container(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Header(
                          level: 1,
                          text: 'Floor Components',
                          textStyle: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        ...floorComponents,
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ],

              // Add filtered components
              ...filteredComponents,
            ],
      ),
    );

    // Save the PDF to a file
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/site_report_${site.id}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  Future<List<pw.Widget>> generateReportContent() async {
    // Pre-fetch data
    final tests = await supabaseService.getOperationalTests(site.id);
    final inspections = await supabaseService.getEngineInspections(site.id);
    final buildingAccessoriesTable = await _buildBuildingAccessoriesTable();
    final customBuildingAccessoriesTable =
        await _buildCustomBuildingAccessoriesTable();
    final fireAlarmTable = await _buildFireAlarmTable();
    final floorComponents = await _buildFloorComponents();

    // Load the logo image
    final logoImage = await rootBundle.load('assets/images/ember_logo.png');
    final logoImageBytes = logoImage.buffer.asUint8List();

    final List<pw.Widget> reportContent = [
      // Site Description Section (always included)
      pw.Container(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 1,
              text: 'Site Description',
              textStyle: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              siteDescription ?? 'No description available',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 20),
    ];

    // Add sections based on assigned section or if contractor
    if (assignedSection == null || assignedSection == 'pumps_floor') {
      // Add Operational Test Section
      reportContent.addAll([
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Operational Test',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              _buildOperationalTestsTable(tests),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Add Engine Inspection Section
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Engine Inspection',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              _buildEngineInspectionsTable(inspections),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Add Pumps Information Section
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Pumps Information',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              ..._buildPumpsTables(),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
      ]);

      // Add Floor Components Section right after Pumps Information
      if (floorComponents.isNotEmpty) {
        reportContent.add(
          pw.Container(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 1,
                  text: 'Floor Components',
                  textStyle: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
                  ),
                ),
                pw.SizedBox(height: 5),
                ...floorComponents,
              ],
            ),
          ),
        );
        reportContent.add(pw.SizedBox(height: 20));
      }
    }

    if (assignedSection == null || assignedSection == 'building_fire') {
      // Add Building Accessories Section
      reportContent.add(
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Building Accessories',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              buildingAccessoriesTable,
            ],
          ),
        ),
      );
      reportContent.add(pw.SizedBox(height: 20));

      // Add Custom Building Accessories Section
      reportContent.add(
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Custom Building Accessories',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              customBuildingAccessoriesTable,
            ],
          ),
        ),
      );
      reportContent.add(pw.SizedBox(height: 20));

      // Add Fire Alarm Components Section
      reportContent.add(
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Fire Alarm Components',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              fireAlarmTable,
            ],
          ),
        ),
      );
      reportContent.add(pw.SizedBox(height: 20));
    }

    return reportContent;
  }

  Future<List<pw.Widget>> _buildFloorComponents() async {
    final components = <pw.Widget>[];

    for (final floor in floors) {
      // Add floor header
      components.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 5),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Text(
            floor.floorType,
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ),
      );

      try {
        // Fetch all components for this floor
        final hydrantValves = await supabaseService.getHydrantValvesByFloorId(
          floor.id,
        );
        final hydrantUGs = await supabaseService.getHydrantUGsByFloorId(
          floor.id,
        );
        final hydrantWheels = await supabaseService.getHydrantWheelsByFloorId(
          floor.id,
        );
        final hydrantCaps = await supabaseService.getHydrantCapsByFloorId(
          floor.id,
        );
        final hydrantMouthGaskets = await supabaseService
            .getHydrantMouthGasketsByFloorId(floor.id);
        final canvasHoses = await supabaseService.getCanvasHosesByFloorId(
          floor.id,
        );
        final branchPipes = await supabaseService.getBranchPipesByFloorId(
          floor.id,
        );
        final firemanAxes = await supabaseService.getFiremanAxesByFloorId(
          floor.id,
        );
        final hoseReels = await supabaseService.getHoseReelsByFloorId(floor.id);
        final shutOffNozzles = await supabaseService.getShutOffNozzlesByFloorId(
          floor.id,
        );
        final keyGlasses = await supabaseService.getKeyGlassesByFloorId(
          floor.id,
        );
        final pressureGauges = await supabaseService.getPressureGaugesByFloorId(
          floor.id,
        );
        final abcExtinguishers = await supabaseService
            .getABCExtinguishersByFloorId(floor.id);
        final sprinklerZCVs = await supabaseService.getSprinklerZCVsByFloorId(
          floor.id,
        );
        final boosterPumps = await supabaseService.getBoosterPumps(floor.id);

        // Combine all components
        final allComponents = <Map<String, dynamic>>[];

        // Only add components based on assignedSection
        if (assignedSection == null || assignedSection == 'pumps_floor') {
          allComponents.addAll([
            ...hydrantValves.map(
              (c) => {
                'type': 'Hydrant Valve',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...hydrantUGs.map(
              (c) => {
                'type': 'Hydrant UG',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...hydrantWheels.map(
              (c) => {
                'type': 'Hydrant Wheel',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...hydrantCaps.map(
              (c) => {
                'type': 'Hydrant Cap',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...hydrantMouthGaskets.map(
              (c) => {
                'type': 'Hydrant Mouth Gasket',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...canvasHoses.map(
              (c) => {
                'type': 'Canvas Hose',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...branchPipes.map(
              (c) => {
                'type': 'Branch Pipe',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...firemanAxes.map(
              (c) => {
                'type': 'Fireman Axe',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...hoseReels.map(
              (c) => {
                'type': 'Hose Reel',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...shutOffNozzles.map(
              (c) => {
                'type': 'Shut Off Nozzle',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...keyGlasses.map(
              (c) => {
                'type': 'Key Glass',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...pressureGauges.map(
              (c) => {
                'type': 'Pressure Gauge',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...abcExtinguishers.map(
              (c) => {
                'type': 'ABC Extinguisher',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...sprinklerZCVs.map(
              (c) => {
                'type': 'Sprinkler ZCV',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
            ...boosterPumps.map(
              (c) => {
                'type': 'Booster Pump',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt?.toString().split('.')[0] ?? 'N/A',
              },
            ),
          ]);
        }

        if (allComponents.isNotEmpty) {
          components.add(
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Component Type',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Status',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Notes',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'Last Updated',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                ...allComponents.map(
                  (component) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          component['type'] as String? ?? '',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          component['status'] as String? ?? '',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          component['note'] as String? ?? '',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          component['updated_at'] as String? ?? '',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      } catch (e) {
        print('Error building floor components: $e');
      }
    }

    return components;
  }

  pw.Widget _buildPdfInfoTable(List<List<String>> data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      children:
          data.map((row) {
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    row[0],
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    row[1],
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          }).toList(),
    );
  }

  List<pw.Widget> _buildPumpsTables() {
    final pumpWidgets = <pw.Widget>[];

    for (final pump in pumps) {
      final isWorking = pump.status.toLowerCase() == 'working';

      pumpWidgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 20),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: isWorking ? PdfColors.green100 : PdfColors.red100,
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(5),
                    topRight: pw.Radius.circular(5),
                  ),
                ),
                child: pw.Text(
                  pump.name,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: isWorking ? PdfColors.green900 : PdfColors.red900,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(15),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfInfoTable([
                      ['Status', pump.status],
                      ['Mode', pump.mode],
                      ['Operational Status', pump.operationalStatus],
                      ['Start Pressure', '${pump.startPressure} kg/cm²'],
                      ['Stop Pressure', '${pump.stopPressure} kg/cm²'],
                      ['Suction Valve', pump.suctionValve],
                      ['Delivery Valve', pump.deliveryValve],
                      ['Pressure Gauge', pump.pressureGauge],
                      ['Capacity', '${pump.capacity} LPM'],
                      ['Head', '${pump.head} meters'],
                      ['Rated Power', '${pump.ratedPower} kW'],
                    ]),
                    if (pump.comments?.isNotEmpty ?? false) ...[
                      pw.SizedBox(height: 10),
                      pw.Text(
                        'Comments:',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                      pw.Text(
                        pump.comments!,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pumpWidgets;
  }

  Future<pw.Widget> _buildBuildingAccessoriesTable() async {
    try {
      final accessories = await supabaseService.getBuildingAccessoriesBySiteId(
        site.id,
      );

      if (accessories == null) {
        return pw.Text('No building accessories data available');
      }

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.green100),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'Accessory Type',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'Status',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'Last Updated',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'Notes',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Fire Alarm Panel'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.fireAlarmPanelStatus ?? 'Not Working',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.updatedAt?.toString().split('.')[0] ?? '',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(accessories.notes ?? ''),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Repeater Panel'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.repeaterPanelStatus ?? 'Not Working',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.updatedAt?.toString().split('.')[0] ?? '',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(accessories.notes ?? ''),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Battery'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(accessories.batteryStatus ?? 'Not Working'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.updatedAt?.toString().split('.')[0] ?? '',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(accessories.notes ?? ''),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Lift Integration Relay'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.liftIntegrationRelayStatus ?? 'Not Working',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.updatedAt?.toString().split('.')[0] ?? '',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(accessories.notes ?? ''),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Access Integration'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.accessIntegrationStatus ?? 'Not Working',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.updatedAt?.toString().split('.')[0] ?? '',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(accessories.notes ?? ''),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text('Press Fan Integration'),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.pressFanIntegrationStatus ?? 'Not Working',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  accessories.updatedAt?.toString().split('.')[0] ?? '',
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(accessories.notes ?? ''),
              ),
            ],
          ),
        ],
      );
    } catch (e) {
      print('Error building accessories table: $e');
      return pw.Text('Error loading building accessories data');
    }
  }

  Future<pw.Widget> _buildFireAlarmTable() async {
    try {
      // Get all floors for the site
      final floors = await supabaseService.getFloorsBySiteId(site.id);

      if (floors.isEmpty) {
        return pw.Text('No fire alarm data available');
      }

      final components = <pw.Widget>[];

      // For each floor, get all fire alarm components
      for (final floor in floors) {
        // Add floor header
        components.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 5),
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Text(
              floor.floorType,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red900,
              ),
            ),
          ),
        );

        try {
          // Get all fire alarm components for this floor
          final smokeDetectors = await supabaseService
              .getSmokeDetectorsByFloorId(floor.id);
          final heatDetectors = await supabaseService.getHeatDetectorsByFloorId(
            floor.id,
          );
          final flasherHooters = await supabaseService
              .getFlasherHooterAlarmsByFloorId(floor.id);
          final controlModules = await supabaseService
              .getControlModulesByFloorId(floor.id);
          final flowSwitches = await supabaseService.getFlowSwitchesByFloorId(
            floor.id,
          );
          final monitorModules = await supabaseService
              .getMonitorModulesByFloorId(floor.id);
          final telephoneJacks = await supabaseService
              .getTelephoneJacksByFloorId(floor.id);
          final speakers = await supabaseService.getSpeakersByFloorId(floor.id);

          // Combine all components
          final allComponents = [
            ...smokeDetectors.map(
              (c) => {
                'type': 'Smoke Detector',
                'status': c.status,
                'note': c.note,
                'updated_at': null,
              },
            ),
            ...heatDetectors.map(
              (c) => {
                'type': 'Heat Detector',
                'status': c.status,
                'note': c.note,
                'updated_at': null,
              },
            ),
            ...flasherHooters.map(
              (c) => {
                'type': 'Flasher Hooter',
                'status': c.status,
                'note': c.note,
                'updated_at': null,
              },
            ),
            ...controlModules.map(
              (c) => {
                'type': 'Control Module',
                'status': c.status,
                'note': c.note,
                'updated_at': null,
              },
            ),
            ...flowSwitches.map(
              (c) => {
                'type': 'Flow Switch',
                'status': c.status,
                'note': c.note,
                'updated_at': null,
              },
            ),
            ...monitorModules.map(
              (c) => {
                'type': 'Monitor Module',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt,
              },
            ),
            ...telephoneJacks.map(
              (c) => {
                'type': 'Telephone Jack',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt,
              },
            ),
            ...speakers.map(
              (c) => {
                'type': 'Speaker',
                'status': c.status,
                'note': c.note,
                'updated_at': c.updatedAt,
              },
            ),
          ];

          if (allComponents.isNotEmpty) {
            components.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Fire Alarm Components:',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red800,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(3),
                        3: const pw.FlexColumnWidth(2),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                'Component Type',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                'Status',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                'Notes',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text(
                                'Last Updated',
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ...allComponents
                            .map(
                              (component) => pw.TableRow(
                                children: [
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                      component['type'] as String? ?? '',
                                      style: const pw.TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                      component['status'] as String? ?? '',
                                      style: const pw.TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                      component['note'] as String? ?? '',
                                      style: const pw.TextStyle(fontSize: 10),
                                    ),
                                  ),
                                  pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(
                                      component['updated_at']?.toString().split(
                                            '.',
                                          )[0] ??
                                          'N/A',
                                      style: const pw.TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        } catch (e) {
          print('Error fetching fire alarm components: $e');
          components.add(
            pw.Text(
              'Error loading components for ${floor.floorType}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.red),
            ),
          );
        }
      }

      return pw.Column(children: components);
    } catch (e) {
      print('Error building fire alarm table: $e');
      return pw.Text('Error loading fire alarm data');
    }
  }

  Future<pw.Widget> _buildCustomBuildingAccessoriesTable() async {
    try {
      final response = await Supabase.instance.client
          .from('custom_building_accessories')
          .select()
          .eq('site_id', site.id)
          .order('created_at', ascending: false);

      final accessories = List<Map<String, dynamic>>.from(response);

      if (accessories.isEmpty) {
        return pw.Text('No custom building accessories available');
      }

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfColors.green100),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'Accessory Name',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'Status',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'Last Updated',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'Notes',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green900,
                  ),
                ),
              ),
            ],
          ),
          ...accessories
              .map(
                (accessory) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(accessory['accessory_name'] ?? 'N/A'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(accessory['status'] ?? 'Not Working'),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        accessory['updated_at']?.toString().split('.')[0] ??
                            'N/A',
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(accessory['notes'] ?? ''),
                    ),
                  ],
                ),
              )
              .toList(),
        ],
      );
    } catch (e) {
      print('Error building custom accessories table: $e');
      return pw.Text('Error loading custom building accessories data');
    }
  }

  pw.Widget _buildOperationalTestsTable(List<Map<String, dynamic>> tests) {
    if (tests.isEmpty) {
      return pw.Text('No operational tests available');
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Test Type',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Standard Value',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Observed Value',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Comments',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        ...tests
            .map(
              (test) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      test['test_type']?.toString() ?? '',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '${test['standard_value']?.toString() ?? ''} kg/cm²',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      '${test['observed_value']?.toString() ?? ''} kg/cm²',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      test['comments']?.toString() ?? '',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ],
    );
  }

  pw.Widget _buildEngineInspectionsTable(
    List<Map<String, dynamic>> inspections,
  ) {
    if (inspections.isEmpty) {
      return pw.Text('No engine inspections available');
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Component',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Status',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Text(
                'Comments',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        ...inspections
            .map(
              (inspection) => pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      inspection['inspection_type']?.toString() ?? '',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      inspection['value']?.toString() ?? '',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      inspection['comments']?.toString() ?? '',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ],
    );
  }

  List<pw.Widget> _filterComponentsBySection(
    pw.Widget buildingAccessoriesTable,
    pw.Widget customBuildingAccessoriesTable,
    pw.Widget fireAlarmTable,
    List<pw.Widget> floorComponents,
  ) {
    final filteredComponents = <pw.Widget>[];

    // If assignedSection is null (contractor) or no specific section is assigned,
    // include all components
    if (assignedSection == null) {
      filteredComponents.addAll([
        // Building Accessories Section
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Building Accessories',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              buildingAccessoriesTable,
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Custom Building Accessories Section
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Custom Building Accessories',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              customBuildingAccessoriesTable,
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Fire Alarm System Section
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Fire Alarm System',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              fireAlarmTable,
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // Floor Components Section
        ...floorComponents,
      ]);
    } else if (assignedSection == 'pumps_floor') {
      // For pumps_floor section, only include floor components
      filteredComponents.addAll(floorComponents);
    } else if (assignedSection == 'building_fire') {
      // For building_fire section, include building accessories and fire alarm
      filteredComponents.addAll([
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Building Accessories',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              buildingAccessoriesTable,
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 1,
                text: 'Fire Alarm System',
                textStyle: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
              pw.SizedBox(height: 5),
              fireAlarmTable,
            ],
          ),
        ),
      ]);
    }

    return filteredComponents;
  }
}
