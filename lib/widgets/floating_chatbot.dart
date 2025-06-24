import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FloatingChatbot extends StatefulWidget {
  final String userRole; // 'contractor' or 'site_manager'

  const FloatingChatbot({Key? key, required this.userRole}) : super(key: key);

  @override
  State<FloatingChatbot> createState() => _FloatingChatbotState();
}

class _FloatingChatbotState extends State<FloatingChatbot> {
  bool _isOpen = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;

  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Voice recording
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  String _recordingPath = '';
  Timer? _recognitionTimer;

  // OpenAI API
  late String _openAIKey;
  static const String _apiUrl = 'https://api.openai.com/v1';

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _recorder.closeRecorder();
    _player.closePlayer();
    _recognitionTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _openAIKey = dotenv.env['OPENAI_API_KEY'] ?? '';

    if (_openAIKey.isEmpty) {
      _addMessage(
        ChatMessage(
          text:
              'Error: OpenAI API key not found. Please check your configuration.',
          isUser: false,
          isError: true,
        ),
      );
      return;
    }

    try {
      await _requestPermissions();
      await _recorder.openRecorder();
      await _player.openPlayer();

      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/chatbot_recording.wav';
    } catch (e) {
      _addMessage(
        ChatMessage(
          text: 'Error initializing voice services: $e',
          isUser: false,
          isError: true,
        ),
      );
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }
  }

  void _addWelcomeMessage() {
    String welcomeMessage =
        'Hello! I\'m your ${widget.userRole.replaceAll('_', ' ')} assistant. How can I help you today?';
    _addMessage(ChatMessage(text: welcomeMessage, isUser: false));
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    _addMessage(ChatMessage(text: message, isUser: true));
    _textController.clear();

    setState(() {
      _isProcessing = true;
    });

    try {
      final response = await _getChatResponse(message);
      _addMessage(ChatMessage(text: response, isUser: false));

      // Convert response to speech
      await _textToSpeech(response);
    } catch (e) {
      _addMessage(
        ChatMessage(
          text: 'Sorry, I encountered an error. Please try again.',
          isUser: false,
          isError: true,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<String> _getChatResponse(String message) async {
    final prompt = _getSystemPrompt();

    final response = await http.post(
      Uri.parse('$_apiUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $_openAIKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {'role': 'system', 'content': prompt},
          {'role': 'user', 'content': message},
        ],
        'temperature': 0.7,
        'max_tokens': 500,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to get response: ${response.statusCode}');
    }
  }

  String _getSystemPrompt() {
    final role = widget.userRole.replaceAll('_', ' ');
    return '''
You are a helpful AI assistant for a pump management system. You are specifically helping a $role.

Your role is to:
1. Provide helpful information about pump management, site operations, and system features
2. Answer questions about the dashboard and available functions
3. Guide users through common tasks
4. Provide technical support and troubleshooting advice

Key areas you can help with:
- Site management and area assignments
- Pump operations and maintenance
- Inspection procedures and reports
- Task management and scheduling
- System navigation and features
- Technical issues and troubleshooting

Keep your responses concise, professional, and helpful. If you don't know something specific about the system, suggest where the user might find that information or ask for clarification.

Current user role: $role
''';
  }

  Future<void> _startListening() async {
    if (_isListening || _isProcessing) return;

    try {
      setState(() {
        _isListening = true;
      });

      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
      );

      _recognitionTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _processAudioChunk();
      });
    } catch (e) {
      setState(() {
        _isListening = false;
      });
      _addMessage(
        ChatMessage(
          text: 'Error starting voice recognition: $e',
          isUser: false,
          isError: true,
        ),
      );
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) return;

    _recognitionTimer?.cancel();
    _recognitionTimer = null;

    try {
      await _recorder.stopRecorder();
      setState(() {
        _isListening = false;
      });

      await _processAudioChunk();
    } catch (e) {
      setState(() {
        _isListening = false;
      });
    }
  }

  Future<void> _processAudioChunk() async {
    if (!File(_recordingPath).existsSync()) return;

    try {
      final audioFile = File(_recordingPath);
      if (await audioFile.length() == 0) return;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_apiUrl/audio/transcriptions'),
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
          await _sendMessage(transcription);
        }
      }
    } catch (e) {
      debugPrint('Error processing audio: $e');
    }
  }

  Future<void> _textToSpeech(String text) async {
    if (text.isEmpty) return;

    try {
      setState(() {
        _isSpeaking = true;
      });

      final response = await http.post(
        Uri.parse('$_apiUrl/audio/speech'),
        headers: {
          'Authorization': 'Bearer $_openAIKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'model': 'tts-1', 'input': text, 'voice': 'alloy'}),
      );

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final audioFile = File('${tempDir.path}/chatbot_tts.mp3');
        await audioFile.writeAsBytes(response.bodyBytes);

        await _player.startPlayer(fromURI: audioFile.path, codec: Codec.mp3);

        // Estimate duration based on text length
        final estimatedDuration = (text.length * 100).clamp(2000, 10000);
        await Future.delayed(Duration(milliseconds: estimatedDuration));
      }
    } catch (e) {
      debugPrint('TTS error: $e');
    } finally {
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
    });

    // Stop speaking when closing the chat
    if (!_isOpen && _isSpeaking) {
      _stopSpeaking();
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _player.stopPlayer();
    } catch (e) {
      debugPrint('Error stopping player: $e');
    } finally {
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    // Calculate responsive dimensions
    final chatWidth = screenSize.width < 400 ? screenSize.width * 0.9 : 350.0;
    final normalChatHeight =
        screenSize.height < 600 ? screenSize.height * 0.7 : 500.0;

    // When keyboard is open, use a fixed small height
    final chatHeight = isKeyboardOpen ? 250.0 : normalChatHeight;

    final rightOffset = screenSize.width < 400 ? 10.0 : 20.0;

    return Stack(
      children: [
        // Floating chat button
        Positioned(
          bottom: isKeyboardOpen ? keyboardHeight + 20 : 20,
          right: rightOffset,
          child: FloatingActionButton(
            onPressed: _toggleChat,
            backgroundColor: Colors.blue,
            child: Icon(
              _isOpen ? Icons.close : Icons.chat,
              color: Colors.white,
            ),
          ),
        ),

        // Chat dialog
        if (_isOpen)
          Positioned(
            bottom: isKeyboardOpen ? keyboardHeight + 20 : 80.0,
            right: rightOffset,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: chatWidth,
              height: chatHeight,
              constraints: BoxConstraints(
                maxWidth: screenSize.width * 0.95,
                maxHeight: chatHeight,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.smart_toy,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI Assistant',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isListening)
                          const Icon(Icons.mic, color: Colors.red, size: 20),
                        if (_isSpeaking)
                          const Icon(
                            Icons.volume_up,
                            color: Colors.white,
                            size: 20,
                          ),
                      ],
                    ),
                  ),

                  // Messages - Make scrollable when keyboard is open
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children:
                              _messages
                                  .map(
                                    (message) => _buildMessageBubble(message),
                                  )
                                  .toList(),
                        ),
                      ),
                    ),
                  ),

                  // Input area
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: 'Type your message...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onSubmitted: (text) => _sendMessage(text),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed:
                              _isListening ? _stopListening : _startListening,
                          icon: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: _isListening ? Colors.red : Colors.blue,
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _isProcessing
                                  ? null
                                  : () => _sendMessage(_textController.text),
                          icon: Icon(
                            Icons.send,
                            color: _isProcessing ? Colors.grey : Colors.blue,
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
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    message.isUser
                        ? Colors.blue
                        : message.isError
                        ? Colors.red[100]
                        : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color:
                      message.isUser
                          ? Colors.white
                          : message.isError
                          ? Colors.red[800]
                          : Colors.black87,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  ChatMessage({required this.text, required this.isUser, this.isError = false});
}
