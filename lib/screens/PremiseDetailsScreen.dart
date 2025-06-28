import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pump_management_system/screens/premise_product_screen.dart';
import '../models/premise.dart';
import '../models/subsection_product.dart';
import '../models/section.dart';
import '../models/subsection.dart';
import '../utils/responsive_helper.dart';
import '../utils/theme_helper.dart';
import 'create_section_screen.dart';
import 'subsection_selection_screen.dart';
import 'create_subsection_product_screen.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import '../services/supabase_service.dart';

class PremiseDetailsScreen extends StatefulWidget {
  final Premise premise;
  final Section? section;
  final Subsection? subsection;
  final Product? product;

  const PremiseDetailsScreen({
    super.key,
    required this.premise,
    this.section,
    this.subsection,
    this.product,
  });

  @override
  State<PremiseDetailsScreen> createState() => _PremiseDetailsScreenState();
}

class _PremiseDetailsScreenState extends State<PremiseDetailsScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  MobileScannerController? controller;
  String? scannedData;
  bool _isGeneratingQr = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    controller = MobileScannerController();
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      setState(() {
        scannedData = barcode.rawValue;
      });
      controller?.stop();
      _showScanResultDialog();
    }
  }

  void _showScanResultDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Scan Result'),
        content: Text(scannedData ?? 'No data scanned'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller?.start();
            },
            child: Text('Close'),
          ),
          if (scannedData != null)
            TextButton(
              onPressed: () {
                // Add share logic here (e.g., using share_plus package)
                Navigator.pop(context);
                controller?.start();
              },
              child: Text('Share'),
            ),
        ],
      ),
    );
  }

  Future<void> _downloadQrCode(String qrUrl) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) throw Exception('Storage directory not found');
      
      // Use premise name in the filename for better identification
      final sanitizedName = widget.premise.name.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
      final filePath = '${directory.path}/${sanitizedName}_QR_${DateTime.now().millisecondsSinceEpoch}.png';
      
      final response = await http.get(Uri.parse(qrUrl));
      if (response.statusCode == 200) {
        await File(filePath).writeAsBytes(response.bodyBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR code for ${widget.premise.name} downloaded successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                // You could add file viewing functionality here if needed
              },
            ),
          ),
        );
      } else {
        throw Exception('Failed to download QR code');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading QR code: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _generateQrCode() async {
    final supabaseService = SupabaseService();
    
    setState(() {
      _isGeneratingQr = true;
    });
    
    try {
      // Show a loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating QR code...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Call the regenerateQrCode method from SupabaseService
      final qrUrl = await supabaseService.regenerateQrCode(widget.premise.id);
      
      // Since we can't modify widget.premise directly, we'll refresh the screen
      setState(() {
        _isGeneratingQr = false;
      });
      
      // Force a rebuild of the screen to reflect the updated QR URL
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PremiseDetailsScreen(
            premise: widget.premise.copyWith(qrUrl: qrUrl),
            section: widget.section,
            subsection: widget.subsection,
            product: widget.product,
          ),
        ),
      );
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR code for ${widget.premise.name} generated successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() {
        _isGeneratingQr = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating QR code: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ThemeHelper.primaryBlue,
        title: Text(
          widget.premise.name,
          style: GoogleFonts.poppins(
            fontSize: ResponsiveHelper.getFontSize(context, 20),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: ThemeHelper.blueGradient),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit feature coming soon!')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewCard(),
              const SizedBox(height: 20),
              _buildHierarchyCard(),
              const SizedBox(height: 20),
              _buildManagementSection(),
              const SizedBox(height: 20),
              _buildDetailsCard(),
              const SizedBox(height: 20),
              // Scanner Section
              if (widget.premise.qr_Url != null && widget.premise.qr_Url!.isNotEmpty && widget.premise.qr_Url != 'pending')
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan QR Code',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: ThemeHelper.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 300,
                          child: Stack(
                            children: [
                              MobileScanner(
                                controller: controller,
                                onDetect: _onDetect,
                              ),
                              // Custom overlay
                              Container(
                                color: Colors.black.withOpacity(0.5),
                                child: Center(
                                  child: ClipPath(
                                    clipper: ScannerOverlayClipper(
                                      borderColor: ThemeHelper.primaryBlue,
                                      borderRadius: 10,
                                      borderLength: 30,
                                      borderWidth: 5,
                                      cutoutSize: 250,
                                    ),
                                    child: Container(
                                      height: 250,
                                      width: 250,
                                      color: Colors.transparent,
                                    ),
                                  ),
                                ),
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
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ThemeHelper.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.business,
                    color: ThemeHelper.primaryBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.premise.name,
                        style: GoogleFonts.poppins(
                          fontSize: ResponsiveHelper.getFontSize(context, 28),
                          fontWeight: FontWeight.w700,
                          color: ThemeHelper.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 16,
                            color: ThemeHelper.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'by ${widget.premise.contractorName}',
                            style: GoogleFonts.poppins(
                              fontSize: ResponsiveHelper.getFontSize(context, 16),
                              fontWeight: FontWeight.w500,
                              color: ThemeHelper.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (widget.premise.additionalData['location'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: ThemeHelper.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.premise.additionalData['location'].toString(),
                              style: GoogleFonts.poppins(
                                fontSize: ResponsiveHelper.getFontSize(context, 14),
                                color: ThemeHelper.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // QR Code Section - Always show this section, but with different content based on QR availability
                ...[
                  if (widget.premise.qr_Url != null && widget.premise.qr_Url!.isNotEmpty && widget.premise.qr_Url != 'pending')
                    Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ThemeHelper.primaryBlue.withOpacity(0.3), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              children: [
                                Image.network(
                                  widget.premise.qr_Url!,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                      valueColor: AlwaysStoppedAnimation<Color>(ThemeHelper.primaryBlue),
                                    ));
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Error loading QR code: $error');
                                    print('QR URL: ${widget.premise.qr_Url}');
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.qr_code_2, size: 40, color: Colors.grey),
                                        const SizedBox(height: 4),
                                        Text(
                                          'QR Error',
                                          style: TextStyle(fontSize: 10, color: Colors.grey),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: ThemeHelper.primaryBlue,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.qr_code_scanner,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeHelper.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          onPressed: () => _downloadQrCode(widget.premise.qr_Url!),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_2, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text(
                                  'No QR Code',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: _isGeneratingQr 
                            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                            : const Icon(Icons.refresh, size: 18),
                          label: Text(_isGeneratingQr ? 'Generating...' : 'Generate QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isGeneratingQr ? Colors.grey.shade400 : Colors.grey.shade300,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          onPressed: _isGeneratingQr ? null : () => _generateQrCode(),
                        ),
                      ],
                    ),
                ],
              ],
            ),
            // QR Code Info Banner - Show if QR is available
            if (widget.premise.qr_Url != null && widget.premise.qr_Url!.isNotEmpty && widget.premise.qr_Url != 'pending') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.qr_code_scanner, color: Colors.green.shade700, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'QR Code Available',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This premise has a QR code that includes its name and ID. Scan it for quick access or download it for offline use.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_tree,
                  color: ThemeHelper.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Structure Overview',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  _buildHierarchyItem(
                    icon: Icons.business,
                    title: 'Premise',
                    subtitle: 'Main building or property',
                    example: 'Office Building, Mall, Warehouse',
                    isActive: true,
                  ),
                  _buildHierarchyArrow(),
                  _buildHierarchyItem(
                    icon: Icons.layers,
                    title: 'Sections',
                    subtitle: 'Major divisions within premise',
                    example: 'Floors, Wings, Parking Areas',
                  ),
                  _buildHierarchyArrow(),
                  _buildHierarchyItem(
                    icon: Icons.room,
                    title: 'Subsections',
                    subtitle: 'Specific areas within sections',
                    example: 'Rooms, Shops, Office Spaces',
                  ),
                  _buildHierarchyArrow(),
                  _buildHierarchyItem(
                    icon: Icons.inventory,
                    title: 'Products',
                    subtitle: 'Items or devices in subsections',
                    example: 'Furniture, Equipment, Assets',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String example,
    bool isActive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? ThemeHelper.primaryBlue.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? ThemeHelper.primaryBlue : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? ThemeHelper.primaryBlue : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isActive ? ThemeHelper.primaryBlue : ThemeHelper.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: ThemeHelper.textSecondary,
                  ),
                ),
                Text(
                  'e.g., $example',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHierarchyArrow() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Icon(
        Icons.keyboard_arrow_down,
        color: ThemeHelper.primaryBlue,
        size: 24,
      ),
    );
  }

  Widget _buildManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Management Actions',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: ThemeHelper.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildActionButton(
                  context: context,
                  title: 'Create Section',
                  subtitle: 'Add floors, wings, or major areas',
                  icon: Icons.layers,
                  color: Colors.green,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateSectionScreen(
                        premise: widget.premise,
                        premiseId: widget.premise.id,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  context: context,
                  title: 'Create Premise Product',
                  subtitle: 'Add items, equipment, or assets',
                  icon: Icons.inventory,
                  color: Colors.purple,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreatePremiseProductScreen(
                          premise: widget.premise,
                          premiseId: widget.premise.id,
                          premiseName: widget.premise.name,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: ThemeHelper.textPrimary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: ThemeHelper.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    final additionalData = Map<String, dynamic>.from(widget.premise.additionalData);
    additionalData.remove('name');
    additionalData.remove('location');

    if (additionalData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Details',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: ThemeHelper.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: additionalData.entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ThemeHelper.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: ThemeHelper.primaryBlue,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key.toString().toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: ThemeHelper.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.value?.toString() ?? 'N/A',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: ThemeHelper.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.construction, color: Colors.orange),
              const SizedBox(width: 12),
              Text(
                'Coming Soon',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Text(
            '$feature functionality is currently under development and will be available soon!',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Got it',
                style: GoogleFonts.poppins(
                  color: ThemeHelper.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Custom clipper for the scanner overlay
class ScannerOverlayClipper extends CustomClipper<Path> {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutoutSize;

  ScannerOverlayClipper({
    required this.borderColor,
    this.borderRadius = 0,
    this.borderLength = 30,
    this.borderWidth = 5,
    this.cutoutSize = 200,
  });

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height)); // Full screen
    path.addRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: cutoutSize,
          height: cutoutSize,
        ),
        topLeft: Radius.circular(borderRadius),
        topRight: Radius.circular(borderRadius),
        bottomLeft: Radius.circular(borderRadius),
        bottomRight: Radius.circular(borderRadius),
      ),
    );
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}