import 'dart:async';
import 'package:flutter/material.dart';
import '../services/openai_service.dart';

class VoiceChatScreen extends StatefulWidget {
  final String itemId;
  final String siteId;
  final String itemName;

  const VoiceChatScreen({
    super.key,
    required this.itemId,
    required this.siteId,
    required this.itemName,
  });

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  final List<ChatMessage> _chatMessages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isListening = false;
  bool _botSpeaking = false;
  late OpenAIService _openAIService;
  String _currentStep = 'greeting'; // Track the current conversation step

  // Timer for auto-listening resumption
  Timer? _listeningTimer;

  // Queue for conversation steps
  final List<String> _updateQueue = [
    'status',
    'summary',
  ];
  int _currentQueueIndex = 0;

  @override
  void initState() {
    super.initState();
    _openAIService = OpenAIService();
    _initServices();
    _startConversation();
  }

  @override
  void dispose() {
    _textController.dispose();
    _listeningTimer?.cancel();
    _openAIService.dispose();
    super.dispose();
  }

  Future<void> _initServices() async {
    await _openAIService.initialize();

    // Set up OpenAI service listeners
    _openAIService.transcriptionStream.listen((transcription) {
      if (transcription.isNotEmpty) {
        _processUserInput(transcription);
      }
    });
  }

  void _startConversation() async {
    // Prepare context information for the AI
    final context = {
      'item_name': widget.itemName,
    };

    String welcomeMessage = await _openAIService.generateGreeting(context);

    _addMessage(ChatMessage(text: welcomeMessage, isUser: false));

    await _speakBotMessage(welcomeMessage);
    _startListening();
  }

  Future<void> _speakBotMessage(String message) async {
    setState(() {
      _botSpeaking = true;
    });

    try {
      await _openAIService.textToSpeech(message);
    } catch (e) {
      print('TTS Error: $e');
    } finally {
      setState(() {
        _botSpeaking = false;
      });
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _chatMessages.add(message);
    });
  }

  void _startListening() {
    if (_isListening) return;

    setState(() {
      _isListening = true;
    });

    _openAIService.startListening();

    // Auto-stop listening after 10 seconds of no input
    _listeningTimer?.cancel();
    _listeningTimer = Timer(const Duration(seconds: 10), () {
      _stopListening();
      _proceedToNextStep('timeout');
    });
  }

  void _stopListening() {
    if (!_isListening) return;

    _listeningTimer?.cancel();

    setState(() {
      _isListening = false;
    });

    _openAIService.stopListening();
  }

  void _processUserInput(String userInput) async {
    _stopListening();

    _addMessage(ChatMessage(text: userInput, isUser: true));

    // Prepare context for AI response
    final context = {
      'item_name': widget.itemName,
      'current_step': _currentStep,
      'user_input': userInput,
    };

    // Process user input and get response
    final response = await _openAIService.processUserInput(context);

    _addMessage(ChatMessage(text: response.botReply, isUser: false));

    await _speakBotMessage(response.botReply);

    // Determine next step based on AI response
    _proceedToNextStep(response.nextAction);
  }

  void _proceedToNextStep(String action) {
    if (action == 'continue' || action == 'timeout') {
      // Continue with next field in queue
      if (_currentQueueIndex < _updateQueue.length) {
        _currentStep = _updateQueue[_currentQueueIndex];
        _currentQueueIndex++;
        _askNextQuestion();
      } else {
        // Conversation complete
        _finishConversation();
      }
    } else if (action == 'skip') {
      // Skip current field
      if (_currentQueueIndex < _updateQueue.length) {
        _currentStep = _updateQueue[_currentQueueIndex];
        _currentQueueIndex++;
        _askNextQuestion();
      }
    } else if (action == 'repeat') {
      // Stay on current field, ask again
      _askNextQuestion();
    } else if (action == 'exit') {
      // Exit conversation
      _finishConversation();
      Navigator.of(context).pop();
    }
  }

  Future<void> _askNextQuestion() async {
    // Generate question for current step
    final context = {
      'item_name': widget.itemName,
      'current_field': _currentStep,
    };

    String question = await _openAIService.generateFieldQuestion(context);

    _addMessage(ChatMessage(text: question, isUser: false));

    await _speakBotMessage(question);
    _startListening();
  }

  void _finishConversation() async {
    // Generate summary
    final context = {
      'item_name': widget.itemName,
    };

    String summary = await _openAIService.generateSummary(context);

    _addMessage(ChatMessage(text: summary, isUser: false));

    await _speakBotMessage(summary);
  }

  void _sendTextMessage() {
    String message = _textController.text.trim();
    if (message.isEmpty) return;

    _textController.clear();
    _processUserInput(message);
  }

  Widget _buildChatBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isUser ? Colors.blue[200] : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message.text,
        style: TextStyle(color: message.isUser ? Colors.white : Colors.black),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice Chat - ${widget.itemName}'),
        actions: [
          IconButton(
            icon: Icon(_isListening ? Icons.mic : Icons.mic_off),
            color: _isListening ? Colors.green : Colors.red,
            onPressed: () {
              if (_isListening) {
                _stopListening();
              } else {
                _startListening();
              }
              setState(() {});
            },
            tooltip: _isListening ? 'Stop Listening' : 'Start Listening',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop();
            },
            tooltip: 'Exit Chat',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _chatMessages.length,
                itemBuilder: (context, index) {
                  return _buildChatBubble(_chatMessages[index]);
                },
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type your message here...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendTextMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _sendTextMessage,
                  child: const Text('Send'),
                ),
              ],
            ),
            if (_botSpeaking || _isListening)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_botSpeaking)
                      const Text(
                        'Speaking... ',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    if (_isListening)
                      const Text(
                        'Listening... ',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.green,
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
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
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
