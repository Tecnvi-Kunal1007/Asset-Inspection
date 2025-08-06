import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import '../services/site_inspection_service.dart'; // Service doesn't exist
import 'package:google_fonts/google_fonts.dart';

class SiteManagerScreen extends StatefulWidget {
  const SiteManagerScreen({Key? key}) : super(key: key);

  @override
  State<SiteManagerScreen> createState() => _SiteManagerScreenState();
}

class _SiteManagerScreenState extends State<SiteManagerScreen> {
  // final _siteInspectionService = SiteInspectionService(); // Service doesn't exist
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _assignedSites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedSites();
  }

  Future<void> _loadAssignedSites() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // TODO: Implement site inspection service
      final sites = <Map<String, dynamic>>[];
      setState(() {
        _assignedSites = sites;
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

  Future<void> _markInspectionComplete(
    String siteId,
    String freelancerId,
  ) async {
    try {
      // TODO: Implement site inspection service
      final success = true; // Placeholder implementation

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection marked as completed')),
        );
        _loadAssignedSites(); // Reload the sites to update the UI
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking inspection complete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Assigned Sites',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _assignedSites.isEmpty
              ? Center(
                child: Text(
                  'No sites assigned',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              )
              : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _assignedSites.length,
                itemBuilder: (context, index) {
                  final assignment = _assignedSites[index];
                  final site = assignment['sites'];
                  final isCompleted =
                      assignment['inspection_status'] == 'completed';

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
                            site['site_location'] ?? 'No location specified',
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
                                  isCompleted
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isCompleted
                                  ? 'Inspection Completed'
                                  : 'Pending Inspection',
                              style: GoogleFonts.poppins(
                                color:
                                    isCompleted ? Colors.green : Colors.orange,
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
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              const SizedBox(height: 16),
                              if (!isCompleted)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        () => _markInspectionComplete(
                                          site['id'],
                                          assignment['freelancer_id'],
                                        ),
                                    icon: const Icon(Icons.check_circle),
                                    label: Text(
                                      'Mark Inspection Complete',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              if (isCompleted)
                                Text(
                                  'Inspection completed on: ${DateTime.parse(assignment['inspection_completed_at']).toString().split('.')[0]}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }
}
