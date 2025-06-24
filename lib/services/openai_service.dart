import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  final String _apiKey;
  static const String _apiUrl = 'https://api.openai.com/v1';

  // Speech recognition (Whisper)
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String _recordingPath = '';
  bool _isRecording = false;
  Timer? _recognitionTimer;

  // Text-to-speech
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  // Streams for communication
  final _transcriptionController = StreamController<String>.broadcast();
  Stream<String> get transcriptionStream => _transcriptionController.stream;

  OpenAIService() : _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

  Future<void> initialize() async {
    // Initialize recorder
    await _requestPermissions();
    await _recorder.openRecorder();

    // Initialize player
    await _player.openPlayer();

    // Set up temp directory for recordings
    final tempDir = await getTemporaryDirectory();
    _recordingPath = '${tempDir.path}/recording.wav';
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }
  }

  // Start speech recognition
  Future<void> startListening() async {
    if (_isRecording) return;

    try {
      _isRecording = true;
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
      );

      // Set up timer to process audio chunks every 2 seconds
      _recognitionTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _processAudioChunk();
      });
    } catch (e) {
      _isRecording = false;
      debugPrint('Error starting recorder: $e');
    }
  }

  // Stop speech recognition
  Future<void> stopListening() async {
    if (!_isRecording) return;

    _recognitionTimer?.cancel();
    _recognitionTimer = null;

    try {
      await _recorder.stopRecorder();
      _isRecording = false;

      // Process the final audio chunk
      await _processAudioChunk();
    } catch (e) {
      debugPrint('Error stopping recorder: $e');
    }
  }

  // Process recorded audio with Whisper API
  Future<void> _processAudioChunk() async {
    if (!_isRecording && !File(_recordingPath).existsSync()) return;

    try {
      final audioFile = File(_recordingPath);
      if (await audioFile.length() == 0) return;

      final uri = Uri.parse('$_apiUrl/audio/transcriptions');
      final request =
          http.MultipartRequest('POST', uri)
            ..headers['Authorization'] = 'Bearer ${this._apiKey}'
            ..fields['model'] = 'whisper-1'
            ..fields['language'] = 'en'
            ..files.add(
              await http.MultipartFile.fromPath('file', audioFile.path),
            );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode != 200) {
        throw Exception('Failed to transcribe audio: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcription = data['text'] as String;

        if (transcription.isNotEmpty) {
          _transcriptionController.add(transcription);
        }
      } else {
        debugPrint('Whisper API error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error processing audio: $e');
    }
  }

  // Text-to-speech using OpenAI TTS
  Future<void> textToSpeech(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/audio/speech'),
        headers: {
          'Authorization': 'Bearer ${this._apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'model': 'tts-1', 'input': text, 'voice': 'alloy'}),
      );

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final audioFile = File('${tempDir.path}/tts_output.mp3');
        await audioFile.writeAsBytes(response.bodyBytes);

        await _player.startPlayer(fromURI: audioFile.path, codec: Codec.mp3);

        // Wait for audio to finish playing
        await Future.delayed(
          Duration(milliseconds: 4000),
        ); // wait static 4 seconds to allow audio to finish playing
      } else {
        debugPrint('TTS API error: ${response.body}');
      }
    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  // Process user input and get response
  Future<AIResponse> processUserInput(Map<String, dynamic> context) async {
    try {
      // Check if this is a non-working components analysis request
      final isNonWorkingComponentsAnalysis = context.containsKey(
        'non_working_components',
      );

      debugPrint('Sending request to OpenAI API...');
      debugPrint('Context: ${jsonEncode(context)}');

      final response = await http.post(
        Uri.parse('$_apiUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${this._apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content':
                  isNonWorkingComponentsAnalysis
                      ? _getNonWorkingComponentsPrompt()
                      : _getSystemPrompt(),
            },
            {'role': 'user', 'content': jsonEncode(context)},
          ],
          'response_format': {'type': 'json_object'},
          'max_tokens':
              4000, // Increased token limit for more detailed responses
          'temperature': 0.7, // Added temperature for more creative responses
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        debugPrint('Raw API Response: $content');

        final parsedResponse = jsonDecode(content);
        debugPrint('Parsed Response: ${jsonEncode(parsedResponse)}');

        return AIResponse(
          botReply:
              parsedResponse['reply'] ??
              'I couldn\'t process that. Let\'s try again.',
          nextAction: parsedResponse['next_action'] ?? 'continue',
          fieldUpdates: Map<String, String>.from(
            parsedResponse['field_updates'] ?? {},
          ),
        );
      } else {
        debugPrint('Chat API error: ${response.body}');
        return AIResponse(
          botReply: 'Sorry, I encountered an error. Let\'s try again.',
          nextAction: 'repeat',
          fieldUpdates: {},
        );
      }
    } catch (e) {
      debugPrint('Processing error: $e');
      return AIResponse(
        botReply:
            'I\'m having trouble understanding. Can you please repeat that?',
        nextAction: 'repeat',
        fieldUpdates: {},
      );
    }
  }

  // Generate greeting message
  Future<String> generateGreeting(Map<String, dynamic> context) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${this._apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Generate a friendly greeting for a pump maintenance app. Introduce the pump by name and explain that we\'ll be updating various pump settings one by one. The greeting should be brief, professional, and welcoming.',
            },
            {'role': 'user', 'content': jsonEncode(context)},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return 'Welcome to the pump voice assistant. Let\'s update the settings for ${context['pump_name']}.';
      }
    } catch (e) {
      return 'Welcome to the pump voice assistant. Let\'s update the settings for ${context['pump_name']}.';
    }
  }

  // Generate field-specific question
  Future<String> generateFieldQuestion(Map<String, dynamic> context) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${this._apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Generate a clear, concise question about updating a specific field for a pump. Mention the current value and ask if the user wants to update it. Keep the question brief and direct.',
            },
            {'role': 'user', 'content': jsonEncode(context)},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return _getDefaultQuestion(
          context['current_field'],
          context['current_value'],
        );
      }
    } catch (e) {
      return _getDefaultQuestion(
        context['current_field'],
        context['current_value'],
      );
    }
  }

  // Generate conversation summary
  Future<String> generateSummary(Map<String, dynamic> context) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${this._apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Generate a brief summary of the pump update session. Mention the pump name and summarize the current settings that were updated. Keep it conversational and professional.',
            },
            {'role': 'user', 'content': jsonEncode(context)},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        return 'Thank you for updating the settings for ${context['pump_name']}. All changes have been saved.';
      }
    } catch (e) {
      return 'Thank you for updating the settings for ${context['pump_name']}. All changes have been saved.';
    }
  }

  String _getSystemPrompt() {
    return '''
    You are an AI assistant for a pump maintenance application. Your task is to help users update pump settings through a conversational interface.
    
    You will receive a JSON context with the following information:
    - pump_name: The name of the pump being updated
    - current_step: The current field being updated
    - user_input: What the user said
    - Current values for all pump fields: status, mode, start_pressure, stop_pressure, suction_valve, delivery_valve, pressure_gauge
    
    Based on the user input and context, you should:
    1. Determine if the user wants to update the current field
    2. Extract the new value for the field if applicable
    3. Format your response as a JSON object with three fields:
       - "reply": Your verbal response to the user (friendly, brief, and confirm any changes)
       - "next_action": One of ["continue", "skip", "repeat", "exit"]
       - "field_updates": A dictionary of field names and their new values
    
    Valid options for fields:
    - status: "Working" or "Not Working"
    - mode: "Auto" or "Manual"
    - start_pressure, stop_pressure: numeric values (e.g. "2.5")
    - suction_valve, delivery_valve: "Open" or "Closed"
    - pressure_gauge: "Working" or "Not Working"
    
    Example response format:
    {
      "reply": "I've updated the pump status to Working. The status is now set to Working.",
      "next_action": "continue",
      "field_updates": {
        "status": "Working"
      }
    }
    ''';
  }

  String _getNonWorkingComponentsPrompt() {
    return '''
    You are an expert maintenance analyst tasked with creating a comprehensive, narrative-style report about non-working components in a building maintenance system. Your goal is to tell a complete story about the maintenance situation that any reader can understand.

    You will receive a JSON context with:
    - non_working_components: List of components that are not working
    - area_name: Name of the area being analyzed
    - total_components: Total number of non-working components
    - sites_count: Number of sites in the area

    For each component in the list, you have access to:
    - Component type
    - Location
    - Status
    - Notes
    - Floor information (if available)
    - Site information

    Generate a detailed, narrative-style report that tells a complete story. Structure your response as follows:

    1. Introduction and Overview (2-3 paragraphs):
       - Begin with a clear introduction of the area and its maintenance situation
       - Provide a high-level overview of the maintenance challenges
       - Set the context for why this analysis is important
       - Mention the total number of non-working components and number of affected sites

    2. Site-by-Site Analysis (2-3 paragraphs per site):
       For each site:
       - Start with the site's name and location
       - Describe the overall condition of the site
       - Provide a detailed floor-by-floor breakdown:
         * What components are not working on each floor
         * How these issues affect the floor's functionality
         * Any patterns or clusters of issues
       - Include specific numbers and locations
       - Explain the impact of these issues on the site's operations

    3. Component Type Analysis (2-3 paragraphs):
       - Group and analyze components by type
       - For each major component type:
         * Total number not working
         * Distribution across floors and sites
         * Common issues or patterns
         * Impact on building systems
       - Include specific examples and locations

    4. Critical Issues and Safety Concerns (2-3 paragraphs):
       - Identify and prioritize critical issues
       - Explain why each issue is critical
       - Describe potential safety implications
       - Highlight any urgent maintenance needs

    5. Maintenance Impact Analysis (2-3 paragraphs):
       - Analyze how these issues affect daily operations
       - Describe the impact on building systems
       - Explain any cascading effects
       - Discuss potential risks if issues are not addressed

    6. Recommendations and Action Plan (2-3 paragraphs):
       - Provide a prioritized list of maintenance tasks
       - Suggest a maintenance schedule
       - Include specific recommendations for each type of issue
       - Explain the reasoning behind each recommendation

    7. Conclusion (1-2 paragraphs):
       - Summarize the key findings
       - Reinforce the importance of addressing these issues
       - Provide a clear call to action

    Format your response as a JSON object with:
    {
      "reply": "Your detailed, narrative-style report here",
      "next_action": "continue",
      "field_updates": {}
    }

    Important Guidelines:
    - Use a clear, professional tone
    - Include specific numbers, locations, and component types
    - Make the report engaging and easy to understand
    - Provide context and explanations for technical terms
    - Use examples and specific instances to illustrate points
    - Ensure the report tells a complete story from start to finish
    - Aim for a comprehensive analysis that covers all aspects of the maintenance situation
    - Make sure to analyze and mention every non-working component in the list
    - Provide detailed explanations for each issue and its implications

    The report should be thorough enough that someone reading it would have a complete understanding of:
    - What components are not working
    - Where they are located
    - Why they are important
    - What needs to be done
    - How urgent each issue is
    - What the impact is on the building's operations
    ''';
  }

  String _getDefaultQuestion(String field, String currentValue) {
    switch (field) {
      case 'status':
        return 'The current status is $currentValue. Would you like to change the status?';
      case 'mode':
        return 'The current mode is $currentValue. Would you like to update it?';
      case 'start_pressure':
        return 'The current start pressure is $currentValue. Do you want to change this value?';
      case 'stop_pressure':
        return 'The current stop pressure is $currentValue. Do you want to change this value?';
      case 'suction_valve':
        return 'The suction valve is currently $currentValue. Would you like to change it?';
      case 'delivery_valve':
        return 'The delivery valve is currently $currentValue. Would you like to change it?';
      case 'pressure_gauge':
        return 'The pressure gauge is currently $currentValue. Would you like to update its status?';
      case 'summary':
        return 'That completes all the updates. Is there anything else you\'d like to adjust?';
      default:
        return 'Would you like to update any other settings?';
    }
  }

  void dispose() {
    _transcriptionController.close();
    _recognitionTimer?.cancel();
    _recorder.closeRecorder();
    _player.closePlayer();
  }
}

class AIResponse {
  final String botReply;
  final String nextAction;
  final Map<String, String> fieldUpdates;

  AIResponse({
    required this.botReply,
    required this.nextAction,
    required this.fieldUpdates,
  });
}
