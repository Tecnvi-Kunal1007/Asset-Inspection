import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/freelancer_service.dart';
import '../models/freelancer.dart';
import '../services/site_assignment_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/area_assignment_service.dart';
import 'add_freelancer_screen.dart';

class ViewFreelancersScreen extends StatefulWidget {
  const ViewFreelancersScreen({Key? key}) : super(key: key);

  @override
  State<ViewFreelancersScreen> createState() => _ViewFreelancersScreenState();
}

class _ViewFreelancersScreenState extends State<ViewFreelancersScreen>
    with SingleTickerProviderStateMixin {
  final FreelancerService _freelancerService = FreelancerService();
  List<Freelancer> _freelancers = [];
  List<Freelancer> _filteredFreelancers = [];
  bool _isLoading = true;
  String _selectedLocation = 'All';
  String _selectedSkill = 'All';
  final Set<String> _locations = {'All'};
  final Set<String> _skills = {'All'};
  final _siteAssignmentService = SiteAssignmentService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadFreelancers();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFreelancers() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      final email = user?.email;

      if (email == null) {
        throw Exception('User not authenticated or email not found');
      }

      // Get contractor ID using email
      final contractorResponse =
          await supabase
              .from('contractor')
              .select('id')
              .eq('email', email)
              .single();

      if (contractorResponse == null) {
        throw Exception('Contractor not found');
      }

      final contractorId = contractorResponse['id'];

      // Fetch freelancers associated with this contractor and role 'freelancer'
      final response = await supabase
          .from('freelancers')
          .select()
          .eq('contractor_id', contractorId)
          .eq('role', 'freelancer');

      setState(() {
        _freelancers.clear();
        _locations.clear();
        _skills.clear();
        _locations.add('All');
        _skills.add('All');

        for (final record in response) {
          final freelancer = Freelancer.fromJson(record);
          _freelancers.add(freelancer);
          if (freelancer.address.isNotEmpty) {
            _locations.add(freelancer.address);
          }
          if (freelancer.skill.isNotEmpty) {
            _skills.add(freelancer.skill);
          }
        }
        _filteredFreelancers = List.from(_freelancers);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading freelancers: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredFreelancers =
          _freelancers.where((freelancer) {
            bool locationMatch =
                _selectedLocation == 'All' ||
                (freelancer.address.toLowerCase() ==
                    _selectedLocation.toLowerCase());
            bool skillMatch =
                _selectedSkill == 'All' ||
                (freelancer.skill.toLowerCase() ==
                    _selectedSkill.toLowerCase());
            bool searchMatch =
                _searchController.text.isEmpty ||
                freelancer.name.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                ) ||
                freelancer.email.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                ) ||
                freelancer.phone.toLowerCase().contains(
                  _searchController.text.toLowerCase(),
                );
            return locationMatch && skillMatch && searchMatch;
          }).toList();
    });
  }

  Future<void> _downloadResume(String resumeUrl) async {
    try {
      if (await canLaunchUrl(Uri.parse(resumeUrl))) {
        await launchUrl(Uri.parse(resumeUrl));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not open resume',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error downloading resume: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAssignSiteDialog(Freelancer freelancer) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You must be logged in to assign sites',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        return;
      }

      final sites = await _siteAssignmentService.getAvailableSitesForAssignment(
        user.id,
        freelancer.id,
      );

      final assignmentsResponse = await supabase
          .from('site_assignments')
          .select('site_id')
          .eq('freelancer_id', freelancer.id);

      final assignedSiteIds =
          (assignmentsResponse as List)
              .map((assignment) => assignment['site_id'] as String)
              .toSet();

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              title: Text(
                'Assign Sites to ${freelancer.name}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              content: Container(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                  ),
                ),
                child:
                    sites.isEmpty
                        ? Center(
                          child: Text(
                            'No sites available for assignment',
                            style: GoogleFonts.poppins(),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: sites.length,
                          itemBuilder: (context, index) {
                            final site = sites[index];
                            final isAssigned = assignedSiteIds.contains(
                              site['id'],
                            );
                            final siteName =
                                site['site_name'] ?? 'Unnamed Site';
                            final siteAddress = site['site_location'] ?? '';

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  siteName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  siteAddress,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                value: isAssigned,
                                activeColor: Colors.blue.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                onChanged: (bool? value) async {
                                  try {
                                    if (value == true) {
                                      await supabase
                                          .from('site_assignments')
                                          .insert({
                                            'site_id': site['id'],
                                            'freelancer_id': freelancer.id,
                                            'inspection_status': 'pending',
                                            'inspection_completed_at': null,
                                          });
                                    } else {
                                      await supabase
                                          .from('site_assignments')
                                          .delete()
                                          .match({
                                            'site_id': site['id'],
                                            'freelancer_id': freelancer.id,
                                          });
                                    }

                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            value == true
                                                ? 'Site assigned successfully'
                                                : 'Site unassigned successfully',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      );
                                      Navigator.pop(context);
                                      _showAssignSiteDialog(freelancer);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error updating assignment: $e',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading sites: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAssignAreaDialog(Map<String, dynamic> freelancer) async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You must be logged in to assign areas'),
            ),
          );
        }
        return;
      }

      // Get contractor ID
      final contractorResponse =
          await supabase
              .from('contractor')
              .select('id')
              .eq('email', user.email!)
              .maybeSingle();

      if (contractorResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contractor not found. Please contact support.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final contractorId = contractorResponse['id'];

      final areaAssignmentService = AreaAssignmentService();
      final areas = await areaAssignmentService.getAvailableAreasForAssignment(
        contractorId,
        freelancer['id'],
      );

      final assignmentsResponse = await supabase
          .from('area_assignments')
          .select('area_id, assignment_type')
          .eq('assigned_to_id', freelancer['id'])
          .eq('status', 'active');

      // Get all assignments for each area to check which sections are assigned
      final allAssignmentsResponse = await supabase
          .from('area_assignments')
          .select('area_id, assignment_type, assigned_to_id')
          .eq('status', 'active');

      // Create a map of area_id to list of assigned sections
      final Map<String, Set<String>> areaAssignments = {};
      for (var assignment in allAssignmentsResponse) {
        final areaId = assignment['area_id'] as String;
        final assignmentType = assignment['assignment_type'] as String;
        areaAssignments.putIfAbsent(areaId, () => {}).add(assignmentType);
      }

      // Create a map of area_id to list of sections assigned to this freelancer
      final Map<String, Set<String>> freelancerAssignments = {};
      for (var assignment in assignmentsResponse) {
        final areaId = assignment['area_id'] as String;
        final assignmentType = assignment['assignment_type'] as String;
        freelancerAssignments.putIfAbsent(areaId, () => {}).add(assignmentType);
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              title: Text(
                'Assign Areas to ${freelancer['name']}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              content: Container(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue.shade50, Colors.blue.shade100],
                  ),
                ),
                child:
                    areas.isEmpty
                        ? Center(
                          child: Text(
                            'No areas available for assignment',
                            style: GoogleFonts.poppins(),
                          ),
                        )
                        : ListView.builder(
                          shrinkWrap: true,
                          itemCount: areas.length,
                          itemBuilder: (context, index) {
                            final area = areas[index];
                            final areaId = area['id'] as String;
                            final assignedSections =
                                areaAssignments[areaId] ?? {};
                            final freelancerAssignedSections =
                                freelancerAssignments[areaId] ?? {};
                            final areaName = area['name'] ?? 'Unnamed Area';
                            final areaLocation = area['site_location'] ?? '';

                            // Check if both sections are assigned
                            final bool isFullyAssigned =
                                assignedSections.contains('pumps_floor') &&
                                assignedSections.contains('building_fire');

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              child: Column(
                                children: [
                                  ListTile(
                                    title: Text(
                                      areaName,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          areaLocation,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (assignedSections.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 8,
                                            children: [
                                              if (assignedSections.contains(
                                                'pumps_floor',
                                              ))
                                                _buildAssignmentChip(
                                                  'Pumps & Floor',
                                                  freelancerAssignedSections
                                                      .contains('pumps_floor'),
                                                  () async {
                                                    try {
                                                      await areaAssignmentService
                                                          .unassignArea(
                                                            areaId,
                                                            freelancer['id'],
                                                          );
                                                      if (mounted) {
                                                        Navigator.pop(context);
                                                        _showAssignAreaDialog(
                                                          freelancer,
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error: $e',
                                                            ),
                                                            backgroundColor:
                                                                Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                              if (assignedSections.contains(
                                                'building_fire',
                                              ))
                                                _buildAssignmentChip(
                                                  'Building & Fire',
                                                  freelancerAssignedSections
                                                      .contains(
                                                        'building_fire',
                                                      ),
                                                  () async {
                                                    try {
                                                      await areaAssignmentService
                                                          .unassignArea(
                                                            areaId,
                                                            freelancer['id'],
                                                          );
                                                      if (mounted) {
                                                        Navigator.pop(context);
                                                        _showAssignAreaDialog(
                                                          freelancer,
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Error: $e',
                                                            ),
                                                            backgroundColor:
                                                                Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing:
                                        isFullyAssigned
                                            ? null
                                            : IconButton(
                                              icon: const Icon(Icons.add),
                                              onPressed: () async {
                                                // Show only unassigned sections
                                                final availableSections = [
                                                  if (!assignedSections
                                                      .contains('pumps_floor'))
                                                    'pumps_floor',
                                                  if (!assignedSections
                                                      .contains(
                                                        'building_fire',
                                                      ))
                                                    'building_fire',
                                                ];

                                                if (availableSections.isEmpty)
                                                  return;

                                                final assignmentType = await showDialog<
                                                  String
                                                >(
                                                  context: context,
                                                  builder:
                                                      (context) => AlertDialog(
                                                        title: Text(
                                                          'Select Assignment Type',
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        content: Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children:
                                                              availableSections.map((
                                                                section,
                                                              ) {
                                                                return ListTile(
                                                                  title: Text(
                                                                    section ==
                                                                            'pumps_floor'
                                                                        ? 'Pump and Floor Inspection'
                                                                        : 'Fire Alarm Inspection',
                                                                    style:
                                                                        GoogleFonts.poppins(),
                                                                  ),
                                                                  onTap:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        section,
                                                                      ),
                                                                );
                                                              }).toList(),
                                                        ),
                                                      ),
                                                );

                                                if (assignmentType != null) {
                                                  try {
                                                    await areaAssignmentService
                                                        .assignArea(
                                                          areaId: areaId,
                                                          assignedToId:
                                                              freelancer['id'],
                                                          assignedToType:
                                                              'freelancer',
                                                          assignedById: user.id,
                                                          assignmentType:
                                                              assignmentType,
                                                        );
                                                    if (mounted) {
                                                      Navigator.pop(context);
                                                      _showAssignAreaDialog(
                                                        freelancer,
                                                      );
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Error: $e',
                                                          ),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  }
                                                }
                                              },
                                            ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadFreelancers,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Freelancers',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue.shade700, Colors.blue.shade500],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.people,
                    size: 80,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter Freelancers',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _searchController,
                              style: GoogleFonts.poppins(),
                              decoration: InputDecoration(
                                hintText: 'Search freelancers...',
                                hintStyle: GoogleFonts.poppins(
                                  color: Colors.grey.shade400,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.blue.shade700,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.blue.shade100,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.blue.shade100,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    color: Colors.blue.shade700,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) => _applyFilters(),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedLocation,
                                    isExpanded: true,
                                    isDense: true,
                                    decoration: InputDecoration(
                                      labelText: 'Location',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      labelStyle: GoogleFonts.poppins(
                                        color: Colors.blue.shade700,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Colors.blue.shade100,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Colors.blue.shade700,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    items:
                                        _locations
                                            .map(
                                              (location) => DropdownMenuItem(
                                                value: location,
                                                child: Text(
                                                  location,
                                                  style: GoogleFonts.poppins(),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedLocation = value;
                                          _applyFilters();
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedSkill,
                                    isExpanded: true,
                                    isDense: true,
                                    decoration: InputDecoration(
                                      labelText: 'Skill',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      labelStyle: GoogleFonts.poppins(
                                        color: Colors.blue.shade700,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Colors.blue.shade100,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(15),
                                        borderSide: BorderSide(
                                          color: Colors.blue.shade700,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    items:
                                        _skills
                                            .map(
                                              (skill) => DropdownMenuItem(
                                                value: skill,
                                                child: Text(
                                                  skill,
                                                  style: GoogleFonts.poppins(),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedSkill = value;
                                          _applyFilters();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (_filteredFreelancers.isEmpty)
                      Center(
                        child: Text(
                          'No freelancers found',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredFreelancers.length,
                        itemBuilder: (context, index) {
                          final freelancer = _filteredFreelancers[index];
                          return Card(
                            elevation: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.blue.shade50, Colors.white],
                                ),
                              ),
                              child: ExpansionTile(
                                tilePadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    freelancer.name[0].toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  freelancer.name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  freelancer.skill,
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      16,
                                    ),
                                    child: Column(
                                      children: [
                                        _buildInfoRow(
                                          'Email',
                                          freelancer.email,
                                          Icons.email,
                                        ),
                                        _buildInfoRow(
                                          'Phone',
                                          freelancer.phone,
                                          Icons.phone,
                                        ),
                                        _buildInfoRow(
                                          'Location',
                                          freelancer.address,
                                          Icons.location_on,
                                        ),
                                        _buildInfoRow(
                                          'Experience',
                                          '${freelancer.experienceYears} years',
                                          Icons.work,
                                        ),
                                        const SizedBox(height: 16),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed:
                                                  () => _showAssignSiteDialog(
                                                    freelancer,
                                                  ),
                                              icon: const Icon(
                                                Icons.assignment,
                                              ),
                                              label: Text(
                                                'Assign Sites',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.blue.shade700,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                elevation: 2,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                if (freelancer.resumeUrl !=
                                                    null) {
                                                  launchUrl(
                                                    Uri.parse(
                                                      freelancer.resumeUrl!,
                                                    ),
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.description,
                                              ),
                                              label: Text(
                                                'View Resume',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.orange.shade700,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                elevation: 2,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ElevatedButton.icon(
                                              onPressed:
                                                  () => _showAssignAreaDialog({
                                                    'id': freelancer.id,
                                                    'name': freelancer.name,
                                                  }),
                                              icon: const Icon(Icons.map),
                                              label: Text(
                                                'Assign Areas',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.green.shade700,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                elevation: 2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFreelancerScreen(),
            ),
          );
        },
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentChip(
    String label,
    bool isAssignedToFreelancer,
    VoidCallback onUnassign,
  ) {
    return Chip(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: isAssignedToFreelancer ? Colors.white : Colors.blue.shade700,
        ),
      ),
      backgroundColor:
          isAssignedToFreelancer ? Colors.blue.shade700 : Colors.blue.shade50,
      deleteIcon:
          isAssignedToFreelancer
              ? const Icon(Icons.close, size: 16, color: Colors.white)
              : null,
      onDeleted: isAssignedToFreelancer ? onUnassign : null,
    );
  }
}
