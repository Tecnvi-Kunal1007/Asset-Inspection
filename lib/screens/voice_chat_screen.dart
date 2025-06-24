import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/pump_controller.dart';
import '../services/openai_service.dart';

class VoiceChatScreen extends StatefulWidget {
  final String pumpId;
  final String siteId;
  final String pumpName;

  const VoiceChatScreen({
    super.key,
    required this.pumpId,
    required this.siteId,
    required this.pumpName,
  });

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  late PumpController _pumpController;
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
    'mode',
    'start_pressure',
    'stop_pressure',
    'suction_valve',
    'delivery_valve',
    'pressure_gauge',
    'summary',
  ];
  int _currentQueueIndex = 0;

  @override
  void initState() {
    super.initState();
    _pumpController = PumpController(
      pumpId: widget.pumpId,
      siteId: widget.siteId,
    );
    _pumpController.addListener(_onPumpControllerChanged);

    _openAIService = OpenAIService();
    _initServices();
    _startConversation();
  }

  @override
  void dispose() {
    _pumpController.removeListener(_onPumpControllerChanged);
    _textController.dispose();
    _listeningTimer?.cancel();
    _openAIService.dispose();
    super.dispose();
  }

  void _onPumpControllerChanged() {
    setState(() {
      // Update UI when pump changes dynamically
    });
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
      'pump_name': widget.pumpName,
      'status': _pumpController.status,
      'mode': _pumpController.mode,
      'start_pressure': _pumpController.startPressure,
      'stop_pressure': _pumpController.stopPressure,
      'suction_valve': _pumpController.suctionValve,
      'delivery_valve': _pumpController.deliveryValve,
      'pressure_gauge': _pumpController.pressureGauge,
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
      'pump_name': widget.pumpName,
      'status': _pumpController.status,
      'mode': _pumpController.mode,
      'start_pressure': _pumpController.startPressure,
      'stop_pressure': _pumpController.stopPressure,
      'suction_valve': _pumpController.suctionValve,
      'delivery_valve': _pumpController.deliveryValve,
      'pressure_gauge': _pumpController.pressureGauge,
      'current_step': _currentStep,
      'user_input': userInput,
    };

    // Process user input and get response
    final response = await _openAIService.processUserInput(context);

    // Handle field updates based on AI response
    _updatePumpFields(response);

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
      'pump_name': widget.pumpName,
      'current_field': _currentStep,
      'current_value': _getCurrentFieldValue(),
    };

    String question = await _openAIService.generateFieldQuestion(context);

    _addMessage(ChatMessage(text: question, isUser: false));

    await _speakBotMessage(question);
    _startListening();
  }

  String _getCurrentFieldValue() {
    switch (_currentStep) {
      case 'status':
        return _pumpController.status;
      case 'mode':
        return _pumpController.mode;
      case 'start_pressure':
        return '${_pumpController.startPressure} kg/cm²';
      case 'stop_pressure':
        return _pumpController.stopPressure;
      case 'suction_valve':
        return _pumpController.suctionValve;
      case 'delivery_valve':
        return _pumpController.deliveryValve;
      case 'pressure_gauge':
        return _pumpController.pressureGauge;
      default:
        return '';
    }
  }

  void _updatePumpFields(AIResponse response) {
    // Update pump fields based on AI response
    if (response.fieldUpdates.containsKey('status')) {
      _pumpController.updateStatus(response.fieldUpdates['status']!);
    }

    if (response.fieldUpdates.containsKey('mode')) {
      _pumpController.updateMode(response.fieldUpdates['mode']!);
    }

    if (response.fieldUpdates.containsKey('start_pressure')) {
      try {
        final pressure = double.parse(response.fieldUpdates['start_pressure']!);
        _pumpController.updateStartPressure(pressure);
      } catch (e) {
        print('Error parsing start pressure: $e');
      }
    }

    if (response.fieldUpdates.containsKey('stop_pressure')) {
      _pumpController.updateStopPressure(
        response.fieldUpdates['stop_pressure']!,
      );
    }

    if (response.fieldUpdates.containsKey('suction_valve')) {
      _pumpController.updateSuctionValve(
        response.fieldUpdates['suction_valve']!,
      );
    }

    if (response.fieldUpdates.containsKey('delivery_valve')) {
      _pumpController.updateDeliveryValve(
        response.fieldUpdates['delivery_valve']!,
      );
    }

    if (response.fieldUpdates.containsKey('pressure_gauge')) {
      _pumpController.updatePressureGauge(
        response.fieldUpdates['pressure_gauge']!,
      );
    }
  }

  void _finishConversation() async {
    // Generate summary
    final context = {
      'pump_name': widget.pumpName,
      'status': _pumpController.status,
      'mode': _pumpController.mode,
      'start_pressure': _pumpController.startPressure,
      'stop_pressure': _pumpController.stopPressure,
      'suction_valve': _pumpController.suctionValve,
      'delivery_valve': _pumpController.deliveryValve,
      'pressure_gauge': _pumpController.pressureGauge,
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

  Widget _buildDynamicFieldDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Status: ${_pumpController.status}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'Mode: ${_pumpController.mode}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'Start Pressure: ${_pumpController.startPressure} kg/cm²',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'Stop Pressure: ${_pumpController.stopPressure}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'Suction Valve: ${_pumpController.suctionValve}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'Delivery Valve: ${_pumpController.deliveryValve}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          'Pressure Gauge: ${_pumpController.pressureGauge}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice Chat - ${widget.pumpName}'),
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
            _buildDynamicFieldDisplay(),
            const SizedBox(height: 12),
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
