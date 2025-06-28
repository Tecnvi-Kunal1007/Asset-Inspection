import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/site_manager_service.dart';
import '../services/site_inspection_service.dart';
import '../services/area_assignment_service.dart';
import '../services/area_inspection_service.dart';
import '../models/site.dart';
import '../models/area.dart';
import 'home_screen.dart';
import 'site_assignment_history_screen.dart';
import 'login_page.dart';
import 'site_details_screen.dart';
import 'work_report_form_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create_site_screen.dart';
import 'package:pump_management_system/screens/assigned_tasks_screen.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../components/area_report_generator.dart';
import '../services/supabase_service.dart';
import '../services/report_email_service.dart';
import '../widgets/billboard_footer.dart';
import 'package:pump_management_system/widgets/floating_chat.dart';
import '../utils/responsive_helper.dart';

class SiteManagerDashboard extends StatefulWidget {
  const SiteManagerDashboard({super.key});

  @override
  State<StatefulWidget> createState() => _SiteManagerDashboard();
}

class _SiteManagerDashboard extends State<SiteManagerDashboard> {
  final authService = AuthService();
  final siteManagerService = SiteManagerService();
  final _siteInspectionService = SiteInspectionService();
  final _areaAssignmentService = AreaAssignmentService();
  final _areaInspectionService = AreaInspectionService();
  final _supabaseService = SupabaseService();
  final _reportEmailService = ReportEmailService();
  List<Site> _assignedSites = [];
  List<Map<String, dynamic>> _assignedAreas = [];
  Map<String, bool> _completedInspections = {};
  Map<String, List<Site>> _sitesByArea = {};
  Map<String, bool> _expandedAreas = {};
  String? _freelancerId;
  bool _isLoading = true;
  List<String> _assignedSections = [];
  bool _isGeneratingReport = false;
  Map<String, List<Map<String, dynamic>>> _areaReports = {};
  Map<String, bool> _isLoadingReports = {};
  Map<String, bool> _canMarkComplete = {};
  bool _isContractor = false;

  @override
  void initState() {
    super.initState();
    _loadAssignedData();
  }

