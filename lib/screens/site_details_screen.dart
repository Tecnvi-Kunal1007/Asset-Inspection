import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/site.dart';
import '../utils/responsive_helper.dart';

class SiteDetailsScreen extends StatefulWidget {
  final Site site;
  final List<String> assignedSections;

  const SiteDetailsScreen({super.key, required this.site, required this.assignedSections});

  @override
  State<SiteDetailsScreen> createState() => _SiteDetailsScreenState();
}

class _SiteDetailsScreenState extends State<SiteDetailsScreen> {
  late TextEditingController _siteNameController;
  late TextEditingController _siteLocationController;
  late TextEditingController _descriptionController;
  late TextEditingController _accessoryController;
  late TextEditingController _fireAlarmController;

  @override
  void initState() {
    super.initState();
    _siteNameController = TextEditingController(text: widget.site.siteName);
    _siteLocationController = TextEditingController(text: widget.site.siteLocation);
    _descriptionController = TextEditingController(text: widget.site.description);
    _accessoryController = TextEditingController();
    _fireAlarmController = TextEditingController();
  }

  @override
  void dispose() {
    _siteNameController.dispose();
    _siteLocationController.dispose();
    _descriptionController.dispose();
    _accessoryController.dispose();
    _fireAlarmController.dispose();
    super.dispose();
  }

  Widget _infoTile(String title, String subtitle, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Site Details', style: GoogleFonts.poppins()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Site Information Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.business, color: Colors.blue, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Site Information',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 20),
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _infoTile('Site Name', widget.site.siteName, Icons.business),
                    _infoTile('Location', widget.site.siteLocation, Icons.location_city),
                    if (widget.site.description.isNotEmpty)
                      _infoTile('Description', widget.site.description, Icons.description),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Contact Information Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.contacts, color: Colors.blue, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Contact Information',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 20),
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _infoTile('Site Owner', widget.site.siteOwner, Icons.person),
                    _infoTile('Owner Email', widget.site.siteOwnerEmail, Icons.email),
                    _infoTile('Owner Phone', widget.site.siteOwnerPhone, Icons.phone),
                    const SizedBox(height: 10),
                    _infoTile('Site Manager', widget.site.siteManager, Icons.person_outline),
                    _infoTile('Manager Email', widget.site.siteManagerEmail, Icons.email_outlined),
                    _infoTile('Manager Phone', widget.site.siteManagerPhone, Icons.phone_outlined),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),

            // Floor Management Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.layers, color: Colors.blue, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Floor Management',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 18),
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Manage building floors and their components here.',
                      style: GoogleFonts.poppins(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement floor management navigation
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Floor management coming soon')),
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: Text('Add Floor', style: GoogleFonts.poppins()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Accessories Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.build, color: Colors.blue, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Building Accessories',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 18),
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _accessoryController,
                      decoration: InputDecoration(
                        hintText: 'Enter accessory details',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Implement save accessory logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Accessory saved!')),
                        );
                        _accessoryController.clear();
                      },
                      child: Text('Save Accessory', style: GoogleFonts.poppins()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Fire Alarm Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.alarm, color: Colors.blue, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Fire Alarm Management',
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveHelper.getFontSize(context, 18),
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _fireAlarmController,
                      decoration: InputDecoration(
                        hintText: 'Enter fire alarm details',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Implement save fire alarm logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fire alarm saved!')),
                        );
                        _fireAlarmController.clear();
                      },
                      child: Text('Save Fire Alarm', style: GoogleFonts.poppins()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    );
  }
}
