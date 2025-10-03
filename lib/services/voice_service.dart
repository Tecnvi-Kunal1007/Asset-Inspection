import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VoiceService {
  // API configuration
  late String _openAIKey;
  final String _openAIBaseUrl = 'https://api.openai.com/v1';
  
  // Speech recognition (Whisper)
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  String _recordingPath = '';
  bool _isRecording = false;
  Timer? _recognitionTimer;
  
  // Text-to-speech
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  
  // Streams for communication
  final _commandController = StreamController<String>.broadcast();
  final _responseController = StreamController<String>.broadcast();
  final _transcriptionController = StreamController<String>.broadcast();
  
  Stream<String> get commandStream => _commandController.stream;
  Stream<String> get responseStream => _responseController.stream;
  Stream<String> get transcriptionStream => _transcriptionController.stream;
  
  bool _isConnected = false;
  bool _isProcessing = false;
  
  VoiceService();
  
  Future<bool> initialize() async {
    try {
      // Load API key from environment - prioritize dart-define for web builds
      if (kIsWeb) {
        _openAIKey = const String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
        if (_openAIKey.isEmpty) {
          _openAIKey = dotenv.env['OPENAI_API_KEY'] ?? '';
        }
      } else {
        _openAIKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      }
      
      if (_openAIKey.isEmpty) {
        debugPrint('OpenAI API key not found in .env file');
        _isConnected = false;
        return false;
      }

      // Test the API connection
      final response = await http.get(
        Uri.parse('$_openAIBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_openAIKey',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('Successfully connected to OpenAI API');
        _isConnected = true;
        
        // Initialize recorder and player
        await _requestPermissions();
        await _recorder.openRecorder();
        await _player.openPlayer();
        
        // Set up temp directory for recordings
        final tempDir = await getTemporaryDirectory();
        _recordingPath = '${tempDir.path}/recording.wav';
        
        return true;
      } else {
        debugPrint('Failed to connect to OpenAI API: ${response.statusCode}');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      debugPrint('Error initializing voice service: $e');
      _isConnected = false;
      return false;
    }
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
    
    if (!_isConnected) {
      final initialized = await initialize();
      if (!initialized) {
        _commandController.add('Error initializing voice service. Please check your API key.');
        return;
      }
    }
    
    try {
      _isRecording = true;
      _commandController.add('Listening for voice commands...');
      
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
      _commandController.add('Error starting voice recognition: $e');
    }
  }
  
  // Stop speech recognition
  Future<void> stopListening() async {
    if (!_isRecording) return;
    
    _recognitionTimer?.cancel();
    _recognitionTimer = null;
    _commandController.add('Stopped listening for voice commands.');
    
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
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_openAIBaseUrl/audio/transcriptions'),
      );
      
      request.headers['Authorization'] = 'Bearer $_openAIKey';
      request.fields['model'] = 'whisper-1';
      request.fields['language'] = 'en';
      
      request.files.add(
        http.MultipartFile(
          'file',
          audioFile.readAsBytes().asStream(),
          await audioFile.length(),
          filename: 'audio.wav',
        ),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transcription = data['text'] as String;
        
        if (transcription.isNotEmpty) {
          _transcriptionController.add(transcription);
          // Process the transcribed command
          processCommand(transcription);
        }
      } else {
        debugPrint('Whisper API error: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error processing audio: $e');
    }
  }
  
  // Text-to-speech using OpenAI TTS
// Text-to-speech using OpenAI TTS
Future<void> textToSpeech(String text) async {
  if (!_isConnected) {
    final initialized = await initialize();
    if (!initialized) {
      _responseController.add('Error connecting to OpenAI API. Please check your API key.');
      return;
    }
  }
  
  try {
    final response = await http.post(
      Uri.parse('$_openAIBaseUrl/audio/speech'),
      headers: {
        'Authorization': 'Bearer $_openAIKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'tts-1',
        'input': text,
        'voice': 'alloy',
      }),
    );
    
    if (response.statusCode == 200) {
      final tempDir = await getTemporaryDirectory();
      final audioFile = File('${tempDir.path}/tts_output.mp3');
      await audioFile.writeAsBytes(response.bodyBytes);
      
      try {
        // Start playing the audio
        await _player.startPlayer(
          fromURI: audioFile.path,
          codec: Codec.mp3,
        );
        
        // Use a simple time-based approach that scales with text length
        // Average speech rate is about 150 words per minute or ~2.5 words per second
        // This approximates ~400ms per character for comfortable speech
        int estimatedDuration = (text.length * 100).clamp(2000, 60000);
        debugPrint('Estimated audio duration: ${estimatedDuration}ms');
        
        // Wait for estimated duration plus a small buffer
        await Future.delayed(Duration(milliseconds: estimatedDuration));
        
      } catch (e) {
        debugPrint('Player error: $e');
        _responseController.add('Error playing audio: $e');
      }
    } else {
      debugPrint('TTS API error: ${response.body}');
      _responseController.add('Error generating speech');
    }
  } catch (e) {
    debugPrint('TTS error: $e');
    _responseController.add('Error converting text to speech: $e');
  }
}
  

  Future<void> processCommand(String command) async {
    if (_isProcessing) {
      _responseController.add('Still processing previous command, please wait...');
      return;
    }

    if (!_isConnected) {
      final initialized = await initialize();
      if (!initialized) {
        _responseController.add('Error connecting to OpenAI API. Please check your API key.');
        return;
      }
    }

    _isProcessing = true;
    _commandController.add('Processing command: $command');

    try {
      final response = await http.post(
        Uri.parse('$_openAIBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_openAIKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': _getSystemPrompt(),
            },
            {
              'role': 'user',
              'content': command,
            },
          ],
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final content = responseData['choices'][0]['message']['content'];
        
        try {
          final parsedResponse = jsonDecode(content);
          final botReply = parsedResponse['reply'] ?? 'Sorry, I couldn\'t process that correctly.';
          
          _responseController.add(botReply);
          await textToSpeech(botReply);
          
          // Return the full parsed response for action processing
          return parsedResponse;
        } catch (e) {
          debugPrint('Error parsing JSON response: $e');
          _responseController.add(content);
          await textToSpeech(content);
        }
      } else {
        throw Exception('OpenAI API error: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      debugPrint('Error processing command: $e');
      final errorMsg = 'Sorry, I encountered an error processing your command. Please try again.';
      _responseController.add(errorMsg);
      await textToSpeech(errorMsg);
    } finally {
      _isProcessing = false;
    }
    
    return null;
  }

  // Process user input and get response with specific context
  Future<AIResponse> processUserInput(Map<String, dynamic> context) async {
    if (!_isConnected) {
      final initialized = await initialize();
      if (!initialized) {
        return AIResponse(
          botReply: 'Error connecting to OpenAI API. Please check your API key.',
          nextAction: 'repeat',
          fieldUpdates: {},
        );
      }
    }
    
    try {
      final response = await http.post(
        Uri.parse('$_openAIBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_openAIKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': _getSystemPrompt(),
            },
            {
              'role': 'user',
              'content': jsonEncode({
                'context': context,
                'current_step': context['current_step'],
                'user_input': context['user_input'],
              }),
            },
          ],
          'response_format': {'type': 'json_object'},
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        final parsedResponse = jsonDecode(content);
        
        final botReply = parsedResponse['reply'] ?? 'I couldn\'t process that. Let\'s try again.';
        await textToSpeech(botReply);
        
        return AIResponse(
          botReply: botReply,
          nextAction: parsedResponse['next_action'] ?? 'continue',
          fieldUpdates: Map<String, String>.from(parsedResponse['field_updates'] ?? {}),
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
        botReply: 'I\'m having trouble understanding. Can you please repeat that?',
        nextAction: 'repeat',
        fieldUpdates: {},
      );
    }
  }
  
  // Generate greeting message
  Future<String> generateGreeting(Map<String, dynamic> context) async {
    try {
      final response = await http.post(
        Uri.parse('$_openAIBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_openAIKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': 'Generate a friendly greeting for a building maintenance app. Introduce yourself and explain that we\'ll be updating various settings one by one. The greeting should be brief, professional, and welcoming.',
            },
            {
              'role': 'user',
              'content': jsonEncode(context),
            },
          ],
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final greeting = data['choices'][0]['message']['content'];
        await textToSpeech(greeting);
        return greeting;
      } else {
        final defaultGreeting = 'Welcome to the building maintenance voice assistant. Let\'s update the settings.';
        await textToSpeech(defaultGreeting);
        return defaultGreeting;
      }
    } catch (e) {
      final defaultGreeting = 'Welcome to the building maintenance voice assistant. Let\'s update the settings.';
      await textToSpeech(defaultGreeting);
      return defaultGreeting;
    }
  }
  
  // Generate field-specific question
  Future<String> generateFieldQuestion(Map<String, dynamic> context) async {
    try {
      final response = await http.post(
        Uri.parse('$_openAIBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_openAIKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': 'Generate a clear, concise question about updating a specific field. Mention the current value and ask if the user wants to update it. Keep the question brief and direct.',
            },
            {
              'role': 'user',
              'content': jsonEncode(context),
            },
          ],
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final question = data['choices'][0]['message']['content'];
        await textToSpeech(question);
        return question;
      } else {
        final defaultQuestion = _getDefaultQuestion(context['current_field'], context['current_value']);
        await textToSpeech(defaultQuestion);
        return defaultQuestion;
      }
    } catch (e) {
      final defaultQuestion = _getDefaultQuestion(context['current_field'], context['current_value']);
      await textToSpeech(defaultQuestion);
      return defaultQuestion;
    }
  }
  
  // Generate conversation summary
  Future<String> generateSummary(Map<String, dynamic> context) async {
    try {
      final response = await http.post(
        Uri.parse('$_openAIBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_openAIKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'system',
              'content': 'Generate a brief summary of the update session. Summarize the current settings that were updated. Keep it conversational and professional.',
            },
            {
              'role': 'user',
              'content': jsonEncode(context),
            },
          ],
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final summary = data['choices'][0]['message']['content'];
        await textToSpeech(summary);
        return summary;
      } else {
        final defaultSummary = 'Thank you for updating the settings for ${context['pump_name']}. All changes have been saved.';
        await textToSpeech(defaultSummary);
        return defaultSummary;
      }
    } catch (e) {
      final defaultSummary = 'Thank you for updating the settings for ${context['pump_name']}. All changes have been saved.';
      await textToSpeech(defaultSummary);
      return defaultSummary;
    }
  }
  
  // Send a text message to OpenAI and stream the response
  Future<void> sendMessage(String message) async {
    if (!_isConnected) {
      final initialized = await initialize();
      if (!initialized) {
        _responseController.add('Error connecting to OpenAI API. Please check your API key.');
        return;
      }
    }

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_openAIBaseUrl/chat/completions'),
      );
      
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_openAIKey',
      });
      
      request.body = jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'system',
            'content': 'You are a helpful assistant for a pump management system.',
          },
          {'role': 'user', 'content': message},
        ],
        'stream': true,
      });

      final streamedResponse = await http.Client().send(request);
      String fullResponse = '';

      if (streamedResponse.statusCode == 200) {
        streamedResponse.stream.listen((data) {
          final stringData = utf8.decode(data);
          for (final line in stringData.split('\n')) {
            if (line.startsWith('data: ') && line != 'data: [DONE]') {
              try {
                final dataJson = line.substring(6);
                if (dataJson.trim().isNotEmpty) {
                  final json = jsonDecode(dataJson);
                  final content = json['choices'][0]['delta']['content'];
                  if (content != null) {
                    _responseController.add(content);
                    fullResponse += content;
                  }
                }
              } catch (e) {
                // Skip lines that don't contain valid JSON
              }
            }
          }
        }, onDone: () {
          debugPrint('Stream response completed');
          if (fullResponse.isNotEmpty) {
            textToSpeech(fullResponse);
          }
        }, onError: (e) {
          debugPrint('Error in stream: $e');
          _responseController.add('Error receiving response from API.');
        });
      } else {
        throw Exception('Failed to connect to OpenAI API: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      _responseController.add('Error communicating with OpenAI API: $e');
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
    _commandController.close();
    _responseController.close();
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