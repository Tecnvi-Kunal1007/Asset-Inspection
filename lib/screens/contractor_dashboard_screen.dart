import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pump_management_system/screens/areas_screen.dart';
import 'package:pump_management_system/screens/add_freelancer_screen.dart';
import 'package:pump_management_system/screens/view_freelancers_screen.dart';
import 'package:pump_management_system/screens/employee_management_screen.dart';
import 'package:pump_management_system/screens/site_assignment_history_screen.dart';
import 'package:pump_management_system/screens/product_management_screen.dart';
import 'package:pump_management_system/screens/site_inspection_status_screen.dart';
import 'package:pump_management_system/screens/work_reports_screen.dart';
import 'package:pump_management_system/screens/area_assignment_history_screen.dart';
import 'package:pump_management_system/screens/area_inspection_status_screen.dart';
import 'package:pump_management_system/screens/task_management_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pump_management_system/widgets/billboard_footer.dart';
import 'package:pump_management_system/widgets/floating_chatbot.dart';

class ContractorDashboardScreen extends StatelessWidget {
  const ContractorDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 200.0,
                      floating: false,
                      pinned: true,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          'Contractor Dashboard',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blue.shade800,
                                Colors.blue.shade500,
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.dashboard_customize,
                              size: 80,
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isSmallScreen ? 1 : 2,
                          childAspectRatio: isSmallScreen ? 1.5 : 1.2,
                          crossAxisSpacing: 16.0,
                          mainAxisSpacing: 16.0,
                        ),
                        delegate: SliverChildListDelegate([
                          _buildDashboardCard(
                            context,
                            'Manage Sites',
                            Icons.construction,
                            'Track and manage all your construction sites',
                            Colors.orange,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AreasScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Handle Freelancers',
                            Icons.people,
                            'Manage your freelancer workforce',
                            Colors.green,
                            () {
                              _showFreelancerOptions(context);
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Manage Employees',
                            Icons.business,
                            'Oversee your employee operations',
                            Colors.purple,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const EmployeeManagementScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Area Assignments',
                            Icons.map,
                            'Manage area assignments and history',
                            Colors.green,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const AreaAssignmentHistoryScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Area Inspections',
                            Icons.assignment_turned_in,
                            'View area inspection status and reports',
                            const Color.fromARGB(255, 218, 68, 120),
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          const AreaInspectionStatusScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Work Reports',
                            Icons.description,
                            'View work reports from freelancers',
                            Colors.indigo,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const WorkReportsScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Task Management',
                            Icons.task,
                            'Manage and track tasks',
                            Colors.amber,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => const TaskManagementScreen(),
                                ),
                              );
                            },
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              const BillboardFooter(),
            ],
          ),
          // Floating chatbot
          const FloatingChatbot(userRole: 'contractor'),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    String description,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.8), color],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: Colors.white),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFreelancerOptions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ViewFreelancersScreen()),
    );
  }
}
