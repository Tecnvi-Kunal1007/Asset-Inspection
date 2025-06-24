import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
import '../models/pump.dart';
import '../services/chatbot_service.dart';
import '../services/supabase_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatScreen extends StatefulWidget {
  final Pump pump;
  final Function(Pump) onPumpUpdated;

  const ChatScreen({
    super.key,
    required this.pump,
    required this.onPumpUpdated,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatbotService = ChatbotService();
  final _supabaseService = SupabaseService();
  final List<types.Message> _messages = [];
  final Uuid _uuid = const Uuid();
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  // Add user object for the chat
  final types.User _user = const types.User(id: 'user', firstName: 'User');

  // Add bot user object
  final types.User _bot = const types.User(
    id: 'bot',
    firstName: 'Pump Assistant',
  );

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _addWelcomeMessage() {
    final welcomeMessage = types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _uuid.v4(),
      text:
          '''Hello! 👋 I'm your pump management assistant. I can help you update the following information for ${widget.pump.name}:

📊 Status: Working/Not Working
🔄 Mode: Auto/Manual
⬆️ Start Pressure: in kg/cm²
⬇️ Stop Pressure: in kg/cm²
🔵 Suction Valve: Open/Closed
🔴 Delivery Valve: Open/Closed
📈 Pressure Gauge: Working/Not Working

What would you like to update?''',
    );

    setState(() {
      _messages.add(welcomeMessage);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _addThinkingMessage() {
    final typingMessage = types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _uuid.v4(),
      text: '🤔 Thinking...',
    );

    setState(() {
      _messages.add(typingMessage);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _removeLastMessage() {
    if (_messages.isNotEmpty) {
      setState(() {
        _messages.removeLast();
      });
    }
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    if (_isLoading) return;

    final userMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: _uuid.v4(),
      text: message.text,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    _addThinkingMessage();

    try {
      final result = await _chatbotService.processUserMessage(
        message.text,
        widget.pump,
      );
      final responseText = result['message'] as String;

      _removeLastMessage();

      if (result['updates'] != null) {
        final updates = result['updates'] as Map<String, dynamic>;
        if (updates.isNotEmpty) {
          final updatedPump = widget.pump.copyWith(
            status:
                updates.containsKey('status')
                    ? updates['status'] as String
                    : null,
            mode:
                updates.containsKey('mode') ? updates['mode'] as String : null,
            startPressure:
                updates.containsKey('start_pressure')
                    ? (updates['start_pressure'] as num).toDouble()
                    : null,
            stopPressure:
                updates.containsKey('stop_pressure')
                    ? updates['stop_pressure'] as String
                    : null,
            suctionValve:
                updates.containsKey('suction_valve')
                    ? updates['suction_valve'] as String
                    : null,
            deliveryValve:
                updates.containsKey('delivery_valve')
                    ? updates['delivery_valve'] as String
                    : null,
            pressureGauge:
                updates.containsKey('pressure_gauge')
                    ? updates['pressure_gauge'] as String
                    : null,
          );

          await _supabaseService.updatePump(updatedPump);
          widget.onPumpUpdated(updatedPump);
        }
      }

      final botResponse = types.TextMessage(
        author: _bot,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: _uuid.v4(),
        text: responseText,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(botResponse);
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      if (result['follow_up'] != null &&
          result['follow_up'].toString().isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 800), () {
          final followUpMessage = types.TextMessage(
            author: _bot,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: _uuid.v4(),
            text: result['follow_up'] as String,
          );
          if (!mounted) return;
          setState(() {
            _messages.add(followUpMessage);
          });
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToBottom(),
          );
        });
      }
    } catch (error) {
      _removeLastMessage();

      print('Error in chat: $error');
      final errorMessage = types.TextMessage(
        author: _bot,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: _uuid.v4(),
        text:
            '❌ Sorry, I encountered an error processing your request. Please try again or check your network connection.',
      );

      if (!mounted) return;
      setState(() {
        _messages.add(errorMessage);
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWorking = widget.pump.status.toLowerCase() == 'working';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  isWorking ? Colors.green.shade100 : Colors.red.shade100,
              child: Icon(
                Icons.settings,
                color: isWorking ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.pump.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Status: ${widget.pump.status}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color:
                        isWorking ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showPumpInfo(context),
          ),
        ],
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: false, // Messages will flow downwards
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.author.id == _user.id;

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isUser
                              ? (isWorking
                                  ? Colors.green.shade600
                                  : Colors.red.shade600)
                              : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isUser) ...[
                              CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                radius: 12,
                                child: Icon(
                                  Icons.smart_toy,
                                  color: Colors.blue.shade700,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              isUser ? 'You' : 'Pump Assistant',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    isUser
                                        ? Colors.white
                                        : Colors.grey.shade700,
                              ),
                            ),
                            if (isUser) ...[
                              const SizedBox(width: 8),
                              CircleAvatar(
                                backgroundColor: Colors.grey.shade200,
                                radius: 12,
                                child: Icon(
                                  Icons.person,
                                  color: Colors.grey.shade700,
                                  size: 16,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (message as types.TextMessage).text,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isUser ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        _handleSendPressed(
                          types.PartialText(text: text.trim()),
                        );
                        _textController.clear();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Type your message here...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey.shade500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color:
                              isWorking
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color:
                        isWorking ? Colors.green.shade600 : Colors.red.shade600,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded),
                    color: Colors.white,
                    onPressed: () {
                      final text = _textController.text.trim();
                      if (text.isNotEmpty) {
                        _handleSendPressed(types.PartialText(text: text));
                        _textController.clear();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPumpInfo(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.pump.name} Details',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoSection('Current Status'),
                  _buildInfoRow('Status', widget.pump.status),
                  _buildInfoRow('Mode', widget.pump.mode),
                  _buildInfoRow(
                    'Start Pressure',
                    '${widget.pump.startPressure} kg/cm²',
                  ),
                  _buildInfoRow('Stop Pressure', '${widget.pump.stopPressure}'),
                  _buildInfoRow('Suction Valve', widget.pump.suctionValve),
                  _buildInfoRow('Delivery Valve', widget.pump.deliveryValve),
                  _buildInfoRow('Pressure Gauge', widget.pump.pressureGauge),
                  const SizedBox(height: 20),
                  _buildInfoSection('Chat Commands Examples'),
                  _buildCommandExample('Change status to Working'),
                  _buildCommandExample('Set the mode to Auto'),
                  _buildCommandExample('Update start pressure to 5.5 kg/cm²'),
                  _buildCommandExample('Open suction valve'),
                  _buildCommandExample('Close delivery valve'),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildInfoSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Text(value, style: GoogleFonts.poppins(color: Colors.grey.shade900)),
        ],
      ),
    );
  }

  Widget _buildCommandExample(String command) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.arrow_right, size: 20, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Text(
            command,
            style: GoogleFonts.poppins(
              fontStyle: FontStyle.italic,
              color: Colors.blue.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
