import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/work_report.dart';
import '../services/work_report_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkReportsScreen extends StatefulWidget {
  const WorkReportsScreen({Key? key}) : super(key: key);

  @override
  State<WorkReportsScreen> createState() => _WorkReportsScreenState();
}

class _WorkReportsScreenState extends State<WorkReportsScreen> {
  final _workReportService = WorkReportService();
  final _supabase = Supabase.instance.client;
  List<WorkReport> _reports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final reports = await _workReportService.getWorkReportsByContractor(
        user.id,
      );
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading reports: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Work Reports',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReports),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _reports.isEmpty
              ? Center(
                child: Text(
                  'No work reports found',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reports.length,
                itemBuilder: (context, index) {
                  final report = _reports[index];
                  return _buildReportCard(report);
                },
              ),
    );
  }

  Widget _buildReportCard(WorkReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: false,
        collapsedIconColor: Colors.blue.shade700,
        iconColor: Colors.blue.shade700,
        title: Row(
          children: [
            Icon(Icons.description, color: Colors.blue.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.equipmentName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(report.repairDate),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Work Description
                _buildInfoRow('Work Description', report.workDescription),
                const SizedBox(height: 12),

                // Replaced Parts
                _buildInfoRow('Replaced Parts', report.replacedParts),
                const SizedBox(height: 12),

                // Repair Date
                _buildInfoRow(
                  'Repair Date',
                  DateFormat('MMM dd, yyyy').format(report.repairDate),
                ),
                const SizedBox(height: 12),

                // Next Due Date
                _buildInfoRow(
                  'Next Due Date',
                  DateFormat('MMM dd, yyyy').format(report.nextDueDate),
                ),
                const SizedBox(height: 12),

                // QR Code Data
                if (report.qrCodeData != null) ...[
                  _buildInfoRow('QR Code Data', report.qrCodeData!),
                  const SizedBox(height: 12),
                ],

                // Photos Section
                if (report.workPhotoUrl != null ||
                    report.finishedPhotoUrl != null ||
                    report.geotaggedPhotoUrl != null) ...[
                  Text(
                    'Photos',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      if (report.workPhotoUrl != null)
                        _buildPhotoSection('Work Photo', report.workPhotoUrl!),
                      if (report.finishedPhotoUrl != null) ...[
                        const SizedBox(height: 16),
                        _buildPhotoSection(
                          'Finished Photo',
                          report.finishedPhotoUrl!,
                        ),
                      ],
                      if (report.geotaggedPhotoUrl != null) ...[
                        const SizedBox(height: 16),
                        _buildPhotoSection(
                          'Geotagged Photo',
                          report.geotaggedPhotoUrl!,
                          locationAddress: report.locationAddress,
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(
    String label,
    String url, {
    String? locationAddress,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.blue.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                color: Colors.grey.shade200,
                child: const Icon(Icons.error),
              );
            },
          ),
        ),
        if (locationAddress != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    locationAddress,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
