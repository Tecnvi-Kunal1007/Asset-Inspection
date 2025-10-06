import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pump_management_system/screens/premises_screen.dart';
import 'package:pump_management_system/screens/task_management_screen.dart';
import 'package:pump_management_system/screens/view_freelancers_screen.dart';
import 'package:pump_management_system/screens/work_reports_screen.dart';
import 'package:pump_management_system/screens/login_page.dart';
import 'QrScannerScreen.dart';
import 'assignment_overview_screen.dart';
import '../widgets/floating_chat.dart';

// import 'area_inspection_status_screen.dart'; // Screen doesn't exist
import 'employee_management_screen.dart';
// import 'product_management_screen.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'call_screen.dart';
import 'call_options_screen.dart';
import 'premises_screen.dart';
import 'dart:math' as math;

class ContractorDashboardScreen extends StatefulWidget {
  const ContractorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<ContractorDashboardScreen> createState() =>
      _ContractorDashboardScreenState();
}

class _ContractorDashboardScreenState extends State<ContractorDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _videoCallAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _videoCallPulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _videoCallAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _videoCallPulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _videoCallAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
    _videoCallAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoCallAnimationController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1F2937),
          ),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: const Color(0xFF6B7280),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Logout failed: $e',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFFFF6B6B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _startVideoCall() {
    print('Video call button tapped - opening call options');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            print('Building CallOptionsScreen with channel: team_meeting');
            return const CallOptionsScreen(
              channelName: 'team_meeting',
            );
          },
        ),
      );
      print('Navigation to CallOptionsScreen initiated');
    } catch (e) {
      print('Error navigating to CallOptionsScreen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, const Color(0xFFF8F9FA)],
          ),
        ),
        child: Stack(
          children: [
            // Animated particle background
            _buildParticleBackground(),

            // Floating geometric shapes
            _buildFloatingShapes(screenWidth, screenHeight),

            // Main content
            SafeArea(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: _buildModernDashboard(screenWidth, screenHeight),
                    ),
                  );
                },
              ),
            ),

            // Floating Chat
            Positioned(
              bottom: 20,
              right: 20,
              child: const FloatingChat(userRole: 'contractor'),
            ),

            // Floating Video Call Button
            Positioned(
              bottom: 90, // Position above the chat button
              right: 20,
              child: AnimatedBuilder(
                animation: _videoCallPulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _videoCallPulseAnimation.value,
                    child: GestureDetector(
                      onTap: _startVideoCall,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF25D366),
                              const Color(0xFF25D366).withOpacity(0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: const Color(0xFF25D366).withOpacity(0.2),
                              blurRadius: 40,
                              spreadRadius: 0,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.videocam,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  );
                },
              ).animate()
                  .fadeIn(duration: 800.ms, delay: 1200.ms)
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .shimmer(
                duration: 3000.ms,
                delay: 2000.ms,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticleBackground() {
    return Stack(
      children: List.generate(10, (index) {
        return Positioned(
          left: math.Random().nextDouble() * 400,
          top: math.Random().nextDouble() * 800,
          child: TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 4000 + (index * 300)),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(
                  math.sin(value * 2 * math.pi) * 15,
                  math.cos(value * 2 * math.pi) * 10,
                ),
                child: Container(
                  width: 2 + (index % 2),
                  height: 2 + (index % 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF667eea).withValues(alpha: 0.1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withValues(alpha: 0.05),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildFloatingShapes(double screenWidth, double screenHeight) {
    return Stack(
      children: [
        // Large floating circle
        Positioned(
          top: screenHeight * 0.15,
          right: -80,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withValues(alpha: 0.05),
                  const Color(0xFF667eea).withValues(alpha: 0.02),
                ],
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
            duration: 5000.ms,
            begin: const Offset(0.9, 0.9),
            end: const Offset(1.1, 1.1),
          )
              .then()
              .scale(
            duration: 5000.ms,
            begin: const Offset(1.1, 1.1),
            end: const Offset(0.9, 0.9),
          ),
        ),

        // Medium floating square
        Positioned(
          bottom: screenHeight * 0.25,
          left: -40,
          child: Transform.rotate(
            angle: math.pi / 6,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6B6B).withValues(alpha: 0.04),
                    const Color(0xFFFF8E53).withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 10000.ms),
        ),
      ],
    );
  }

  Widget _buildModernDashboard(double screenWidth, double screenHeight) {
    return CustomScrollView(
      slivers: [
        // Modern App Bar with Logout Button
        SliverAppBar(
          expandedHeight: 180,
          floating: false,
          pinned: true,
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [],
          leading: Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: GestureDetector(
              onTap: _logout,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667eea),
                      const Color(0xFF764ba2),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 600.ms, delay: 200.ms)
                .scale(duration: 800.ms, curve: Curves.elasticOut),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF667eea), const Color(0xFF764ba2)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                child: _buildDashboardHeader(),
              ),
            ),
          ),
        ),

        // Dashboard Content
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildQuickStats(),
              const SizedBox(height: 25),
              _buildDashboardGrid(screenWidth),
              const SizedBox(height: 100), // Space for floating buttons
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardHeader() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo with glow effect
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.3),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.dashboard_customize,
              size: 40,
              color: Colors.white,
            ),
          )
              .animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(
            duration: 2000.ms,
            color: Colors.white.withValues(alpha: 0.5),
          ),

          const SizedBox(height: 16),

          // Title with gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFE0E7FF)],
            ).createShader(bounds),
            child: Text(
              'Contractor Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(height: 8),

          Text(
            'Manage your construction projects',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 400.ms)
              .slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Overview',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
              _buildStatRow(
                'Active Premises',
                '8',
                Icons.business,
                const Color(0xFF667eea),
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                'Total Employees',
                '24',
                Icons.people,
                const Color(0xFFFF6B6B),
              ),
              const SizedBox(height: 12),
              _buildStatRow(
                'Ongoing Tasks',
                '15',
                Icons.task_alt,
                const Color(0xFF4ECDC4),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 600.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildStatRow(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid(double screenWidth) {
    final isTablet = screenWidth > 600;
    final crossAxisCount = isTablet ? 2 : 1;

    final dashboardItems = [
      DashboardItem(
        title: 'Manage Premises',
        subtitle: 'Track and manage all premises',
        icon: Icons.business,
        color: const Color(0xFF667eea),
        onTap: () {
          showModalBottomSheet(
            context: context,
            builder: (_) {
              return SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add_business),
                      title: const Text('Create Premise'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreatePremiseScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.qr_code_scanner),
                      title: const Text('Scan Premise'),
                      onTap: () async {
                        Navigator.pop(context);
                        final code = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QrScannerScreen(
                              onScan: (String scannedData) {
                                onQrScanned(context, scannedData);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      DashboardItem(
        title: 'Manage Employees',
        subtitle: 'Handle your workforce',
        icon: Icons.people,
        color: const Color(0xFFFF6B6B),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ViewFreelancersScreen()),
        ),
      ),
      DashboardItem(
        title: 'Task Management',
        subtitle: 'Organize and track tasks',
        icon: Icons.task_alt,
        color: const Color(0xFF4ECDC4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const  TaskManagementScreen()),
        ),
      ),
      DashboardItem(
        title: 'Assignment Overview',
        subtitle: 'Manage premise assignments',
        icon: Icons.assignment_ind,
        color: const Color(0xFF9C27B0),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AssignmentOverviewScreen(),
          ),
        ),
      ),
      DashboardItem(
        title: 'Work Reports',
        subtitle: 'View detailed reports',
        icon: Icons.assessment,
        color: const Color(0xFF45B7D1),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WorkReportsScreen()),
        ),
      ),
      DashboardItem(
        title: 'Employee Management',
        subtitle: 'Manage your team',
        icon: Icons.group,
        color: const Color(0xFF96CEB4),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EmployeeManagementScreen(),
          ),
        ),
      ),
      // DashboardItem(
      //   title: 'Product Management',
      //   subtitle: 'AI-powered inventory system',
      //   icon: Icons.inventory_2_rounded,
      //   color: const Color(0xFF9C27B0),
      //   onTap:
      //       () => Navigator.push(
      //         context,
      //         MaterialPageRoute(
      //           builder: (_) => const ProductManagementScreen(),
      //         ),
      //       ),
      // ),
      DashboardItem(
        title: 'Product Management',
        subtitle: 'AI-powered inventory system',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF9C27B0),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProductManagementScreen(),
              ),
            ),
      ),
      DashboardItem(
        title: 'Inspection Status',
        subtitle: 'Track inspection progress',
        icon: Icons.checklist,
        color: const Color(0xFFFF8E53),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feature coming soon!')),
          );
        },
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: dashboardItems.length,
      itemBuilder: (context, index) {
        final item = dashboardItems[index];
        return _buildDashboardCard(item, index);
      },
    );
  }

  Widget _buildDashboardCard(DashboardItem item, int index) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.color,
                        item.color.withValues(alpha: 0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withValues(alpha: 0.3),
                        blurRadius: 15,
                        spreadRadius: 0,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(item.icon, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  item.title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
      duration: 600.ms,
      delay: Duration(milliseconds: 800 + (index * 100)),
    )
        .slideY(begin: 0.3, end: 0)
        .shimmer(
      duration: 2000.ms,
      delay: Duration(milliseconds: 1500 + (index * 200)),
    );
  }
}

class DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}