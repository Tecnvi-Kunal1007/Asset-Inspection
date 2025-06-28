import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pump_management_system/screens/premises_screen.dart';
import 'package:pump_management_system/screens/task_management_screen.dart';
import 'package:pump_management_system/screens/view_freelancers_screen.dart';
import 'package:pump_management_system/screens/work_reports_screen.dart';
import '../widgets/billboard_footer.dart';
import '../widgets/floating_chat.dart';
import 'area_assignment_history_screen.dart';
import 'area_inspection_status_screen.dart';
import 'areas_screen.dart';
import 'employee_management_screen.dart';

class ContractorDashboardScreen extends StatelessWidget {
  const ContractorDashboardScreen({Key? key}) : super(key: key);

  // Company color palette
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryPurple = Color(0xFF9C27B0);
  static const Color primaryTeal = Color(0xFF009688);
  static const Color primaryOrange = Color(0xFFFF9800);
  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color primaryIndigo = Color(0xFF3F51B5);
  static const Color primaryCyan = Color(0xFF00BCD4);
  static const Color backgroundGradientStart = Color(0xFFF8F9FA);
  static const Color backgroundGradientEnd = Color(0xFFE9ECEF);

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isMediumScreen = screenSize.width >= 600 && screenSize.width < 900;
    final isLargeScreen = screenSize.width >= 900;

    // Determine grid columns based on screen size
    int getCrossAxisCount() {
      if (isSmallScreen) return 1;
      if (isMediumScreen) return 2;
      return 3;
    }

    // Dynamic aspect ratio based on screen size
    double getAspectRatio() {
      if (isSmallScreen) return 1.3;
      if (isMediumScreen) return 1.2;
      return 1.1;
    }

    return Scaffold(
      backgroundColor: backgroundGradientStart,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  backgroundGradientStart,
                  backgroundGradientEnd,
                  Color(0xFFE3F2FD),
                ],
              ),
            ),
          ),
          // Floating shapes background
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryBlue.withOpacity(0.1),
                    primaryBlue.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryPurple.withOpacity(0.1),
                    primaryPurple.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: isSmallScreen ? 200.0 : 240.0,
                      floating: false,
                      pinned: true,
                      backgroundColor: Colors.white,
                      elevation: 0,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          'Contractor Dashboard',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                            fontSize: isSmallScreen ? 18 : 22,
                          ),
                        ),
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryBlue,
                                primaryPurple,
                                primaryTeal,
                              ],
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Animated background pattern
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        image: NetworkImage('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNDAiIGhlaWdodD0iNDAiIHZpZXdCb3g9IjAgMCA0MCA0MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZGVmcz48cGF0dGVybiBpZD0iZG90cyIgd2lkdGg9IjQwIiBoZWlnaHQ9IjQwIiBwYXR0ZXJuVW5pdHM9InVzZXJTcGFjZU9uVXNlIj48Y2lyY2xlIGN4PSIyMCIgY3k9IjIwIiByPSIyIiBmaWxsPSIjZmZmIiBvcGFjaXR5PSIwLjMiLz48L3BhdHRlcm4+PC9kZWZzPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9InVybCgjZG90cykiLz48L3N2Zz4='),
                                        repeat: ImageRepeat.repeat,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Main icon with glow effect
                              Center(
                                child: Container(
                                  padding: EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.dashboard_customize,
                                    size: isSmallScreen ? 60 : 80,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              // Floating elements
                              Positioned(
                                top: 60,
                                right: 40,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 100,
                                left: 30,
                                child: Container(
                                  width: 15,
                                  height: 15,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: getCrossAxisCount(),
                          childAspectRatio: getAspectRatio(),
                          crossAxisSpacing: isSmallScreen ? 16.0 : 20.0,
                          mainAxisSpacing: isSmallScreen ? 16.0 : 20.0,
                        ),
                        delegate: SliverChildListDelegate([
                          _buildDashboardCard(
                            context,
                            'Manage Sites',
                            Icons.construction,
                            'Track and manage all your construction sites',
                            primaryBlue,
                            primaryIndigo,
                            Icons.location_city,
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
                            primaryPurple,
                            Color(0xFF7B1FA2),
                            Icons.group_work,
                                () {
                              _showFreelancerOptions(context);
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Manage Employees',
                            Icons.business,
                            'Oversee your employee operations',
                            primaryTeal,
                            Color(0xFF00695C),
                            Icons.supervisor_account,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const EmployeeManagementScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Area Assignments',
                            Icons.map,
                            'Manage area assignments and history',
                            primaryOrange,
                            Color(0xFFF57C00),
                            Icons.assignment_ind,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AreaAssignmentHistoryScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Area Inspections',
                            Icons.assignment_turned_in,
                            'View area inspection status and reports',
                            primaryGreen,
                            Color(0xFF388E3C),
                            Icons.fact_check,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AreaInspectionStatusScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Work Reports',
                            Icons.description,
                            'View work reports from freelancers',
                            primaryCyan,
                            Color(0xFF0097A7),
                            Icons.analytics,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>  CreatePremiseScreen(),
                                ),
                              );
                            },
                          ),
                          _buildDashboardCard(
                            context,
                            'Task Management',
                            Icons.task,
                            'Manage and track tasks',
                            Color(0xFFE91E63),
                            Color(0xFFC2185B),
                            Icons.checklist,
                                () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TaskManagementScreen(),
                                ),
                              );
                            },
                          ),
                        ]),
                      ),
                    ),
                    // Add some bottom padding for the floating chat
                    SliverPadding(
                      padding: EdgeInsets.only(bottom: 100),
                    ),
                  ],
                ),
              ),
              const BillboardFooter(),
            ],
          ),
          // Floating chatbot positioned at bottom right
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const FloatingChat(userRole: 'contractor'),
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
      String description,
      Color primaryColor,
      Color secondaryColor,
      IconData accentIcon,
      VoidCallback onTap,
      ) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Card(
      elevation: 8,
      shadowColor: primaryColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                secondaryColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background accent icon
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: Icon(
                    accentIcon,
                    size: 60,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 20.0 : 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: isSmallScreen ? 32 : 36,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 10),
                    Flexible(
                      child: Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 12 : 16),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explore',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFreelancerOptions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ViewFreelancersScreen(),
      ),
    );
  }
}