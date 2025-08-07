import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/assignment.dart';
import '../models/premise.dart';
import '../services/assignment_service.dart';
import '../services/supabase_service.dart';
import '../utils/theme_helper.dart';
import '../utils/responsive_helper.dart';
import 'premise_assignment_screen.dart';

class AssignmentOverviewScreen extends StatefulWidget {
  const AssignmentOverviewScreen({Key? key}) : super(key: key);

  @override
  State<AssignmentOverviewScreen> createState() =>
      _AssignmentOverviewScreenState();
}

class _AssignmentOverviewScreenState extends State<AssignmentOverviewScreen>
    with TickerProviderStateMixin {
  final AssignmentService _assignmentService = AssignmentService();
  final SupabaseService _supabaseService = SupabaseService();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  AssignmentOverview? _overview;
  List<Premise> _allPremises = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final TextEditingController _searchController = TextEditingController();
  final List<String> _filterOptions = [
    'All',
    'Assigned',
    'Unassigned',
    'Fire Inspection',
    'Security',
    'Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final overview = await _assignmentService.getContractorAssignments();
      final premises = await _supabaseService.getPremises();

      setState(() {
        _overview = overview;
        _allPremises = premises;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load assignments: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThemeHelper.purple.withOpacity(0.05),
              ThemeHelper.orange.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: _isLoading ? _buildLoadingState() : _buildMainContent(),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: ThemeHelper.cardShadow,
            ),
            child: Column(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ThemeHelper.purple),
                  strokeWidth: 3,
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading assignments...',
                  style: ThemeHelper.bodyStyle(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildStatsCards(),
              const SizedBox(height: 20),
              _buildSearchAndFilter(),
              const SizedBox(height: 20),
              _buildAssignmentsList(),
              const SizedBox(height: 100), // Bottom padding for FAB
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ThemeHelper.purple, ThemeHelper.orange],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assignment Overview',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Track all premise assignments',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.dashboard,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _loadData,
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    if (_overview == null) return const SizedBox.shrink();

    return ResponsiveHelper.responsiveWidget(
      context: context,
      mobile: _buildStatsCardsMobile(),
      tablet: _buildStatsCardsTablet(),
      desktop: _buildStatsCardsDesktop(),
    );
  }

  Widget _buildStatsCardsMobile() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Premises',
                _overview!.totalPremises.toString(),
                Icons.business,
                ThemeHelper.primaryBlue,
                0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Assigned',
                _overview!.assignedPremises.toString(),
                Icons.assignment_turned_in,
                ThemeHelper.green,
                1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Tasks',
                _overview!.totalAssignments.toString(),
                Icons.task_alt,
                ThemeHelper.orange,
                2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Coverage',
                '${_overview!.assignmentPercentage.toStringAsFixed(1)}%',
                Icons.pie_chart,
                ThemeHelper.purple,
                3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsCardsTablet() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Premises',
            _overview!.totalPremises.toString(),
            Icons.business,
            ThemeHelper.primaryBlue,
            0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Assigned',
            _overview!.assignedPremises.toString(),
            Icons.assignment_turned_in,
            ThemeHelper.green,
            1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Total Tasks',
            _overview!.totalAssignments.toString(),
            Icons.task_alt,
            ThemeHelper.orange,
            2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Coverage',
            '${_overview!.assignmentPercentage.toStringAsFixed(1)}%',
            Icons.pie_chart,
            ThemeHelper.purple,
            3,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCardsDesktop() {
    return _buildStatsCardsTablet(); // Same as tablet for now
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    int index,
  ) {
    return Container(
          padding: const EdgeInsets.all(16),
          decoration: ThemeHelper.cardDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: ThemeHelper.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: (index * 100).ms, duration: 600.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ThemeHelper.cardDecoration(),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search premises or freelancers...',
              prefixIcon: Icon(Icons.search, color: ThemeHelper.textSecondary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: ThemeHelper.textSecondary.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: ThemeHelper.purple),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 16),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  _filterOptions
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(filter),
                            selected: _selectedFilter == filter,
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = selected ? filter : 'All';
                              });
                            },
                            backgroundColor: ThemeHelper.backgroundLight,
                            selectedColor: ThemeHelper.purple.withOpacity(0.2),
                            checkmarkColor: ThemeHelper.purple,
                            labelStyle: GoogleFonts.poppins(
                              color:
                                  _selectedFilter == filter
                                      ? ThemeHelper.purple
                                      : ThemeHelper.textSecondary,
                              fontWeight:
                                  _selectedFilter == filter
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms);
  }

  Widget _buildAssignmentsList() {
    if (_overview == null) return const SizedBox.shrink();

    final filteredPremises = _getFilteredPremises();

    if (filteredPremises.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: ThemeHelper.cardDecoration(),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: ThemeHelper.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No assignments found',
              style: ThemeHelper.subheadingStyle(
                context,
                color: ThemeHelper.textSecondary,
              ),
            ),
            Text(
              'Try adjusting your search or filters',
              style: ThemeHelper.bodyStyle(context),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 400.ms, duration: 600.ms);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assignments (${filteredPremises.length})',
          style: ThemeHelper.headingStyle(context),
        ),
        const SizedBox(height: 16),
        ...filteredPremises.asMap().entries.map((entry) {
          final index = entry.key;
          final premise = entry.value;
          return _buildPremiseAssignmentCard(premise, index);
        }),
      ],
    );
  }

  List<dynamic> _getFilteredPremises() {
    if (_overview == null) return [];

    List<dynamic> premises = [];

    // Add assigned premises
    for (final premiseAssignment in _overview!.premiseAssignments) {
      premises.add(premiseAssignment);
    }

    // Add unassigned premises if filter allows
    if (_selectedFilter == 'All' || _selectedFilter == 'Unassigned') {
      final assignedPremiseIds =
          _overview!.premiseAssignments.map((pa) => pa.premiseId).toSet();

      for (final premise in _allPremises) {
        if (!assignedPremiseIds.contains(premise.id)) {
          premises.add(premise);
        }
      }
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      premises =
          premises.where((item) {
            if (item is PremiseAssignment) {
              return item.premiseName.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  item.assignedFreelancerNames.any(
                    (name) =>
                        name.toLowerCase().contains(_searchQuery.toLowerCase()),
                  );
            } else if (item is Premise) {
              return item.name.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );
            }
            return false;
          }).toList();
    }

    // Apply category filter
    if (_selectedFilter != 'All' &&
        _selectedFilter != 'Assigned' &&
        _selectedFilter != 'Unassigned') {
      premises =
          premises.where((item) {
            if (item is PremiseAssignment) {
              return item.assignmentsList.any(
                (assignment) => assignment.tasks.any(
                  (task) => task.toLowerCase().contains(
                    _selectedFilter.toLowerCase(),
                  ),
                ),
              );
            }
            return false;
          }).toList();
    } else if (_selectedFilter == 'Assigned') {
      premises = premises.where((item) => item is PremiseAssignment).toList();
    } else if (_selectedFilter == 'Unassigned') {
      premises = premises.where((item) => item is Premise).toList();
    }

    return premises;
  }

  Widget _buildPremiseAssignmentCard(dynamic item, int index) {
    if (item is PremiseAssignment) {
      return _buildAssignedPremiseCard(item, index);
    } else if (item is Premise) {
      return _buildUnassignedPremiseCard(item, index);
    }
    return const SizedBox.shrink();
  }

  Widget _buildAssignedPremiseCard(
    PremiseAssignment premiseAssignment,
    int index,
  ) {
    final gradient = ThemeHelper.getGradientByIndex(index);

    return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: ThemeHelper.gradientCardDecoration(gradient),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.business,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            premiseAssignment.premiseName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${premiseAssignment.assignmentCount} assignments',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed:
                          () => _navigateToAssignment(
                            premiseAssignment.premiseId,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...premiseAssignment.assignmentsList.map(
                  (assignment) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          child: Text(
                            assignment.freelancerName
                                .substring(0, 1)
                                .toUpperCase(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assignment.freelancerName,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                assignment.tasks.join(', '),
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (index * 100).ms, duration: 600.ms)
        .slideX(begin: 0.3, end: 0);
  }

  Widget _buildUnassignedPremiseCard(Premise premise, int index) {
    return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: ThemeHelper.cardDecoration(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: ThemeHelper.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.business_outlined,
                    color: ThemeHelper.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        premise.name,
                        style: ThemeHelper.subheadingStyle(context),
                      ),
                      Text(
                        'No assignments yet',
                        style: GoogleFonts.poppins(
                          color: ThemeHelper.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _navigateToAssignment(premise.id),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Assign'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeHelper.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: (index * 100).ms, duration: 600.ms)
        .slideX(begin: -0.3, end: 0);
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: () {
        // Show premise selection dialog
        _showPremiseSelectionDialog();
      },
      backgroundColor: ThemeHelper.purple,
      icon: const Icon(Icons.add_task, color: Colors.white),
      label: Text(
        'Quick Assign',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _navigateToAssignment(String premiseId) async {
    final premise = _allPremises.firstWhere((p) => p.id == premiseId);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PremiseAssignmentScreen(premise: premise),
      ),
    );

    if (result == true) {
      _loadData(); // Refresh data if assignment was made
    }
  }

  void _showPremiseSelectionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Select Premise to Assign',
              style: ThemeHelper.headingStyle(context),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: _allPremises.length,
                itemBuilder: (context, index) {
                  final premise = _allPremises[index];
                  final isAssigned =
                      _overview?.premiseAssignments.any(
                        (pa) => pa.premiseId == premise.id,
                      ) ??
                      false;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isAssigned
                              ? ThemeHelper.green.withOpacity(0.2)
                              : ThemeHelper.textSecondary.withOpacity(0.2),
                      child: Icon(
                        isAssigned
                            ? Icons.assignment_turned_in
                            : Icons.business,
                        color:
                            isAssigned
                                ? ThemeHelper.green
                                : ThemeHelper.textSecondary,
                        size: 20,
                      ),
                    ),
                    title: Text(premise.name),
                    subtitle: Text(
                      isAssigned ? 'Already assigned' : 'Not assigned',
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: ThemeHelper.textSecondary,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToAssignment(premise.id);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: ThemeHelper.textSecondary),
                ),
              ),
            ],
          ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
