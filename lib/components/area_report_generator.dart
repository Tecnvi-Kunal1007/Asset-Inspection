import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/area.dart';
import '../models/site.dart';
import '../services/supabase_service.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/floor.dart';
import 'site_report_generator.dart';
import 'package:printing/printing.dart';
import '../services/openai_service.dart';

class AreaReportGenerator {
  final Area area;
  final List<Site> sites;
  final SupabaseService supabaseService;
  final String? assignedSection;
  final bool isContractor;
  final List<Map<String, dynamic>> nonWorkingComponents = [];

  AreaReportGenerator({
    required this.area,
    required this.sites,
    required this.supabaseService,
    this.assignedSection,
    this.isContractor = false,
  });

  Future<Map<String, dynamic>?> _getContractorDetails() async {
    try {
      final supabase = Supabase.instance.client;
      final response =
          await supabase
              .from('contractor')
              .select('name, email')
              .eq('id', area.contractorId)
              .single();
      return response;
    } catch (e) {
      print('Error fetching contractor details: $e');
      return null;
    }
  }

  Future<void> _collectNonWorkingComponents(
    String siteId,
    String componentType,
  ) async {
    final components = await _getAllComponentsForSite(siteId, componentType);
    for (final component in components) {
      // Convert component to Map if it's not already
      final componentMap = component is Map ? component : component.toJson();
      if (componentMap['status']?.toString().toLowerCase() == 'not working') {
        // Get floor information if the component has a floorId
        String? floorName;
        if (componentMap['floor_id'] != null) {
          final floors = await supabaseService.getFloorsBySiteId(siteId);
          final floor = floors.firstWhere(
            (f) => f.id == componentMap['floor_id'],
            orElse:
                () => Floor(
                  id: componentMap['floor_id'],
                  siteId: siteId,
                  floorType: 'Unknown Floor',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
          );
          floorName = floor.floorType;
        }

        nonWorkingComponents.add({
          'site_id': siteId,
          'component_type': componentType,
          'component_details': componentMap,
          'floor_name': floorName,
        });
      }
    }
  }

  Future<String> _generateAISummary() async {
    try {
      final openAIService = OpenAIService();

      // Format the non-working components data for better analysis
      final formattedComponents =
          nonWorkingComponents.map((component) {
            return {
              'site_name':
                  sites
                      .firstWhere(
                        (site) => site.id == component['site_id'],
                        orElse:
                            () => Site(
                              id: component['site_id'],
                              siteName: 'Unknown Site',
                              siteLocation: 'Unknown Location',
                              siteOwner: 'Unknown',
                              siteOwnerEmail: 'unknown@email.com',
                              siteOwnerPhone: 'Unknown',
                              siteManager: 'Unknown',
                              siteManagerEmail: 'unknown@email.com',
                              siteManagerPhone: 'Unknown',
                              siteInspectorName: 'Unknown',
                              siteInspectorEmail: 'unknown@email.com',
                              siteInspectorPhone: 'Unknown',
                              siteInspectorPhoto: 'unknown.jpg',
                              contractorEmail: 'unknown@email.com',
                              contractorId: 'unknown',
                              areaId: area.id,
                              createdAt: DateTime.now(), description: '',
                            ),
                      )
                      .siteName,
              'floor_name': component['floor_name'] ?? 'Site Level',
              'component_type': component['component_type'],
              'component_details': {
                'id': component['component_details']['id'],
                'location': component['component_details']['location'],
                'status': component['component_details']['status'],
                'notes': component['component_details']['notes'],
                if (component['component_details']['name'] != null)
                  'name': component['component_details']['name'],
              },
            };
          }).toList();

      final context = {
        'non_working_components': formattedComponents,
        'area_name': area.name,
        'total_components': nonWorkingComponents.length,
        'sites_count': sites.length,
      };

      final response = await openAIService.processUserInput(context);
      return response.botReply;
    } catch (e) {
      print('Error generating AI summary: $e');
      return 'Unable to generate AI summary at this time.';
    }
  }

  Future<File> generateReport() async {
    // Get contractor details
    final contractorDetails = await _getContractorDetails();
    final contractorName =
        contractorDetails?['name'] as String? ?? 'Not assigned';
    final contractorEmail =
        contractorDetails?['email'] as String? ?? 'Not assigned';

    // Load the logo image
    final logoImage = await rootBundle.load('assets/images/ember_logo.png');
    final logoImageBytes = logoImage.buffer.asUint8List();

    // Create a PDF document
    final pdf = pw.Document();

    // Clear previous non-working components
    nonWorkingComponents.clear();

    // Collect non-working components for each site
    for (final site in sites) {
      print('Processing site: ${site.siteName}'); // Debug print

      // Collect components based on assigned section or all components for contractors
      if (isContractor || assignedSection == 'floor') {
        // No longer collecting pumps
        await _collectNonWorkingComponents(site.id, 'building_accessories');
        await _collectNonWorkingComponents(
          site.id,
          'custom_building_accessories',
        );
      }
      if (isContractor || assignedSection == 'building_fire') {
        await _collectNonWorkingComponents(site.id, 'smoke_detectors');
        await _collectNonWorkingComponents(site.id, 'heat_detectors');
        await _collectNonWorkingComponents(site.id, 'flasher_hooter_alarms');
        await _collectNonWorkingComponents(site.id, 'control_modules');
        await _collectNonWorkingComponents(site.id, 'flow_switches');
        await _collectNonWorkingComponents(site.id, 'monitor_modules');
        await _collectNonWorkingComponents(site.id, 'telephone_jacks');
        await _collectNonWorkingComponents(site.id, 'speakers');
        await _collectNonWorkingComponents(site.id, 'hydrant_valves');
        await _collectNonWorkingComponents(site.id, 'hydrant_ugs');
        await _collectNonWorkingComponents(site.id, 'hydrant_wheels');
        await _collectNonWorkingComponents(site.id, 'hydrant_caps');
        await _collectNonWorkingComponents(site.id, 'hydrant_mouth_gaskets');
        await _collectNonWorkingComponents(site.id, 'canvas_hoses');
        await _collectNonWorkingComponents(site.id, 'branch_pipes');
        await _collectNonWorkingComponents(site.id, 'fireman_axes');
        await _collectNonWorkingComponents(site.id, 'hose_reels');
        await _collectNonWorkingComponents(site.id, 'shut_off_nozzles');
        await _collectNonWorkingComponents(site.id, 'key_glasses');
        await _collectNonWorkingComponents(site.id, 'pressure_gauges');
        await _collectNonWorkingComponents(site.id, 'abc_extinguishers');
        await _collectNonWorkingComponents(site.id, 'sprinkler_zcvs');
        await _collectNonWorkingComponents(site.id, 'building_accessories');
        await _collectNonWorkingComponents(
          site.id,
          'custom_building_accessories',
        );
      }
    }

    // Display non-working components in terminal
    if (nonWorkingComponents.isNotEmpty) {
      print('\n=== Non-Working Components Report ===');
      print('Area: ${area.name}');
      print('Total Non-Working Components: ${nonWorkingComponents.length}\n');

      // Group by site
      final componentsBySite = <String, List<Map<String, dynamic>>>{};
      for (final component in nonWorkingComponents) {
        final siteId = component['site_id'];
        if (!componentsBySite.containsKey(siteId)) {
          componentsBySite[siteId] = [];
        }
        componentsBySite[siteId]!.add(component);
      }

      // Print details for each site
      for (final site in sites) {
        final siteComponents = componentsBySite[site.id];
        if (siteComponents != null && siteComponents.isNotEmpty) {
          print('Site: ${site.siteName}');
          print('Location: ${site.siteLocation}');
          print('Non-Working Components: ${siteComponents.length}');

          // Group by floor
          final componentsByFloor = <String, List<Map<String, dynamic>>>{};
          for (final component in siteComponents) {
            final floorName = component['floor_name'] ?? 'Site Level';
            if (!componentsByFloor.containsKey(floorName)) {
              componentsByFloor[floorName] = [];
            }
            componentsByFloor[floorName]!.add(component);
          }

          // Print details for each floor
          for (final floorName in componentsByFloor.keys) {
            final floorComponents = componentsByFloor[floorName]!;
            print('\n  Floor: $floorName');
            print('  Non-Working Components: ${floorComponents.length}');

            // Group by component type
            final componentsByType = <String, List<Map<String, dynamic>>>{};
            for (final component in floorComponents) {
              final type = component['component_type'];
              if (!componentsByType.containsKey(type)) {
                componentsByType[type] = [];
              }
              componentsByType[type]!.add(component);
            }

            // Print details for each component type
            for (final type in componentsByType.keys) {
              final components = componentsByType[type]!;
              print('\n    $type (${components.length}):');
              for (final component in components) {
                final details = component['component_details'];
                print('      - ID: ${details['id']}');
                print('        Location: ${details['location'] ?? 'N/A'}');
                print('        Status: ${details['status'] ?? 'N/A'}');
                print('        Notes: ${details['notes'] ?? 'N/A'}');
                if (type == 'custom_building_accessories') {
                  print('        Name: ${details['name'] ?? 'N/A'}');
                }
                if (type == 'pumps') {
                  print('        Name: ${details['name'] ?? 'N/A'}');
                }
              }
            }
          }
          print('\n');
        }
      }
      print('=====================================\n');

      // Generate and display AI summary with better formatting
      print('\n=== AI-Generated Summary ===');
      print('=' * 80); // Separator line
      final aiSummary = await _generateAISummary();

      // Split the summary into lines and print each line
      final summaryLines = aiSummary.split('\n');
      for (final line in summaryLines) {
        print(line);
      }

      print('=' * 80); // Separator line
      print('=====================================\n');

      // Also print the raw summary for debugging
      print('\n=== Raw AI Summary (for debugging) ===');
      print(aiSummary);
      print('=====================================\n');
    }

    // Generate AI summary
    String aiSummary = '';
    if (nonWorkingComponents.isNotEmpty) {
      aiSummary = await _generateAISummary();
    }

    // Add area information page with page limit
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        maxPages: 100, // Set a reasonable maximum number of pages
        header: (context) {
          return pw.Container(
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
                  'Area Inspection Report',
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
          );
        },
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
                  area.name,
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
        build: (context) {
          final List<pw.Widget> children = [
            // Area Information Section
            _buildAreaInformationSection(contractorName),
            pw.SizedBox(height: 20),
          ];

          // Add contractor information if applicable
          if (isContractor == true) {
            children.addAll([
              _buildContractorInformationSection(contractorName),
              pw.SizedBox(height: 20),
            ]);
          }

          // Add non-working components summary if available
          if (nonWorkingComponents.isNotEmpty) {
            children.addAll([
              pw.Header(
                level: 1,
                child: pw.Text(
                  'Non-Working Components Summary',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.deepOrange,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Total Non-Working Components: ${nonWorkingComponents.length}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
            ]);
          }

          // Add AI summary if available
          if (aiSummary.isNotEmpty) {
            children.addAll([
              pw.Header(
                level: 1,
                child: pw.Text(
                  'AI-Generated Maintenance Analysis',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.deepOrange,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              // Split AI summary into paragraphs and add them with proper spacing
              ...aiSummary
                  .split('\n\n')
                  .map(
                    (paragraph) => pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          paragraph,
                          style: const pw.TextStyle(
                            fontSize: 12,
                            lineSpacing: 1.5,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                      ],
                    ),
                  )
                  .toList(),
              pw.SizedBox(height: 30),
            ]);
          }

          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: children,
            ),
          ];
        },
      ),
    );

    // Add site reports with chunking
    for (final site in sites) {
      final siteReportContent = await _buildSiteReportContent(site);

      // Split site report content into smaller chunks if needed
      final chunks = _splitContentIntoChunks(siteReportContent);

      for (final chunk in chunks) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            maxPages: 100,
            header:
                (context) => pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.blue, width: 2),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'SITE INSPECTION REPORT',
                                style: pw.TextStyle(
                                  fontSize: 24,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                site.siteName,
                                style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue700,
                                ),
                              ),
                            ],
                          ),
                          pw.Text(
                            DateTime.now().toString(),
                            style: const pw.TextStyle(
                              fontSize: 12,
                              color: PdfColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            footer:
                (context) => pw.Container(
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
                        DateTime.now().toString(),
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
                ),
            build: (context) => chunk,
          ),
        );
      }
    }

    // Save the PDF
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/area_report.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<List<dynamic>> _getAllComponentsForSite(
    String siteId,
    String componentType,
  ) async {
    final floors = await supabaseService.getFloorsBySiteId(siteId);
    final allComponents = <dynamic>[];

    // Get building accessories as they are site-level components
    if (componentType == 'building_accessories') {
      final accessories = await supabaseService.getBuildingAccessories(siteId);
      allComponents.addAll(accessories);
    }

    // Get custom building accessories as they are site-level components
    if (componentType == 'custom_building_accessories') {
      final customAccessories = await supabaseService
          .getCustomBuildingAccessories(siteId);
      allComponents.addAll(customAccessories);
    }

    // Get floor-level components
    for (final floor in floors) {
      switch (componentType) {
        case 'smoke_detectors':
          allComponents.addAll(
            await supabaseService.getSmokeDetectorsByFloorId(floor.id),
          );
          break;
        case 'heat_detectors':
          allComponents.addAll(
            await supabaseService.getHeatDetectorsByFloorId(floor.id),
          );
          break;
        case 'flasher_hooter_alarms':
          allComponents.addAll(
            await supabaseService.getFlasherHooterAlarmsByFloorId(floor.id),
          );
          break;
        case 'control_modules':
          allComponents.addAll(
            await supabaseService.getControlModulesByFloorId(floor.id),
          );
          break;
        case 'flow_switches':
          allComponents.addAll(
            await supabaseService.getFlowSwitchesByFloorId(floor.id),
          );
          break;
        case 'monitor_modules':
          allComponents.addAll(
            await supabaseService.getMonitorModulesByFloorId(floor.id),
          );
          break;
        case 'telephone_jacks':
          allComponents.addAll(
            await supabaseService.getTelephoneJacksByFloorId(floor.id),
          );
          break;
        case 'speakers':
          allComponents.addAll(
            await supabaseService.getSpeakersByFloorId(floor.id),
          );
          break;
        case 'hydrant_valves':
          allComponents.addAll(
            await supabaseService.getHydrantValvesByFloorId(floor.id),
          );
          break;
        case 'hydrant_ugs':
          allComponents.addAll(
            await supabaseService.getHydrantUGsByFloorId(floor.id),
          );
          break;
        case 'hydrant_wheels':
          allComponents.addAll(
            await supabaseService.getHydrantWheelsByFloorId(floor.id),
          );
          break;
        case 'hydrant_caps':
          allComponents.addAll(
            await supabaseService.getHydrantCapsByFloorId(floor.id),
          );
          break;
        case 'hydrant_mouth_gaskets':
          allComponents.addAll(
            await supabaseService.getHydrantMouthGasketsByFloorId(floor.id),
          );
          break;
        case 'canvas_hoses':
          allComponents.addAll(
            await supabaseService.getCanvasHosesByFloorId(floor.id),
          );
          break;
        case 'branch_pipes':
          allComponents.addAll(
            await supabaseService.getBranchPipesByFloorId(floor.id),
          );
          break;
        case 'fireman_axes':
          allComponents.addAll(
            await supabaseService.getFiremanAxesByFloorId(floor.id),
          );
          break;
        case 'hose_reels':
          allComponents.addAll(
            await supabaseService.getHoseReelsByFloorId(floor.id),
          );
          break;
        case 'shut_off_nozzles':
          allComponents.addAll(
            await supabaseService.getShutOffNozzlesByFloorId(floor.id),
          );
          break;
        case 'key_glasses':
          allComponents.addAll(
            await supabaseService.getKeyGlassesByFloorId(floor.id),
          );
          break;
        case 'pressure_gauges':
          allComponents.addAll(
            await supabaseService.getPressureGaugesByFloorId(floor.id),
          );
          break;
        case 'abc_extinguishers':
          allComponents.addAll(
            await supabaseService.getABCExtinguishersByFloorId(floor.id),
          );
          break;
        case 'sprinkler_zcvs':
          allComponents.addAll(
            await supabaseService.getSprinklerZCVsByFloorId(floor.id),
          );
          break;
      }
    }

    return allComponents;
  }

  pw.Widget _buildSiteInformationSection(Site site) {
    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Header(
            level: 1,
            text: 'Site Information',
            textStyle: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue,
            ),
          ),
          pw.SizedBox(height: 5),
          _buildPdfInfoTable([
            ['Site Name', site.siteName],
            ['Location', site.siteLocation],
            ['Owner', site.siteOwner],
            ['Owner Contact', '${site.siteOwnerEmail}\n${site.siteOwnerPhone}'],
            ['Manager', site.siteManager],
            [
              'Manager Contact',
              '${site.siteManagerEmail}\n${site.siteManagerPhone}',
            ],
            ['Inspector', site.siteInspectorName],
            [
              'Inspector Contact',
              '${site.siteInspectorEmail}\n${site.siteInspectorPhone}',
            ],
          ]),
        ],
      ),
    );
  }

  pw.Widget _buildOperationalTestsSection(List<Map<String, dynamic>> tests) {
    if (tests.isEmpty) {
      return pw.Text('No operational tests available');
    }

    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Header(
            level: 1,
            text: 'Operational Tests',
            textStyle: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Table(
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
                      'Test Type',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Status',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Notes',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
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
                          child: pw.Text(test['test_type']?.toString() ?? ''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(test['status']?.toString() ?? ''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(test['notes']?.toString() ?? ''),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildEngineInspectionsSection(
    List<Map<String, dynamic>> inspections,
  ) {
    if (inspections.isEmpty) {
      return pw.Text('No engine inspections available');
    }

    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Header(
            level: 1,
            text: 'Engine Inspections',
            textStyle: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Table(
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
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Status',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                      'Comments',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
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
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(inspection['value']?.toString() ?? ''),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            inspection['comments']?.toString() ?? '',
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
    );
  }

  pw.Widget _buildSiteDescriptionSection(String? description) {
    return pw.Container(
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
          pw.Text(description ?? 'No description available'),
        ],
      ),
    );
  }

  pw.Widget _buildBuildingAccessoriesSection(
    List<Floor> floors,
    List<dynamic> smokeDetectors,
    List<dynamic> heatDetectors,
    List<dynamic> flasherHooterAlarms,
    List<dynamic> controlModules,
    List<dynamic> flowSwitches,
    List<dynamic> monitorModules,
    List<dynamic> telephoneJacks,
    List<dynamic> speakers,
  ) {
    if (floors.isEmpty) {
      return pw.Text('No building accessories available');
    }

    return pw.Container(
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
          ...floors.map((floor) {
            final buildingComponents = [
              ...smokeDetectors
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Smoke Detector',
                      'status': c.status,
                      'note': c.note,
                      'updated_at': 'N/A',
                    },
                  ),
              ...heatDetectors
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Heat Detector',
                      'status': c.status,
                      'note': c.note,
                      'updated_at': 'N/A',
                    },
                  ),
              ...flasherHooterAlarms
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Flasher Hooter Alarm',
                      'status': c.status,
                      'note': c.note,
                      'updated_at': 'N/A',
                    },
                  ),
              ...controlModules
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Control Module',
                      'status': c.status,
                      'note': c.note,
                      'updated_at': 'N/A',
                    },
                  ),
              ...flowSwitches
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Flow Switch',
                      'status': c.status,
                      'note': c.note,
                      'updated_at': 'N/A',
                    },
                  ),
              ...monitorModules
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Monitor Module',
                      'status': c.status,
                      'note': c.note,
                      'updated_at': 'N/A',
                    },
                  ),
              ...telephoneJacks
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Telephone Jack',
                      'status': c.status,
                      'note': c.note,
                      'updated_at': 'N/A',
                    },
                  ),
              ...speakers
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Speaker',
                      'status': c.status,
                      'note': c.note,
                      'updated_at': 'N/A',
                    },
                  ),
            ];

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Floor ${floor.id}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 5),

                  if (buildingComponents.isNotEmpty) ...[
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red50,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(5),
                        ),
                      ),
                      child: pw.Text(
                        'Fire Alarms & Building Accessories',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    _buildComponentTable(buildingComponents),
                  ] else
                    pw.Text('No building accessories available for this floor'),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  pw.Widget _buildFloorComponentsSection(
    List<Floor> floors,
    List<dynamic> hydrantValves,
    List<dynamic> hydrantUGs,
    List<dynamic> hydrantWheels,
    List<dynamic> hydrantCaps,
    List<dynamic> hydrantMouthGaskets,
    List<dynamic> canvasHoses,
    List<dynamic> branchPipes,
    List<dynamic> firemanAxes,
    List<dynamic> hoseReels,
    List<dynamic> shutOffNozzles,
    List<dynamic> keyGlasses,
    List<dynamic> pressureGauges,
    List<dynamic> abcExtinguishers,
    List<dynamic> sprinklerZCVs,
    List<dynamic> boosterPumps,
  ) {
    if (floors.isEmpty) {
      return pw.Text('No floor components available');
    }

    return pw.Container(
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
          ...floors.map((floor) {
            // Floor Components
            final floorComponents = [
              ...hydrantValves
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Hydrant Valve',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...hydrantUGs
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Hydrant UG',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...hydrantWheels
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Hydrant Wheel',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...hydrantCaps
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Hydrant Cap',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...hydrantMouthGaskets
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Hydrant Mouth Gasket',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...canvasHoses
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Canvas Hose',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...branchPipes
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Branch Pipe',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...firemanAxes
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Fireman Axe',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...hoseReels
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Hose Reel',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...shutOffNozzles
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Shut Off Nozzle',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...keyGlasses
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Key Glass',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...pressureGauges
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Pressure Gauge',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...abcExtinguishers
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'ABC Extinguisher',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
              ...sprinklerZCVs
                  .where((c) => c.floorId == floor.id)
                  .map(
                    (c) => {
                      'type': 'Sprinkler ZCV',
                      'status': c.status,
                      'note': c.note,
                      'updated_at':
                          c.updatedAt?.toString().split('.')[0] ?? 'N/A',
                    },
                  ),
            ];

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Floor ${floor.id}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue,
                    ),
                  ),
                  pw.SizedBox(height: 5),

                  if (floorComponents.isNotEmpty) ...[
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(5),
                        ),
                      ),
                      child: pw.Text(
                        'Pumps & Accessories',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    _buildComponentTable(floorComponents),
                  ] else
                    pw.Text('No components available for this floor'),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  pw.Widget _buildComponentTable(List<Map<String, dynamic>> components) {
    return pw.Table(
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
        ...components.map(
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
    );
  }

  pw.Widget _buildPdfInfoTable(List<List<String>> data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(4),
      },
      children:
          data.map((row) {
            return pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    row[0],
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
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

  pw.Widget _buildSiteInfo(Site site) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
            ),
            child: pw.Text(
              site.siteName,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue900,
              ),
            ),
          ),
          pw.SizedBox(height: 5),
          _buildPdfInfoTable([
            ['Location', site.siteLocation],
            ['Owner', site.siteOwner],
            ['Owner Contact', '${site.siteOwnerEmail}\n${site.siteOwnerPhone}'],
            ['Manager', site.siteManager],
            [
              'Manager Contact',
              '${site.siteManagerEmail}\n${site.siteManagerPhone}',
            ],
            ['Inspector', site.siteInspectorName],
            [
              'Inspector Contact',
              '${site.siteInspectorEmail}\n${site.siteInspectorPhone}',
            ],
          ]),
        ],
      ),
    );
  }

  // Helper method to split content into smaller chunks
  List<List<pw.Widget>> _splitContentIntoChunks(List<pw.Widget> content) {
    final chunks = <List<pw.Widget>>[];
    var currentChunk = <pw.Widget>[];
    var currentHeight = 0.0;
    const maxChunkHeight = 700.0; // Approximate height for one page

    for (final widget in content) {
      // Estimate widget height (this is a rough estimation)
      double estimatedHeight = 0.0;
      if (widget is pw.Container) {
        estimatedHeight = 100.0; // Base height for containers
      } else if (widget is pw.Table) {
        estimatedHeight =
            50.0 * (widget.children?.length ?? 1); // Estimate table height
      } else if (widget is pw.Text) {
        estimatedHeight = 20.0; // Base height for text
      } else {
        estimatedHeight = 30.0; // Default height for other widgets
      }

      if (currentHeight + estimatedHeight > maxChunkHeight) {
        chunks.add(currentChunk);
        currentChunk = [];
        currentHeight = 0.0;
      }

      currentChunk.add(widget);
      currentHeight += estimatedHeight;
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }

  // Build area information section
  pw.Widget _buildAreaInformationSection(String contractorName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          child: pw.Text(
            'Area Information',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        _buildPdfInfoTable([
          ['Area Name', area.name],
          ['Location', area.siteLocation],
          ['Description', area.description ?? 'No description'],
          ['Owner', area.siteOwner],
          ['Owner Contact', '${area.siteOwnerEmail}\n${area.siteOwnerPhone}'],
          ['Manager', area.siteManager],
          [
            'Manager Contact',
            '${area.siteManagerEmail}\n${area.siteManagerPhone}',
          ],
          ['Contractor', '$contractorName\n${area.contractorEmail}'],
        ]),
      ],
    );
  }

  // Build contractor information section
  pw.Widget _buildContractorInformationSection(String contractorName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          child: pw.Text(
            'Contractor Information',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
        ),
        pw.SizedBox(height: 10),
        _buildPdfInfoTable([
          ['Contractor Name', contractorName],
          ['Contractor Email', area.contractorEmail],
        ]),
      ],
    );
  }

  // Build site report content
  Future<List<pw.Widget>> _buildSiteReportContent(Site site) async {
    // Fetch required data for each site
    final floors = await supabaseService.getFloorsBySiteId(site.id);

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

    // Load the logo image
    final logoImage = await rootBundle.load('assets/images/ember_logo.png');
    final logoImageBytes = logoImage.buffer.asUint8List();

    // Create a site report generator
    final siteReportGenerator = SiteReportGenerator(
      site: site,
      floors: floors,
      siteDescription: siteDescription,
      supabaseService: supabaseService,
      assignedSection:
          isContractor
              ? null
              : assignedSection, // Pass null for contractors to include all sections
    );

    // Get the site report content
    final siteContent = await siteReportGenerator.generateReportContent();

    // Create a list to hold all widgets including header and footer
    final List<pw.Widget> completeSiteReport = [];

    // Add header
    completeSiteReport.add(
      pw.Container(
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
              'Site: ${site.siteName}',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue,
              ),
            ),
            pw.Image(pw.MemoryImage(logoImageBytes), width: 100, height: 50),
          ],
        ),
      ),
    );
    completeSiteReport.add(pw.SizedBox(height: 20));

    // Add site content
    completeSiteReport.addAll(siteContent);

    // Add footer
    completeSiteReport.add(
      pw.Container(
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
              'Building Management System',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    );
    completeSiteReport.add(
      pw.SizedBox(height: 40),
    ); // Add extra space between sites

    return completeSiteReport;
  }
}
