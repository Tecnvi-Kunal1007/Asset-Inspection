import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';
import '../utils/theme_helper.dart';

class PremiseReportScreen extends StatefulWidget {
  final String premiseId;

  const PremiseReportScreen({Key? key, required this.premiseId}) : super(key: key);

  @override
  State<PremiseReportScreen> createState() => _PremiseReportScreenState();
}

class _PremiseReportScreenState extends State<PremiseReportScreen> {
  bool _isGenerating = false;
  String? _errorMessage;
  bool _reportGenerated = false;

  Future<void> _generateReport() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _reportGenerated = false;
    });

    try {
      final supabaseService = SupabaseService();
      final pdfService = PdfService();

      // Show progress
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fetching premise data...'),
          duration: Duration(seconds: 2),
        ),
      );

      final data = await supabaseService.fetchPremiseData(widget.premiseId);
      
      // Update progress
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating PDF report...'),
          duration: Duration(seconds: 2),
        ),
      );

      await pdfService.generatePremiseReport(data);
      
      setState(() {
        _reportGenerated = true;
      });

      // Show success message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Report generated successfully! Check your share options.'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate report: ${e.toString()}';
      });
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Premise Report",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ThemeHelper.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThemeHelper.primaryBlue.withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _reportGenerated ? Icons.check_circle : Icons.description,
                  size: 80,
                  color: _reportGenerated ? Colors.green : Colors.teal,
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                _reportGenerated 
                    ? 'Report Generated Successfully!' 
                    : 'Generate Premise Report',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: ThemeHelper.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Description
              Text(
                _reportGenerated
                    ? 'Your premise inspection report has been generated and is ready to share.'
                    : 'Generate a comprehensive report containing all premise details, sections, subsections, and products.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: ThemeHelper.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Generate Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isGenerating ? null : _generateReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _reportGenerated ? Colors.green : Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: _isGenerating
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Generating Report...',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _reportGenerated ? Icons.refresh : Icons.picture_as_pdf,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _reportGenerated ? 'Generate Again' : 'Generate Report',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              if (_reportGenerated) ...[
                const SizedBox(height: 16),
                Text(
                  'The report has been shared using your device\'s sharing options.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: ThemeHelper.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
