import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/premise.dart';
import '../models/freelancer.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';
import '../services/freelancer_service.dart';
import '../utils/theme_helper.dart';
import '../utils/responsive_helper.dart';

class PremiseAssignmentScreen extends StatefulWidget {
  final Premise premise;

  const PremiseAssignmentScreen({Key? key, required this.premise})
    : super(key: key);

  @override
  State<PremiseAssignmentScreen> createState() =>
      _PremiseAssignmentScreenState();
}

class _PremiseAssignmentScreenState extends State<PremiseAssignmentScreen>
    with TickerProviderStateMixin {
  final AssignmentService _assignmentService = AssignmentService();
  final FreelancerService _freelancerService = FreelancerService();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Freelancer> _freelancers = [];
  List<Freelancer> _employees = [];
  PremiseAssignment? _currentAssignments;
  bool _isLoading = true;

  Freelancer? _selectedFreelancer;
  final TextEditingController _taskController = TextEditingController();
  final List<String> _tasks = [];

  // Predefined task suggestions
  final List<String> _taskSuggestions = [
    'Fire Inspection',
    'Fire Fighting Equipment Check',
    'Security Assessment',
    'Drainage Maintenance',
    'Electrical Safety Check',
    'HVAC Inspection',
    'Emergency Exit Verification',
    'Safety Equipment Audit',
    'Structural Assessment',
    'Compliance Review',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadData();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
      final freelancers =
          await _freelancerService.getFreelancersForCurrentContractor();
      final employees =
          await _freelancerService.getEmployeesForCurrentContractor();
      final assignments = await _assignmentService.getPremiseAssignments(
        widget.premise.id,
      );

      setState(() {
        _freelancers = freelancers;
        _employees = employees;
        _currentAssignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load data: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ThemeHelper.purple.withOpacity(0.1),
              ThemeHelper.orange.withOpacity(0.1),
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
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: ThemeHelper.cardShadow,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ThemeHelper.purple),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading assignment data...',
            style: ThemeHelper.bodyStyle(
              context,
              color: ThemeHelper.textSecondary,
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
              _buildPremiseCard(),
              const SizedBox(height: 20),
              _buildCurrentAssignments(),
              const SizedBox(height: 20),
              _buildNewAssignmentCard(),
              const SizedBox(height: 100), // Bottom padding
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
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
                  Text(
                    'Assign Tasks',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Manage premise assignments',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
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
    );
  }

  Widget _buildPremiseCard() {
    return Container(
      decoration: ThemeHelper.cardDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ThemeHelper.primaryBlue.withOpacity(0.1),
            ThemeHelper.cyan.withOpacity(0.1),
          ],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ThemeHelper.primaryBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.business,
                  color: ThemeHelper.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.premise.name,
                      style: ThemeHelper.headingStyle(context),
                    ),
                    Text(
                      'Premise ID: ${widget.premise.id.substring(0, 8)}...',
                      style: ThemeHelper.bodyStyle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.premise.additionalData.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Additional Information',
              style: ThemeHelper.subheadingStyle(context),
            ),
            const SizedBox(height: 8),
            ...widget.premise.additionalData.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      '${entry.key}: ',
                      style: ThemeHelper.bodyStyle(
                        context,
                        color: ThemeHelper.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value.toString(),
                        style: ThemeHelper.bodyStyle(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.3, end: 0);
  }

  Widget _buildCurrentAssignments() {
    if (_currentAssignments == null || !_currentAssignments!.hasAssignments) {
      return Container(
        decoration: ThemeHelper.cardDecoration(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 48,
              color: ThemeHelper.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No assignments yet',
              style: ThemeHelper.subheadingStyle(
                context,
                color: ThemeHelper.textSecondary,
              ),
            ),
            Text(
              'Create your first assignment below',
              style: ThemeHelper.bodyStyle(context),
            ),
          ],
        ),
      ).animate().fadeIn(delay: 200.ms, duration: 600.ms);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current Assignments', style: ThemeHelper.headingStyle(context)),
        const SizedBox(height: 16),
        ...(_currentAssignments!.assignmentsList.asMap().entries.map((entry) {
          final index = entry.key;
          final assignment = entry.value;
          return _buildAssignmentCard(assignment, index);
        })),
      ],
    );
  }

  Widget _buildAssignmentCard(Assignment assignment, int index) {
    final gradient = ThemeHelper.getGradientByIndex(index);

    return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: ThemeHelper.gradientCardDecoration(gradient),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.3),
                      child: Text(
                        assignment.freelancerName.substring(0, 1).toUpperCase(),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assignment.freelancerName,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (assignment.role != null)
                            Text(
                              assignment.role!,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                      onPressed:
                          () => _removeAssignment(assignment.freelancerId),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tasks:',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      assignment.tasks
                          .map(
                            (task) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                task,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Assigned: ${_formatDate(assignment.assignedDate)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
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

  Widget _buildNewAssignmentCard() {
    return Container(
      decoration: ThemeHelper.cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ThemeHelper.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_task, color: ThemeHelper.green, size: 20),
              ),
              const SizedBox(width: 12),
              Text('New Assignment', style: ThemeHelper.headingStyle(context)),
            ],
          ),
          const SizedBox(height: 20),
          _buildFreelancerSelection(),
          if (_selectedFreelancer != null) ...[
            const SizedBox(height: 20),
            _buildTaskInput(),
            const SizedBox(height: 20),
            _buildTaskSuggestions(),
            if (_tasks.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSelectedTasks(),
            ],
            const SizedBox(height: 20),
            _buildAssignButton(),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 600.ms);
  }

  Widget _buildFreelancerSelection() {
    final allPeople = [..._freelancers, ..._employees];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Freelancer/Employee',
          style: ThemeHelper.subheadingStyle(context),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: ThemeHelper.textSecondary.withOpacity(0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Freelancer>(
              value: _selectedFreelancer,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Choose a person to assign',
                  style: ThemeHelper.bodyStyle(context),
                ),
              ),
              items:
                  allPeople
                      .map(
                        (person) => DropdownMenuItem<Freelancer>(
                          value: person,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: ThemeHelper.getColorByIndex(
                                    allPeople.indexOf(person),
                                  ).withOpacity(0.2),
                                  child: Text(
                                    person.name.substring(0, 1).toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      color: ThemeHelper.getColorByIndex(
                                        allPeople.indexOf(person),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        person.name,
                                        style: ThemeHelper.bodyStyle(context),
                                      ),
                                      Text(
                                        '${person.role} • ${person.skill}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: ThemeHelper.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (Freelancer? value) {
                setState(() {
                  _selectedFreelancer = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add Custom Task', style: ThemeHelper.subheadingStyle(context)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _taskController,
                decoration: InputDecoration(
                  hintText: 'Enter task description...',
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
                onSubmitted: (_) => _addTask(),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: ThemeHelper.purpleGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: _addTask,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Add Tasks', style: ThemeHelper.subheadingStyle(context)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _taskSuggestions
                  .map(
                    (task) => GestureDetector(
                      onTap: () => _addTaskFromSuggestion(task),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _tasks.contains(task)
                                  ? ThemeHelper.green.withOpacity(0.2)
                                  : ThemeHelper.backgroundLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                _tasks.contains(task)
                                    ? ThemeHelper.green
                                    : ThemeHelper.textSecondary.withOpacity(
                                      0.3,
                                    ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_tasks.contains(task))
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: ThemeHelper.green,
                              )
                            else
                              Icon(
                                Icons.add_circle_outline,
                                size: 16,
                                color: ThemeHelper.textSecondary,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              task,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color:
                                    _tasks.contains(task)
                                        ? ThemeHelper.green
                                        : ThemeHelper.textSecondary,
                                fontWeight:
                                    _tasks.contains(task)
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
      ],
    );
  }

  Widget _buildSelectedTasks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Tasks (${_tasks.length})',
          style: ThemeHelper.subheadingStyle(context),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ThemeHelper.backgroundLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ThemeHelper.purple.withOpacity(0.3)),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _tasks
                    .map(
                      (task) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: ThemeHelper.purpleGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              task,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _removeTask(task),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAssignButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _tasks.isNotEmpty ? _assignTasks : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeHelper.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in),
            const SizedBox(width: 8),
            Text(
              'Assign Tasks',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  void _addTask() {
    final task = _taskController.text.trim();
    if (task.isNotEmpty && !_tasks.contains(task)) {
      setState(() {
        _tasks.add(task);
        _taskController.clear();
      });
    }
  }

  void _addTaskFromSuggestion(String task) {
    if (!_tasks.contains(task)) {
      setState(() {
        _tasks.add(task);
      });
    } else {
      setState(() {
        _tasks.remove(task);
      });
    }
  }

  void _removeTask(String task) {
    setState(() {
      _tasks.remove(task);
    });
  }

  Future<void> _assignTasks() async {
    if (_selectedFreelancer == null || _tasks.isEmpty) return;

    try {
      final success = await _assignmentService.assignFreelancerToPremise(
        premiseId: widget.premise.id,
        freelancerId: _selectedFreelancer!.id,
        freelancerName: _selectedFreelancer!.name,
        tasks: _tasks,
        role: _selectedFreelancer!.role,
        email: _selectedFreelancer!.email,
        phone: _selectedFreelancer!.phone,
      );

      if (success) {
        _showSuccessSnackBar('Assignment created successfully!');
        setState(() {
          _selectedFreelancer = null;
          _tasks.clear();
          _taskController.clear();
        });
        await _loadData(); // Refresh assignments
      } else {
        _showErrorSnackBar('Failed to create assignment');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating assignment: $e');
    }
  }

  Future<void> _removeAssignment(String freelancerId) async {
    try {
      final success = await _assignmentService.removeAssignment(
        premiseId: widget.premise.id,
        freelancerId: freelancerId,
      );

      if (success) {
        _showSuccessSnackBar('Assignment removed successfully!');
        await _loadData(); // Refresh assignments
      } else {
        _showErrorSnackBar('Failed to remove assignment');
      }
    } catch (e) {
      _showErrorSnackBar('Error removing assignment: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ThemeHelper.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
