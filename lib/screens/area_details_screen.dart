import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../models/area.dart';
import '../models/site.dart';
import '../services/supabase_service.dart';
import '../services/report_email_service.dart';
import '../components/area_report_generator.dart';
import 'create_site_screen.dart';
import 'site_details_screen.dart';
import 'pdf_editor_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AreaDetailsScreen extends StatefulWidget {
  final Area area;

  const AreaDetailsScreen({super.key, required this.area});

  @override
  State<AreaDetailsScreen> createState() => _AreaDetailsScreenState();
}

class _AreaDetailsScreenState extends State<AreaDetailsScreen> {
  final _supabaseService = SupabaseService();
  final _reportEmailService = ReportEmailService();
  List<Site> _sites = [];
  bool _isLoading = true;
  bool _isGeneratingReport = false;
  bool _isSendingReport = false;
  String? _reportUrl;
  final _searchController = TextEditingController();
  List<Site> _filteredSites = [];
  bool _isEditing = false;
  List<Map<String, dynamic>> _reports = [];
  bool _isLoadingReports = false;

  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _siteOwnerController = TextEditingController();
  final _siteOwnerEmailController = TextEditingController();
  final _siteOwnerPhoneController = TextEditingController();
  final _siteManagerController = TextEditingController();
  final _siteManagerEmailController = TextEditingController();
  final _siteManagerPhoneController = TextEditingController();
  final _siteLocationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSites();
    _initializeControllers();
    _loadReports();
  }

  void _initializeControllers() {
    _nameController.text = widget.area.name;
    _descriptionController.text = widget.area.description;
    _siteOwnerController.text = widget.area.siteOwner;
    _siteOwnerEmailController.text = widget.area.siteOwnerEmail;
    _siteOwnerPhoneController.text = widget.area.siteOwnerPhone;
    _siteManagerController.text = widget.area.siteManager;
    _siteManagerEmailController.text = widget.area.siteManagerEmail;
    _siteManagerPhoneController.text = widget.area.siteManagerPhone;
    _siteLocationController.text = widget.area.siteLocation;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _siteOwnerController.dispose();
    _siteOwnerEmailController.dispose();
    _siteOwnerPhoneController.dispose();
    _siteManagerController.dispose();
    _siteManagerEmailController.dispose();
    _siteManagerPhoneController.dispose();
    _siteLocationController.dispose();
    super.dispose();
  }

  void _filterSites(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSites = List.from(_sites);
      } else {
        _filteredSites =
            _sites
                .where(
                  (site) =>
                      site.siteName.toLowerCase().contains(
                        query.toLowerCase(),
                      ) ||
                      site.siteLocation.toLowerCase().contains(
                        query.toLowerCase(),
                      ),
                )
                .toList();
      }
    });
  }

  Future<void> _loadSites() async {
    try {
      final sites = await _supabaseService.getSitesByArea(widget.area.id);
      setState(() {
        _sites = sites;
        _filteredSites = List.from(sites);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _updateArea() async {
    try {
      final updatedArea = Area(
        id: widget.area.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        contractorId: widget.area.contractorId,
        siteOwner: _siteOwnerController.text.trim(),
        siteOwnerEmail: _siteOwnerEmailController.text.trim(),
        siteOwnerPhone: _siteOwnerPhoneController.text.trim(),
        siteManager: _siteManagerController.text.trim(),
        siteManagerEmail: _siteManagerEmailController.text.trim(),
        siteManagerPhone: _siteManagerPhoneController.text.trim(),
        siteLocation: _siteLocationController.text.trim(),
        contractorEmail: widget.area.contractorEmail,
        createdAt: widget.area.createdAt,
        updatedAt: DateTime.now(),
      );

      await _supabaseService.updateArea(updatedArea);
      setState(() {
        _isEditing = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Site updated successfully'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<File> _generateReportFile() async {
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

    final isContractor = contractorResponse != null;

    final reportGenerator = AreaReportGenerator(
      area: widget.area,
      sites: _sites,
      supabaseService: _supabaseService,
      isContractor: isContractor,
    );
    return await reportGenerator.generateReport();
  }

  Future<void> _generateAreaReport() async {
    try {
      setState(() {
        _isGeneratingReport = true;
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

      final isContractor = contractorResponse != null;

      // Generate report
      final reportFile = await _generateReportFile();

      // Create a meaningful report name with timestamp
      final timestamp = DateTime.now();
      final reportName =
          '${widget.area.name}_${isContractor ? 'Complete' : 'Section'}_Report_${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}';

      // Upload to Supabase
      final reportUrl = await _supabaseService.uploadAreaReport(
        widget.area.id,
        reportFile,
        reportName: reportName,
      );

      // Refresh the reports list
      await _loadReports();

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

  Future<void> _downloadReport() async {
    if (_reportUrl == null) return;

    try {
      final reportFile = await _downloadAndSaveReport(_reportUrl!);

      if (reportFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report downloaded successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download report')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading report: ${error.toString()}'),
        ),
      );
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

  Future<void> _viewReport(String reportUrl) async {
    try {
      final reportFile = await _downloadAndSaveReport(reportUrl);
      if (reportFile == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download report'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error viewing report: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoadingReports = true;
    });

    try {
      final reports = await _supabaseService.getAreaReports(widget.area.id);
      setState(() {
        _reports = reports;
        _isLoadingReports = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingReports = false;
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

  Future<void> _sendReport(String reportUrl, String reportName) async {
    try {
      setState(() {
        _isSendingReport = true;
      });

      // Validate site manager email
      if (widget.area.siteManagerEmail.isEmpty) {
        throw Exception(
          'Site manager email is not set. Please update the area details first.',
        );
      }

      // Download the report file
      final reportFile = await _downloadAndSaveReport(reportUrl);
      if (reportFile == null) {
        throw Exception('Failed to download report file');
      }

      // Send the report via email
      try {
        await _reportEmailService.sendReportEmail(
          recipientEmail: widget.area.siteManagerEmail,
          areaName: widget.area.name,
          reportFile: reportFile,
          reportName: reportName,
        );

        // If we get here, the email was sent successfully
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report sent successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (emailError) {
        print('Email sending failed: $emailError');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send email: ${emailError.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSendingReport = false;
      });
    }
  }

  void _showReportSelectionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(
              'Select Report to Send',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Container(
              width: double.maxFinite,
              height: 400, // Fixed height for scrolling
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListView.builder(
                itemCount: _reports.length,
                itemBuilder: (context, index) {
                  final report = _reports[index];
                  final generatedAt = DateTime.parse(report['generated_at']);
                  final formattedDate =
                      '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} ${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.description,
                        color: Colors.blue,
                      ),
                      title: Text(
                        report['name'] ?? 'Report $formattedDate',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Generated on $formattedDate',
                        style: GoogleFonts.poppins(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _sendReport(
                          report['report_url'],
                          report['name'] ?? 'Report $formattedDate',
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600),
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
          ),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
        ),
        keyboardType: keyboardType,
        enabled: enabled && _isEditing,
        style: GoogleFonts.poppins(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.area.name, style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _updateArea();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Area Information Card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Site Information',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Site Name',
                      icon: Icons.business,
                    ),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      icon: Icons.description,
                    ),
                    _buildTextField(
                      controller: _siteLocationController,
                      label: 'Location',
                      icon: Icons.location_on,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Owner Information',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _siteOwnerController,
                      label: 'Owner Name',
                      icon: Icons.person,
                    ),
                    _buildTextField(
                      controller: _siteOwnerEmailController,
                      label: 'Owner Email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _buildTextField(
                      controller: _siteOwnerPhoneController,
                      label: 'Owner Phone',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Manager Information',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _siteManagerController,
                      label: 'Manager Name',
                      icon: Icons.manage_accounts,
                    ),
                    _buildTextField(
                      controller: _siteManagerEmailController,
                      label: 'Manager Email',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _buildTextField(
                      controller: _siteManagerPhoneController,
                      label: 'Manager Phone',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),

            // Sites Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sites',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => CreateSiteScreen(
                                areaId: widget.area.id,
                                area: widget.area,
                              ),
                        ),
                      );
                      if (result == true) {
                        _loadSites();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text('Add Site', style: GoogleFonts.poppins()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search sites...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: _filterSites,
              ),
            ),

            // Sites List
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSites.isEmpty
                ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No sites found',
                      style: GoogleFonts.poppins(fontSize: 18),
                    ),
                  ),
                )
                : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredSites.length,
                  itemBuilder: (context, index) {
                    final site = _filteredSites[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          site.siteName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          site.siteLocation,
                          style: GoogleFonts.poppins(),
                        ),
                        trailing: PopupMenuButton<String>(
                          itemBuilder:
                              (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                          onSelected: (value) async {
                            if (value == 'edit') {
                              // TODO: Implement edit functionality
                            } else if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Delete Site'),
                                      content: const Text(
                                        'Are you sure you want to delete this site?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirm == true) {
                                try {
                                  await _supabaseService.deleteSite(site.id);
                                  _loadSites();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error deleting site: $e'),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => SiteDetailsScreen(
                                    site: site,
                                    assignedSections: [],
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
            const SizedBox(height: 16),

            // Report Generation Buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.description),
                    label: Text(
                      'Generate Report',
                      style: GoogleFonts.poppins(),
                    ),
                    onPressed: _isGeneratingReport ? null : _generateAreaReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: Text(
                      'Download Report',
                      style: GoogleFonts.poppins(),
                    ),
                    onPressed: _reportUrl != null ? _downloadReport : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Generated Reports',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isLoadingReports)
                          const Center(child: CircularProgressIndicator())
                        else if (_reports.isEmpty)
                          Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No reports generated yet',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            height: 300, // Fixed height for scrolling
                            child: ListView.builder(
                              itemCount: _reports.length,
                              itemBuilder: (context, index) {
                                final report = _reports[index];
                                final generatedAt = DateTime.parse(
                                  report['generated_at'],
                                );
                                final formattedDate =
                                    '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} ${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: InkWell(
                                    onTap:
                                        () => _viewReport(report['report_url']),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.description,
                                        color: Colors.blue,
                                      ),
                                      title: Text(
                                        report['file_name'] ??
                                            'Report $formattedDate',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'Generated on $formattedDate',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.blue,
                                            ),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (
                                                        context,
                                                      ) => PdfEditorScreen(
                                                        pdfUrl:
                                                            report['report_url'],
                                                        areaName:
                                                            widget.area.name,
                                                        areaId: widget.area.id,
                                                      ),
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.download,
                                              color: Colors.green,
                                            ),
                                            onPressed: () async {
                                              try {
                                                final reportFile =
                                                    await _downloadAndSaveReport(
                                                      report['report_url'],
                                                    );
                                                if (reportFile != null) {
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Report downloaded and opened successfully',
                                                      ),
                                                    ),
                                                  );
                                                } else {
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Failed to download report',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              } catch (error) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Error downloading report: ${error.toString()}',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isGeneratingReport ? null : _generateAreaReport,
                  icon:
                      _isGeneratingReport
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.description),
                  label: Text(
                    _isGeneratingReport ? 'Generating...' : 'Generate Report',
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      _isSendingReport ? null : _showReportSelectionDialog,
                  icon:
                      _isSendingReport
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send),
                  label: Text(_isSendingReport ? 'Sending...' : 'Send Report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
