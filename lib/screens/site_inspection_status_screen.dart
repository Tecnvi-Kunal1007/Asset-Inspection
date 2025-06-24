import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/site_inspection_service.dart';
import 'package:google_fonts/google_fonts.dart';

class SiteInspectionStatusScreen extends StatefulWidget {
  const SiteInspectionStatusScreen({Key? key}) : super(key: key);

  @override
  State<SiteInspectionStatusScreen> createState() =>
      _SiteInspectionStatusScreenState();
}

class _SiteInspectionStatusScreenState
    extends State<SiteInspectionStatusScreen> {
  final _siteInspectionService = SiteInspectionService();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _sites = [];
  bool _isLoading = true;
  String _filterStatus = 'all'; // 'all', 'pending', 'completed'

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final sites = await _siteInspectionService.getSitesWithInspectionStatus(
        user.id,
      );
      setState(() {
        _sites = sites;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading sites: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSites {
    if (_filterStatus == 'all') return _sites;

    return _sites.where((site) {
      final assignments = (site['site_assignments'] as List?) ?? [];
      if (assignments.isEmpty) return _filterStatus == 'pending';

      final hasCompleted = assignments.any(
        (assignment) => assignment['inspection_status'] == 'completed',
      );
      return _filterStatus == 'completed' ? hasCompleted : !hasCompleted;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Site Inspection Status',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment<String>(
                        value: 'all',
                        label: Text('All', style: GoogleFonts.poppins()),
                      ),
                      ButtonSegment<String>(
                        value: 'pending',
                        label: Text('Pending', style: GoogleFonts.poppins()),
                      ),
                      ButtonSegment<String>(
                        value: 'completed',
                        label: Text('Completed', style: GoogleFonts.poppins()),
                      ),
                    ],
                    selected: {_filterStatus},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() {
                        _filterStatus = selection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSites.isEmpty
                    ? Center(
                      child: Text(
                        'No sites found',
                        style: GoogleFonts.poppins(fontSize: 16),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredSites.length,
                      itemBuilder: (context, index) {
                        final site = _filteredSites[index];
                        final assignments =
                            (site['site_assignments'] as List?) ?? [];
                        final hasCompleted = assignments.any(
                          (assignment) =>
                              assignment['inspection_status'] == 'completed',
                        );

                        return Card(
                          elevation: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            title: Text(
                              site['site_name'] ?? 'Unnamed Site',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  site['site_location'] ??
                                      'No location specified',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        hasCompleted
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    hasCompleted
                                        ? 'Inspection Completed'
                                        : 'Pending Inspection',
                                    style: GoogleFonts.poppins(
                                      color:
                                          hasCompleted
                                              ? Colors.green
                                              : Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
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
                                    if (site['site_description'] != null &&
                                        site['site_description'].isNotEmpty)
                                      Text(
                                        site['site_description'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Assigned Inspectors:',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (assignments.isEmpty)
                                      Text(
                                        'No inspectors assigned',
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      )
                                    else
                                      ...assignments.map((assignment) {
                                        final freelancer =
                                            assignment['freelancers'];
                                        final isCompleted =
                                            assignment['inspection_status'] ==
                                            'completed';
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                isCompleted
                                                    ? Colors.green
                                                    : Colors.orange,
                                            child: Icon(
                                              isCompleted
                                                  ? Icons.check
                                                  : Icons.pending,
                                              color: Colors.white,
                                            ),
                                          ),
                                          title: Text(
                                            freelancer['name'] ??
                                                'Unknown Inspector',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                freelancer['email'] ?? '',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (isCompleted &&
                                                  assignment['inspection_completed_at'] !=
                                                      null)
                                                Text(
                                                  'Completed on: ${DateTime.parse(assignment['inspection_completed_at']).toString().split('.')[0]}',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadSites,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
