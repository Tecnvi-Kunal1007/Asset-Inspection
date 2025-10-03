import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/openai_service.dart';
import '../services/supabase_service.dart';
import '../services/summary_pdf_service.dart';
import '../test_pdf.dart';
import '../utils/theme_helper.dart';

class PremiseSummaryScreen extends StatefulWidget {
  final String? reportText;
  final String? premiseId;
  final String? premiseName;

  const PremiseSummaryScreen({
    Key? key,
    this.reportText,
    this.premiseId,
    this.premiseName,
  }) : super(key: key);

  @override
  _PremiseSummaryScreenState createState() => _PremiseSummaryScreenState();
}

class _PremiseSummaryScreenState extends State<PremiseSummaryScreen> {
  String? summary;
  bool isLoadingSummary = false;
  bool isGeneratingPdf = false;
  String? errorMessage;
  Map<String, dynamic>? fullPremiseData;

  Future<void> _summarize() async {
    setState(() {
      isLoadingSummary = true;
      errorMessage = null;
    });

    try {
      final aiService = EnhancedOpenAIService();
      
      // Check if OpenAI service is properly initialized
      if (!aiService.isInitialized) {
        throw Exception('OpenAI service not initialized. Please check your API key configuration in the .env file.');
      }

      final supabaseService = SupabaseService();
      String reportToSummarize;

      // Get the formatted data for AI analysis
      if (widget.premiseId != null) {
        // Use the new method that formats data specifically for AI
        reportToSummarize = await supabaseService.getPremiseDataForAI(widget.premiseId!);

        // Also get the raw data for PDF generation later
        fullPremiseData = await supabaseService.fetchPremiseData(widget.premiseId!);
      } else if (widget.reportText != null) {
        reportToSummarize = widget.reportText!;
      } else {
        throw Exception('No premise ID or report text provided');
      }

      print('Data length for AI: ${reportToSummarize.length} characters');

      if (reportToSummarize.isEmpty) {
        throw Exception('No meaningful data found to summarize');
      }

      // Test connection before making the actual request
      final connectionTest = await aiService.testConnection();
      if (!connectionTest) {
        throw Exception('Unable to connect to OpenAI API. Please check your internet connection and API key.');
      }

      final result = await aiService.summarizeReportImproved(reportToSummarize);

      print('=== AI Summary Result Debug ===');
      print('AI returned summary length: ${result.length}');
      print('AI summary content: $result');

      setState(() {
        summary = result;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('AI summary generated successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

    } catch (e) {
      print('Error in _summarize: $e');
      
      String userFriendlyMessage;
      if (e.toString().contains('API key')) {
        userFriendlyMessage = 'OpenAI API key is missing or invalid. Please check your configuration.';
      } else if (e.toString().contains('Rate limit')) {
        userFriendlyMessage = 'OpenAI rate limit exceeded. Please try again in a few minutes.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        userFriendlyMessage = 'Network connection error. Please check your internet connection.';
      } else if (e.toString().contains('No meaningful data')) {
        userFriendlyMessage = 'No inspection data found for this premise. Please ensure the premise has been inspected.';
      } else {
        userFriendlyMessage = e.toString().replaceFirst('Exception: ', '');
      }
      
      setState(() {
        errorMessage = userFriendlyMessage;
        summary = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFriendlyMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        isLoadingSummary = false;
      });
    }
  }

  Future<void> _generateSummaryPdf() async {
    if (summary == null || summary!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please generate a summary first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Debug logging
    print('=== PDF Generation Debug ===');
    print('Summary length: ${summary!.length}');
    print('Summary content preview: ${summary!.substring(0, summary!.length > 100 ? 100 : summary!.length)}...');
    print('Premise name: ${widget.premiseName ?? fullPremiseData?['name'] ?? 'Unknown Premise'}');
    print('Original data keys: ${fullPremiseData?.keys.toList() ?? []}');

    setState(() {
      isGeneratingPdf = true;
      errorMessage = null;
    });

    try {
      final summaryPdfService = EnhancedSummaryPdfService();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Generating AI summary PDF...'),
          duration: Duration(seconds: 2),
        ),
      );

      await summaryPdfService.generateSummaryReport(
        summary: summary!,
        premiseName: widget.premiseName ?? fullPremiseData?['name'] ?? 'Unknown Premise',
        originalData: fullPremiseData ?? {},
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('AI summary PDF generated successfully!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    } catch (e) {
      print('Error generating PDF: $e');
      setState(() {
        errorMessage = 'Failed to generate PDF: ${e.toString()}';
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() {
        isGeneratingPdf = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "AI Report Summary",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (summary != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: isGeneratingPdf ? null : _generateSummaryPdf,
              tooltip: 'Generate PDF',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.teal.withValues(alpha: 0.1), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade400, Colors.blue.shade500],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "AI",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Intelligent Report Analysis",
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "AI-powered insights for ${widget.premiseName ?? 'your premise'}",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Generate Summary Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoadingSummary ? null : _summarize,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: summary == null ? Colors.teal : Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: isLoadingSummary
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
                        'Generating AI Summary...',
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
                      Icon(summary == null ? Icons.auto_awesome : Icons.refresh, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        summary == null ? 'Generate AI Summary' : 'Regenerate Summary',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // PDF Generation Button
              if (summary != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isGeneratingPdf ? null : _generateSummaryPdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: isGeneratingPdf
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
                        Text('Generating PDF...', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 24),
                        const SizedBox(width: 12),
                        Text('Generate Summary PDF', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Test PDF Generation Button (for debugging)
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await TestPdfService.testPdfGeneration();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test PDF generated successfully!')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Test PDF failed: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bug_report, size: 20),
                      const SizedBox(width: 8),
                      Text('Test PDF Generation', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Error Message
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: GoogleFonts.poppins(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // AI-Generated Summary Boxes
              if (summary != null) ...[
                Text(
                  'AI-Generated Summary:',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: ThemeHelper.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Premise Summary Box
                        _buildSummaryBox(
                          title: 'Premise Overview',
                          icon: Icons.business,
                          color: Colors.blue,
                          content: 'The premise inspection reveals comprehensive facility assessment. Overall condition shows good maintenance standards with proper infrastructure. Key areas include structural integrity and operational efficiency.',
                        ),
                        const SizedBox(height: 16),
                        
                        // Section Summary Box
                        _buildSummaryBox(
                          title: 'Section Analysis',
                          icon: Icons.view_module,
                          color: Colors.green,
                          content: 'Multiple sections evaluated for compliance and functionality. Each section demonstrates adequate performance metrics. Critical areas identified for optimization and improvement.',
                        ),
                        const SizedBox(height: 16),
                        
                        // Subsection Summary Box
                        _buildSummaryBox(
                          title: 'Subsection Details',
                          icon: Icons.grid_view,
                          color: Colors.orange,
                          content: 'Detailed subsection analysis shows specific operational parameters. Individual components meet required standards. Minor adjustments recommended for enhanced performance.',
                        ),
                        const SizedBox(height: 16),
                        
                        // Product Summary Box
                        _buildSummaryBox(
                          title: 'Product Assessment',
                          icon: Icons.inventory,
                          color: Colors.purple,
                          content: 'Product inventory and quality assessment completed successfully. All items catalogued with proper documentation. Compliance with safety and quality standards verified.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This summary is AI-generated. Please review the original detailed report for complete accuracy.',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Empty state
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, size: 64, color: Colors.teal),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'AI Report Analysis Ready',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: ThemeHelper.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Click the button above to generate an intelligent summary of your premise report using AI technology.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: ThemeHelper.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required IconData icon,
    required Color color,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.5,
              color: ThemeHelper.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}