  Future<void> _loadAssignedData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not authenticated');
      }

      // Get freelancer ID using email
      final freelancerId = await siteManagerService.getFreelancerId(
        user.email!,
      );
      if (freelancerId == null) {
        throw Exception('Site manager not found');
      }

      _freelancerId = freelancerId;

      // Get assigned sites
      final sites = await siteManagerService.getAssignedSites(freelancerId);

      // Get assigned areas
      final areas = await _areaAssignmentService.getAssignmentsByUser(
        freelancerId,
        'freelancer',
      );

      // Get assigned sections from area assignments
      final assignedSections = <String>[];
      for (final area in areas) {
        final assignmentType = area['assignment_type'] as String;
        if (assignmentType == 'pumps_floor') {
          assignedSections.add('floor');
        } else if (assignmentType == 'building_fire') {
          assignedSections.add('building_fire');
        }
      }
      assignedSections.toSet().toList(); // Remove duplicates

      // Get inspection status for each site
      final assignments = await Supabase.instance.client
          .from('site_assignments')
          .select('site_id, inspection_status')
          .eq('freelancer_id', freelancerId);

      final completedInspections = Map.fromEntries(
        (assignments as List).map(
          (assignment) => MapEntry(
            assignment['site_id'] as String,
            assignment['inspection_status'] == 'completed',
          ),
        ),
      );

      // Get all sites for each assigned area
      final sitesByArea = <String, List<Site>>{};
      for (final area in areas) {
        final areaId = area['areas']['id'] as String;

        // Fetch all sites in this area
        final areaSites = await Supabase.instance.client
            .from('sites')
            .select()
            .eq('area_id', areaId);

        if (areaSites != null) {
          sitesByArea[areaId] =
              (areaSites as List).map((siteData) {
                return Site(
                  id: siteData['id'] as String,
                  siteName: siteData['site_name'] as String,
                  siteLocation: siteData['site_location'] as String,
                  siteOwner: siteData['site_owner'] as String,
                  siteManager: siteData['site_manager'] as String,
                  areaId: areaId,
                  siteOwnerEmail: siteData['site_owner_email'] as String,
                  siteOwnerPhone: siteData['site_owner_phone'] as String,
                  siteManagerEmail: siteData['site_manager_email'] as String,
                  siteManagerPhone: siteData['site_manager_phone'] as String,
                  siteInspectorName: siteData['site_inspector_name'] as String,
                  siteInspectorEmail:
                      siteData['site_inspector_email'] as String,
                  siteInspectorPhone:
                      siteData['site_inspector_phone'] as String,
                  siteInspectorPhoto:
                      siteData['site_inspector_photo'] as String,
                  contractorId: siteData['contractor_id'] as String,
                  contractorEmail: siteData['contractor_email'] as String,
                  createdAt: DateTime.parse(siteData['created_at'] as String), description: '',
                );
              }).toList();
        }

        // Load reports for this area
        await _loadReports(areaId);
      }

      // Initialize expanded state for areas
      final expandedAreas = Map.fromEntries(
        areas.map((area) => MapEntry(area['areas']['id'] as String, false)),
      );

      setState(() {
        _assignedSites = sites;
        _assignedAreas = areas;
        _completedInspections = completedInspections;
        _sitesByArea = sitesByArea;
        _expandedAreas = expandedAreas;
        _assignedSections = assignedSections;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markInspectionComplete(String siteId) async {
    if (_freelancerId == null) return;

    try {
      final success = await _siteInspectionService.markInspectionComplete(
        siteId,
        _freelancerId!,
      );

      if (success && mounted) {
        setState(() {
          _completedInspections[siteId] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection marked as completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking inspection complete: $e')),
        );
      }
    }
  }

  void _toggleAreaExpansion(String areaId) {
    setState(() {
      _expandedAreas[areaId] = !(_expandedAreas[areaId] ?? false);
    });
  }

  bool _isSiteAssignedToFreelancer(String siteId) {
    return _assignedSites.any((site) => site.id == siteId);
  }

  Future<void> _markAreaInspectionComplete(
    String areaId,
    String assignmentType,
  ) async {
    if (_freelancerId == null) return;

    try {
      final success = await _areaInspectionService.markInspectionComplete(
        areaId,
        _freelancerId!,
        assignmentType,
      );

      if (success && mounted) {
        // Refresh the data
        await _loadAssignedData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Area inspection marked as completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error marking area inspection complete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAssignedAreasGrid(BuildContext context) {
    // Determine number of columns based on screen size
    int columnCount = ResponsiveHelper.getColumnCount(context);
    
    if (ResponsiveHelper.isMobile(context)) {
      // For mobile, use a vertical list
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _assignedAreas.length,
        itemBuilder: (context, index) {
          return _buildAreaListItem(index);
        },
      );
    } else {
      // For tablet and desktop, use a grid
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: ResponsiveHelper.isTablet(context) ? 0.9 : 1.1,
        ),
        itemCount: _assignedAreas.length,
        itemBuilder: (context, index) {
          return _buildAreaListItem(index);
        },
      );
    }
  }

  Widget _buildAreaListItem(int index) {
    final area = _assignedAreas[index]['areas'];
    final areaId = area['id'] as String;
    final assignmentType = _assignedAreas[index]['assignment_type'];
    final sitesInArea = _sitesByArea[areaId] ?? [];
    final isExpanded = _expandedAreas[areaId] ?? false;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Area Header
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              area['name'] ?? 'Unnamed Area',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 18),
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Location: ${area['site_location'] ?? 'Not specified'}',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 14),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assignment Type: ${assignmentType == 'pumps_floor' ? 'Floor Management' : 'Building & Fire'}',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 14),
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total Sites: ${sitesInArea.length}',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 14),
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.blue.shade700,
              ),
              onPressed: () => _toggleAreaExpansion(areaId),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Area Inspection',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.getFontSize(context, 16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAreaDetailCard(_assignedAreas[index], assignmentType),
                  const SizedBox(height: 16),
                  Text(
                    'Sites in this Area',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.getFontSize(context, 16),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateSiteScreen(
                              areaId: areaId,
                              area: Area(
                                id: areaId,
                                name: area['name'] ?? '',
                                description: area['description'] ?? '',
                                contractorId: area['contractor_id'] ?? '',
                                siteOwner: area['site_owner'] ?? '',
                                siteOwnerEmail: area['site_owner_email'] ?? '',
                                siteOwnerPhone: area['site_owner_phone'] ?? '',
                                siteManager: area['site_manager'] ?? '',
                                siteManagerEmail: area['site_manager_email'] ?? '',
                                siteManagerPhone: area['site_manager_phone'] ?? '',
                                siteLocation: area['site_location'] ?? '',
                                contractorEmail: area['contractor_email'] ?? '',
                                createdAt: DateTime.parse(
                                  area['created_at'] ?? DateTime.now().toIso8601String(),
                                ),
                                updatedAt: DateTime.parse(
                                  area['updated_at'] ?? DateTime.now().toIso8601String(),
                                ),
                              ),
                            ),
                          ),
                        ).then((result) {
                          if (result == true) {
                            _loadAssignedData();
                          }
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(
                        'Create New Site',
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 16),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Sites list with responsive layout
                  _buildSitesList(sitesInArea),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAreaDetailCard(Map<String, dynamic> area, String assignmentType) {
    final areaData = area['areas'] as Map<String, dynamic>;
    final inspectionStatus = area['inspection_status'] as String? ?? 'pending';
    final isCompleted = inspectionStatus == 'completed';
    final areaId = areaData['id'] as String;
    final sitesInArea = _sitesByArea[areaId] ?? [];
    final reports = _areaReports[areaId] ?? [];
    final isLoadingReports = _isLoadingReports[areaId] ?? false;
    final canMarkComplete = _canMarkComplete[areaId] ?? false;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    areaData['name'] ?? 'Unnamed Area',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.getFontSize(context, 18),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isCompleted
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCompleted ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Text(
                    inspectionStatus.toUpperCase(),
                    style: TextStyle(
                      color: isCompleted ? Colors.green : Colors.orange,
                      fontSize: ResponsiveHelper.getFontSize(context, 12),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              areaData['description'] ?? 'No description',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Text(
              'Assignment Type: ${assignmentType == 'pumps_floor' ? 'Floor Management' : 'Building & Fire'}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (isCompleted && area['inspection_completed_at'] != null)
              Text(
                'Completed on: ${DateTime.parse(area['inspection_completed_at']).toString().split('.')[0]}',
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: ResponsiveHelper.getFontSize(context, 14),
                ),
              ),
            const SizedBox(height: 16),
            // Report Generation Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Area Reports',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.getFontSize(context, 16),
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Section: ${_assignedSections.first == 'floor' ? 'Floor Management' : 'Building Accessories & Fire Alarm Management'}',
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveHelper.getFontSize(context, 14),
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              _isGeneratingReport
                                  ? null
                                  : () => _generateAreaReport(
                                    Area(
                                      id: areaId,
                                      name: areaData['name'] ?? '',
                                      description:
                                          areaData['description'] ?? '',
                                      contractorId:
                                          areaData['contractor_id'] ?? '',
                                      siteOwner: areaData['site_owner'] ?? '',
                                      siteOwnerEmail:
                                          areaData['site_owner_email'] ?? '',
                                      siteOwnerPhone:
                                          areaData['site_owner_phone'] ?? '',
                                      siteManager:
                                          areaData['site_manager'] ?? '',
                                      siteManagerEmail:
                                          areaData['site_manager_email'] ?? '',
                                      siteManagerPhone:
                                          areaData['site_manager_phone'] ?? '',
                                      siteLocation:
                                          areaData['site_location'] ?? '',
                                      contractorEmail:
                                          areaData['contractor_email'] ?? '',
                                      createdAt: DateTime.parse(
                                        areaData['created_at'] ??
                                            DateTime.now().toIso8601String(),
                                      ),
                                      updatedAt: DateTime.parse(
                                        areaData['updated_at'] ??
                                            DateTime.now().toIso8601String(),
                                      ),
                                    ),
                                    sitesInArea,
                                  ),
                          icon:
                              _isGeneratingReport
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.description),
                          label: Text(
                            _isGeneratingReport
                                ? 'Generating...'
                                : 'Generate Report',
                            style: GoogleFonts.poppins(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isLoadingReports)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (reports.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Recent Reports',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveHelper.getFontSize(context, 14),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...reports.take(3).map((report) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          report['file_name'] ?? 'Unnamed Report',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 14),
                          ),
                        ),
                        subtitle: Text(
                          'Generated: ${DateTime.parse(report['generated_at']).toString().split('.')[0]}',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 12),
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.download,
                                color: Colors.blue,
                              ),
                              onPressed: () => _downloadReport(report['report_url']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.green),
                              onPressed: () => _sendReport(
                                report['report_url'],
                                report['file_name'],
                                areaData,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Mark Inspection Complete Button at the bottom
            if (!isCompleted)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canMarkComplete
                      ? () => _markAreaInspectionComplete(
                        areaData['id'],
                        assignmentType,
                      )
                      : null,
                  icon: const Icon(Icons.check_circle),
                  label: Text(
                    canMarkComplete
                        ? 'Mark Inspection Complete'
                        : 'Generate Report First to Mark Complete',
                    style: GoogleFonts.poppins(),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canMarkComplete ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSitesList(List<Site> sites) {
    if (ResponsiveHelper.isMobile(context)) {
      // For mobile, use a vertical list
      return Column(
        children: sites.map((site) => _buildSiteCard(site)).toList(),
      );
    } else {
      // For tablet and desktop, use a grid
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveHelper.isTablet(context) ? 2 : 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: sites.length,
        itemBuilder: (context, index) {
          return _buildSiteCard(sites[index]);
        },
      );
    }
  }

  Widget _buildSiteCard(Site site) {
    final isAssigned = _isSiteAssignedToFreelancer(site.id);
    final isCompleted = isAssigned && (_completedInspections[site.id] ?? false);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    site.siteName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isAssigned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      'Assigned to You',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Location: ${site.siteLocation}',
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
                if (isAssigned) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${isCompleted ? 'Completed' : 'Pending'}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isCompleted ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 16),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => SiteDetailsScreen(
                          site: site,
                          assignedSections: _assignedSections,
                        ),
                  ),
                );
              },
            ),
          ),
          if (isAssigned && !isCompleted)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markInspectionComplete(site.id),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text(
                    'Mark Inspection Complete',
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    String subtitle,
    Color color,
    VoidCallback onPressed,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(color: Colors.grey[600]),
        ),
        leading: Icon(icon, color: color),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Future<void> _loadReports(String areaId) async {
    setState(() {
      _isLoadingReports[areaId] = true;
    });

    try {
      final reports = await _supabaseService.getAreaReports(areaId);
      setState(() {
        _areaReports[areaId] = reports;
        _isLoadingReports[areaId] = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingReports[areaId] = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading reports: ${error.toString()}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<File> _generateReportFile(Area area, List<Site> sites) async {
    final reportGenerator = AreaReportGenerator(
      area: area,
      sites: sites,
      supabaseService: _supabaseService,
      assignedSection: _assignedSections.first,
      isContractor: _isContractor,
    );
    return await reportGenerator.generateReport();
  }

  Future<void> _generateAreaReport(Area area, List<Site> sites) async {
    try {
      setState(() {
        _isGeneratingReport = true;
        _canMarkComplete[area.id] = false;
      });

      // Get the current user's role
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not authenticated or email not available');
      }

      // Check if the user is a contractor
      final contractorResponse =
          await Supabase.instance.client
              .from('contractor')
              .select('id')
              .eq('email', user.email!)
              .maybeSingle();

      setState(() {
        _isContractor = contractorResponse != null;
      });

      // Get all sites for this area
      final allSites = await Supabase.instance.client
          .from('sites')
          .select()
          .eq('area_id', area.id);

      if (allSites == null) {
        throw Exception('No sites found for this area');
      }

      // Convert to Site objects
      final List<Site> areaSites =
          (allSites as List).map((siteData) {
            return Site(
              id: siteData['id'] as String,
              siteName: siteData['site_name'] as String,
              siteLocation: siteData['site_location'] as String,
              siteOwner: siteData['site_owner'] as String,
              siteManager: siteData['site_manager'] as String,
              areaId: area.id,
              siteOwnerEmail: siteData['site_owner_email'] as String,
              siteOwnerPhone: siteData['site_owner_phone'] as String,
              siteManagerEmail: siteData['site_manager_email'] as String,
              siteManagerPhone: siteData['site_manager_phone'] as String,
              siteInspectorName: siteData['site_inspector_name'] as String,
              siteInspectorEmail: siteData['site_inspector_email'] as String,
              siteInspectorPhone: siteData['site_inspector_phone'] as String,
              siteInspectorPhoto: siteData['site_inspector_photo'] as String,
              contractorId: siteData['contractor_id'] as String,
              contractorEmail: siteData['contractor_email'] as String,
              createdAt: DateTime.parse(siteData['created_at'] as String), description: '',
            );
          }).toList();

      // Filter sites based on user role
      final filteredSites =
          _isContractor
              ? areaSites // Include all sites for contractors
              : areaSites.where((site) {
                // For freelancers, filter based on assigned section
                final siteAssignment = _assignedAreas.firstWhere(
                  (assignment) => assignment['areas']['id'] == area.id,
                  orElse: () => {'assignment_type': ''},
                );
                final assignmentType =
                    siteAssignment['assignment_type'] as String;
                return _assignedSections.contains(assignmentType);
              }).toList();

      // Generate report with filtered sites
      final reportFile = await _generateReportFile(area, filteredSites);

      // Create a meaningful report name with timestamp
      final timestamp = DateTime.now();
      final reportName =
          '${area.name}_${_isContractor ? 'Complete' : (_assignedSections.first == 'floor' ? 'Floor' : 'Building_Fire')}_Report_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';

      // Upload to Supabase
      final reportUrl = await _supabaseService.uploadAreaReport(
        area.id,
        reportFile,
        reportName: reportName,
      );

      // Refresh the reports list
      await _loadReports(area.id);

      setState(() {
        _canMarkComplete[area.id] = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report generated successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: ${error.toString()}')),
      );
    } finally {
      setState(() {
        _isGeneratingReport = false;
      });
    }
  }

  Future<File?> _downloadAndSaveReport(String url) async {
    try {
      // Request storage permission
      if (await Permission.storage.request().isGranted) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final directory = await getApplicationDocumentsDirectory();
          final fileName = url.split('/').last;
          final file = File('${directory.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);

          // Open the file after downloading
          await OpenFile.open(file.path);
          return file;
        }
      }
      return null;
    } catch (e) {
      print('Error downloading report: $e');
      return null;
    }
  }

  Future<void> _downloadReport(String reportUrl) async {
    try {
      final reportFile = await _downloadAndSaveReport(reportUrl);

      if (reportFile != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report downloaded successfully')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download report')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading report: ${error.toString()}'),
        ),
      );
    }
  }

  Future<void> _sendReport(
    String reportUrl,
    String reportName,
    Map<String, dynamic> areaData,
  ) async {
    try {
      setState(() {
        _isGeneratingReport = true;
      });

      print('Starting report sending process...');
      print('Report URL: $reportUrl');
      print('Report Name: $reportName');
      print('Area Data: $areaData');

      // Download the report file
      final response = await http.get(Uri.parse(reportUrl));
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download report file: ${response.statusCode}',
        );
      }
      print('Report file downloaded successfully');

      // Create temporary file
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$reportName');
      await file.writeAsBytes(response.bodyBytes);
      print('Report file saved temporarily');

      // Get freelancer details
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not authenticated');
      }
      print('Current user email: ${user.email}');

      // Get freelancer data
      final freelancerResponse =
          await Supabase.instance.client
              .from('freelancers')
              .select('name, email, phone')
              .eq('email', user.email!)
              .maybeSingle();

      if (freelancerResponse == null) {
        throw Exception('Freelancer details not found');
      }

      final freelancerData = freelancerResponse as Map<String, dynamic>;
      print('Freelancer data retrieved: ${freelancerData['name']}');

      // Get complete area data
      final areaResponse =
          await Supabase.instance.client
              .from('areas')
              .select('*, site_manager_email, contractor_email')
              .eq('id', areaData['id'])
              .maybeSingle();

      if (areaResponse == null) {
        throw Exception('Area data not found');
      }

      print('Complete area data: $areaResponse');

      // Prepare email body with area and freelancer information
      final emailBody = '''
Area Information:
----------------
Area Name: ${areaData['name'] ?? 'N/A'}
Location: ${areaData['site_location'] ?? 'N/A'}
Description: ${areaData['description'] ?? 'N/A'}

Freelancer/Employee Details:
---------------------------
Name: ${freelancerData['name'] ?? 'N/A'}
Email: ${freelancerData['email'] ?? 'N/A'}
Phone: ${freelancerData['phone'] ?? 'N/A'}

Please find attached the inspection report for the above area.
''';

      print('Preparing to send emails...');

      // Send to site manager
      final siteManagerEmail = areaResponse['site_manager_email'];
      if (siteManagerEmail != null && siteManagerEmail.isNotEmpty) {
        print('Sending email to site manager: $siteManagerEmail');
        await _reportEmailService.sendReportEmail(
          recipientEmail: siteManagerEmail,
          areaName: areaData['name'],
          reportFile: file,
          reportName: reportName,
          emailBody: emailBody,
        );
        print('Email sent to site manager successfully');
      } else {
        print('No site manager email found in area data');
      }

      // Send to contractor using email from area data
      final contractorEmail = areaResponse['contractor_email'];
      if (contractorEmail != null && contractorEmail.isNotEmpty) {
        print('Sending email to contractor: $contractorEmail');
        await _reportEmailService.sendReportEmail(
          recipientEmail: contractorEmail,
          areaName: areaData['name'],
          reportFile: file,
          reportName: reportName,
          emailBody: emailBody,
        );
        print('Email sent to contractor successfully');
      } else {
        print('No contractor email found in area data');
      }

      // Clean up temporary file
      await file.delete();
      print('Temporary file cleaned up');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report sent successfully to site manager and contractor',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      print('Error in _sendReport: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending report: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingReport = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text(
            'Freelancer-Employee Dashboard',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: ResponsiveHelper.getFontSize(context, 16),
            ),
          ),
          backgroundColor: Colors.blue,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAssignedData,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await authService.logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: ResponsiveHelper.getPadding(context),
                      child: Column(
                        children: [
                          // Work Report and Tasks Sections in a responsive grid
                          ResponsiveHelper.responsiveWidget(
                            context: context,
                            mobile: Column(
                              children: [
                                _buildWorkReportCard(),
                                const SizedBox(height: 16),
                                _buildTasksCard(),
                              ],
                            ),
                            tablet: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildWorkReportCard()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTasksCard()),
                              ],
                            ),
                            desktop: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildWorkReportCard()),
                                const SizedBox(width: 16),
                                Expanded(child: _buildTasksCard()),
                              ],
                            ),
                          ),

                          // Assigned Areas Section
                          if (_assignedAreas.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 24.0,
                              ),
                              child: Text(
                                'Assigned Areas',
                                style: GoogleFonts.poppins(
                                  fontSize: ResponsiveHelper.getFontSize(context, 20),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildAssignedAreasGrid(context),
                          ],

                          // No Assignments Message
                          if (_assignedAreas.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.assignment_outlined,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Assignments',
                                      style: GoogleFonts.poppins(
                                        fontSize: ResponsiveHelper.getFontSize(context, 20),
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'You have not been assigned any areas yet',
                                      style: GoogleFonts.poppins(
                                        fontSize: ResponsiveHelper.getFontSize(context, 14),
                                        color: Colors.grey.shade500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          const BillboardFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
            // Floating chatbot positioned at bottom right
            Positioned(
              bottom: 20,
              right: 20,
              child: const FloatingChat(userRole: 'site_manager'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkReportCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work Reports',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 20),
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Submit your daily work reports and maintenance activities',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 14),
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkReportFormScreen(
                        freelancerId: _freelancerId!,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  'Create Work Report',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 16),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Tasks',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 20),
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'View and manage tasks assigned to you',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveHelper.getFontSize(context, 14),
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AssignedTasksScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.task_alt),
                label: Text(
                  'View Tasks',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveHelper.getFontSize(context, 16),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
