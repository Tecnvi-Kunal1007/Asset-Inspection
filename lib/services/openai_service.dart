import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class EnhancedOpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  late String _apiKey;
  bool _isInitialized = false;
  static const int _maxRetries = 3;

  EnhancedOpenAIService() {
    _initialize();
  }

  void _initialize() {
    try {
      if (kIsWeb) {
        _apiKey = const String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
        if (_apiKey.isEmpty) {
          _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
        }
      } else {
        _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      }

      if (_apiKey.isEmpty) {
        debugPrint('OpenAI API key not found in .env file');
        _isInitialized = false;
      } else {
        _isInitialized = true;
        debugPrint('Enhanced OpenAI service initialized successfully');
      }
    } catch (e) {
      debugPrint('Error initializing Enhanced OpenAI service: $e');
      _isInitialized = false;
    }
  }

  Future<String> summarizeReportImproved(String reportData, {String model = 'gpt-3.5-turbo', int retries = _maxRetries}) async {
    if (!_isInitialized) {
      throw Exception('OpenAI service not initialized. Please check your API key configuration.');
    }

    if (reportData.isEmpty) {
      throw Exception('No data provided for summarization');
    }

    // Verify model availability
    final availableModels = await getAvailableModels();
    if (!availableModels.contains(model)) {
      debugPrint('Model $model not available. Falling back to gpt-3.5-turbo.');
      model = 'gpt-3.5-turbo';
    }

    for (int attempt = 1; attempt <= retries; attempt++) {
      try {
        debugPrint('Sending improved request to OpenAI API with model $model (attempt $attempt)...');
        debugPrint('Report data length: ${reportData.length} characters');

        final dataAnalysis = analyzeInspectionData(reportData);
        debugPrint('Data analysis: $dataAnalysis');

        final response = await http.post(
          Uri.parse('$_baseUrl/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content': '''You are an expert asset inspection analyst. Create a summary in the following paragraph format with 2-3 lines each, matching the exact structure below. Infer logical sections and subsections if data is limited. If the input data contains JSON, extract and summarize the specific data stored in the JSON structure (e.g., section names, subsection details, item counts, conditions, etc.) within the appropriate sections of the summary.

[Premise Summary]
[First line: Location and purpose inferred from JSON or text.]
[Second line: Management and efficiency based on JSON data or inference.]
[Third line: Condition and facilities derived from JSON or text.]

[Section Analysis]
[First line: List of main sections from JSON 'sections' array or text.]
[Second line: Condition of first section based on JSON 'condition' or inferred.]
[Third line: Condition of second section based on JSON 'condition' or inferred.]

[Subsection Analysis]
[First line: List of subsections from JSON 'subsections' array or text.]
[Second line: Condition of first subsection based on JSON 'condition' or inferred.]
[Third line: Condition of second subsection based on JSON 'condition' or inferred.]

[Products Analysis]
[First line: Total items and categories from JSON 'items' array or text.]
[Second line: Functionality and condition from JSON 'functionality' or inferred.]
[Third line: Repairs and maintenance needs from JSON 'repairs' or inferred.]

FORMATTING RULES:
1. Use EXACT headers in square brackets: [Premise Summary], [Section Analysis], etc.
2. Each paragraph must have exactly 3 lines.
3. Replace generic text with specific analysis from the data, prioritizing JSON data if present.
4. If data is limited or no JSON is provided, make reasonable inferences from text.'''
              },
              {
                'role': 'user',
                'content': '''Analyze this inspection data and create a detailed summary in the specified paragraph format.

Data to analyze:
$reportData

Additional context: This is inspection data that may contain various sections, items, or areas, potentially in JSON format with fields like 'sections', 'subsections', 'items', 'condition', 'functionality', and 'repairs'.'''
              }
            ],
            'max_tokens': 3000,
            'temperature': 0.2,
            'top_p': 0.95,
          }),
        );

        debugPrint('OpenAI API response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['choices'] != null && data['choices'].isNotEmpty) {
            final summary = data['choices'][0]['message']['content'] as String;

            if (summary.trim().isEmpty) {
              throw Exception('OpenAI returned an empty summary');
            }

            final validation = _validateEnhancedSummaryStructure(summary);
            if (!validation['isValid']) {
              debugPrint('Warning: ${validation['issues']}');
            }

            debugPrint('Summary generated successfully with $model, length: ${summary.length} characters');
            return summary.trim();
          } else {
            throw Exception('Invalid response format from OpenAI API');
          }
        } else {
          final errorBody = response.body;
          debugPrint('OpenAI API error response: $errorBody');
          if (attempt < retries) {
            await Future.delayed(Duration(seconds: attempt * 2));
            continue;
          }
          throw Exception('OpenAI API request failed with status ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error in improved summarizeReport with $model (attempt $attempt): $e');
        if (attempt < retries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        rethrow;
      }
    }
    throw Exception('Max retries exceeded for summarization with $model');
  }

  Map<String, dynamic> _validateEnhancedSummaryStructure(String summary) {
    final result = {'isValid': true, 'issues': <String>[]};

    final requiredSections = [
      '[Premise Summary]',
      '[Section Analysis]',
      '[Subsection Analysis]',
      '[Products Analysis]',
    ];

    final issues = <String>[];

    for (final section in requiredSections) {
      if (!summary.contains(section)) {
        issues.add('Missing: $section');
      }
    }

    if (issues.isNotEmpty) {
      result['isValid'] = false;
      result['issues'] = issues.join(', ');
    }

    return result;
  }

  String generateSampleSummary({String theme = 'default'}) {
    final baseSummary = '''[Premise Summary]
The Technogreen Society is located in Bangalore and serves as a community hub.
It is managed by Shivdash Singh, ensuring operational efficiency.
The overall condition is satisfactory with essential facilities.

[Section Analysis]
The report includes two main sections: Grocery Section and Office Area.
The Grocery Section is well-organized with functional refrigeration units.
The Office Area provides modern workspace with reliable internet connectivity.

[Subsection Analysis]
Subsections include Refrigeration Area and Storage Area under Grocery Section.
The Refrigeration Area maintains proper temperatures with no issues.
The Storage Area has minor shelving repairs needed.

[Products Analysis]
The premise has 15 inspected items across various categories.
Most items are in good condition with 87% functionality.
Minor repairs and replacements are needed for some equipment.''';

    if (theme == 'dark') {
      return baseSummary.replaceAll('satisfactory', 'excellent (dark theme enhanced)');
    }
    return baseSummary;
  }

  Future<bool> testConnection() async {
    if (!_isInitialized) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Enhanced OpenAI connection test failed: $e');
      return false;
    }
  }

  Future<List<String>> getAvailableModels() async {
    if (!_isInitialized) {
      throw Exception('Enhanced OpenAI service not initialized');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['data'] as List;
        return models.map((model) => model['id'] as String).toList();
      } else {
        throw Exception('Failed to fetch models: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching models: $e');
      rethrow;
    }
  }

  Map<String, dynamic> analyzeInspectionData(String reportData) {
    try {
      final analysis = <String, dynamic>{
        'totalSections': 0,
        'totalSubsections': 0,
        'totalItems': 0,
        'sections': <String>[],
        'complexity': 'Simple',
      };

      try {
        final jsonData = jsonDecode(reportData);
        if (jsonData is Map<String, dynamic>) {
          if (jsonData.containsKey('sections')) {
            final sections = jsonData['sections'] as List?;
            analysis['totalSections'] = sections?.length ?? 0;
            analysis['sections'] = sections?.map((s) => s['name']?.toString() ?? 'Unnamed').toList() ?? [];

            int subsectionCount = 0;
            int itemCount = 0;
            for (final section in sections ?? []) {
              if (section['subsections'] != null) {
                final subsections = section['subsections'] as List;
                subsectionCount += subsections.length;
                for (final subsection in subsections) {
                  if (subsection['items'] != null) {
                    itemCount += (subsection['items'] as List).length;
                  }
                }
              }
            }
            analysis['totalSubsections'] = subsectionCount;
            analysis['totalItems'] = itemCount;
          }
        }
      } catch (e) {
        final sectionMatches = RegExp(r'(SECTION:|Section:|AREA:|Area:)\s*([^\n]+)', caseSensitive: false).allMatches(reportData);
        analysis['totalSections'] = sectionMatches.length;
        analysis['sections'] = sectionMatches.map((m) => m.group(2)?.trim() ?? 'Unnamed').toList();
        analysis['complexity'] = reportData.length > 2000 ? 'Complex' : 'Simple';
      }

      final total = (analysis['totalSections'] as int) + (analysis['totalSubsections'] as int);
      if (total > 10) {
        analysis['complexity'] = 'Complex';
      } else if (total > 5) {
        analysis['complexity'] = 'Moderate';
      }

      debugPrint('Data analysis: $analysis');
      return analysis;
    } catch (e) {
      debugPrint('Error analyzing inspection data: $e');
      return {'totalSections': 1, 'totalSubsections': 1, 'totalItems': 1, 'complexity': 'Simple'};
    }
  }

  bool get isInitialized => _isInitialized;
}