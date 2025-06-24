import 'package:flutter/material.dart';
import '../models/pump.dart';
import '../services/supabase_service.dart';
import '../services/chatbot_service.dart';
import 'chat_screen.dart';
import 'pump_screen.dart'; // Import the PumpScreen
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PumpDetailsScreen extends StatefulWidget {
  final Pump pump;

  const PumpDetailsScreen({super.key, required this.pump});

  @override
  State<PumpDetailsScreen> createState() => _PumpDetailsScreenState();
}

class _PumpDetailsScreenState extends State<PumpDetailsScreen> {
  final _supabaseService = SupabaseService();
  final _chatbotService = ChatbotService();
  Pump? _updatedPump;

  @override
  Widget build(BuildContext context) {
    final pump = _updatedPump ?? widget.pump;
    final isWorking = pump.status.toLowerCase() == 'working';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                pump.name,
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
                    colors: [
                      isWorking ? Colors.green.shade700 : Colors.red.shade700,
                      isWorking ? Colors.green.shade500 : Colors.red.shade500,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      bottom: -50,
                      child: Icon(
                        Icons.settings,
                        size: 200,
                        color: Colors.white.withOpacity(0.2),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 40.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isWorking
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                pump.status,
                                style: GoogleFonts.poppins(
                                  color:
                                      isWorking
                                          ? Colors.green.shade900
                                          : Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chat, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (context) => ChatScreen(
                            pump: pump,
                            onPumpUpdated: (updatedPump) {
                              setState(() {
                                _updatedPump = updatedPump;
                              });
                            },
                          ),
                    ),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStaticInfo(pump),
                  const SizedBox(height: 24),
                  _buildDynamicInfo(pump),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticInfo(Pump pump) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Static Information',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue.shade700),
                    onPressed: () => _navigateToPumpScreen(pump),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoTile('Capacity', '${pump.capacity} LPM', Icons.speed),
              _buildInfoTile('Head', '${pump.head} meters', Icons.height),
              _buildInfoTile(
                'Rated Power',
                '${pump.ratedPower} kW',
                Icons.power,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildDynamicInfo(Pump pump) {
    final isWorking = pump.status.toLowerCase() == 'working';
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              isWorking ? Colors.green.shade50 : Colors.red.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dynamic Information',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                          isWorking
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      color:
                          isWorking
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                    ),
                    onPressed: () => _navigateToPumpScreen(pump),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatusTile('Status', pump.status, Icons.power_settings_new),
              _buildStatusTile('Mode', pump.mode, Icons.mode),
              _buildInfoTile(
                'Start Pressure',
                '${pump.startPressure} kg/cm²',
                Icons.arrow_upward,
              ),
              _buildInfoTile(
                'Stop Pressure',
                '${pump.stopPressure} kg/cm²',
                Icons.arrow_downward,
              ),
              _buildValveTile('Suction Valve', pump.suctionValve),
              _buildValveTile('Delivery Valve', pump.deliveryValve),
              _buildStatusTile(
                'Pressure Gauge',
                pump.pressureGauge,
                Icons.speed,
              ),
              _buildStatusTile(
                'Operational Status',
                pump.operationalStatus,
                Icons.engineering,
                isOperationalStatus: true,
              ),
              if (pump.comments != null && pump.comments!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCommentsTile(pump.comments!),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.message),
                  label: Text(
                    'Update via Chat',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isWorking ? Colors.green.shade100 : Colors.red.shade100,
                    foregroundColor:
                        isWorking ? Colors.green.shade700 : Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => ChatScreen(
                              pump: pump,
                              onPumpUpdated: (updatedPump) {
                                setState(() {
                                  _updatedPump = updatedPump;
                                });
                              },
                            ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().slideX();
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
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
                  ),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(
    String label,
    String value,
    IconData icon, {
    bool isOperationalStatus = false,
  }) {
    final isWorking =
        value.toLowerCase() == 'working' || value.toLowerCase() == 'operating';
    final isOpened = value.toLowerCase() == 'opened';
    final color = isWorking || isOpened ? Colors.green : Colors.red;
    final iconColor =
        isWorking || isOpened ? Colors.green.shade700 : Colors.red.shade700;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValveTile(String label, String status) {
    final isOpen = status.toLowerCase() == 'open';
    final color = isOpen ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isOpen ? Icons.alt_route : Icons.block,
                color: color.shade700,
                size: 20,
              ),
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
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsTile(String comments) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.comment, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Comments',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comments,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPumpScreen(Pump pump) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => PumpScreen(
              pumpId: pump.id,
              siteId: pump.siteId,
              onPumpUpdated: (updatedPump) {
                setState(() {
                  _updatedPump = updatedPump;
                });
              },
            ),
      ),
    );
  }
}
