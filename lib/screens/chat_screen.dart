import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';
// import '../models/pump.dart'; // Model doesn't exist
import '../services/chatbot_service.dart';
import '../services/supabase_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/chat_service.dart';
import '../models/chat_message.dart';
import '../services/location_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class ChatScreen extends StatefulWidget {
  // final Pump pump;
  // final Function(Pump) onPumpUpdated;

  const ChatScreen({
    super.key,
    // required this.pump,
    // required this.onPumpUpdated,
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
  final ImagePicker _imagePicker = ImagePicker();
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  File? _pendingAttachment;
  String? _pendingAttachmentType;
  String? _pendingAttachmentName;

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
          '''Hello! 👋 I'm your pump management assistant. I can help you update the following information for your equipment:

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
      // Create a system prompt for the chatbot
      final systemPrompt = '''
You are a helpful assistant for a building management system.
You're chatting with a user about their equipment.

Current settings:
- Status: Working
- Mode: Auto
- Start Pressure: 2.5 kg/cm²
- Stop Pressure: 4.0 kg/cm²
- Suction Valve: Open
- Delivery Valve: Open
- Pressure Gauge: Normal

Please respond naturally to the user's message.
''';

      final responseText = await _chatbotService.getChatResponse(
        message.text,
        systemPrompt,
      );

      _removeLastMessage();

      // For now, we're not updating any pump values
      // This would need to be reimplemented if pump functionality is needed again

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

  Future<void> _pickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _pendingAttachment = File(pickedFile.path);
        _pendingAttachmentType = 'image';
        _pendingAttachmentName = pickedFile.name;
      });
      _showAttachmentPreview(
        _pendingAttachment!,
        _pendingAttachmentType!,
        _pendingAttachmentName,
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pendingAttachment = File(result.files.first.path!);
        _pendingAttachmentType = 'document';
        _pendingAttachmentName = result.files.first.name;
      });
      _showAttachmentPreview(
        _pendingAttachment!,
        _pendingAttachmentType!,
        _pendingAttachmentName,
      );
    }
  }

  Future<void> _shareLocation() async {
    try {
      setState(() => _isSending = true);

      final locationHelper = LocationHelper();

      // Check if location is available and request permission if needed
      bool isAvailable = await locationHelper.isLocationAvailable();
      if (!isAvailable) {
        bool permissionGranted = await locationHelper.requestLocationPermission(
          context,
        );
        if (!permissionGranted) {
          // User denied permission, exit early
          setState(() => _isSending = false);
          return;
        }
      }

      // Get location link and address using the helper
      final locationLink = await locationHelper.generateLocationLink(context);
      final locationAddress = await locationHelper.getCurrentAddressSafely(
        context,
      );

      if (locationLink != null && locationAddress != null) {
        final locationMessage = '📍 Location: $locationAddress\n$locationLink';
        await _sendChatMessage(text: locationMessage);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing location: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to share location: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendChatMessage({
    String? text,
    File? attachment,
    String? attachmentType,
    String? attachmentName,
  }) async {
    setState(() => _isSending = true);
    try {
      // For demo, use dummy receiver (in real app, get from context)
      final receiverId = 'dummy_receiver';
      final receiverType = 'contractor';
      await _chatService.sendMessage(
        context: context,
        receiverId: receiverId,
        receiverType: receiverType,
        messageText: text,
        attachment: attachment,
        attachmentType: attachmentType,
        attachmentName: attachmentName,
      );
      // Optionally, add to _messages for instant UI update
      setState(() {
        if (text != null && text.isNotEmpty) {
          _messages.add(
            types.TextMessage(
              author: _user,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: _uuid.v4(),
              text: text,
            ),
          );
        }
        _pendingAttachment = null;
        _pendingAttachmentType = null;
        _pendingAttachmentName = null;
        _messageController.clear();
      });
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showAttachmentPreview(File file, String type, [String? fileName]) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Send ${type == 'image' ? 'Image' : 'File'}?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (type == 'image')
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.attach_file, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName ?? file.path.split('/').last,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Add a message (optional)...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _sendChatMessage(
                    text:
                        _messageController.text.trim().isEmpty
                            ? null
                            : _messageController.text.trim(),
                    attachment: file,
                    attachmentType: type,
                    attachmentName: fileName,
                  );
                  _messageController.clear();
                },
                child: const Text('Send'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWorking = true; // widget.pump.status.toLowerCase() == 'working';

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
                  'Equipment Chat',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Status: Working',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.green.shade700,
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
                // Display logic for attachments and location links
                if (message is types.TextMessage) {
                  final text = message.text;
                  if (text.startsWith('📍 Location:')) {
                    final urlMatch = RegExp(
                      r'(https?://[\w\./?=&%-]+)',
                    ).firstMatch(text);
                    final url = urlMatch != null ? urlMatch.group(0) : null;
                    return GestureDetector(
                      onTap:
                          url != null
                              ? () async {
                                try {
                                  final uri = Uri.parse(url);
                                  if (kDebugMode) {
                                    print('Attempting to launch URL: $url');
                                  }

                                  // First check if we can launch the URL
                                  if (await canLaunchUrl(uri)) {
                                    final launched = await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );

                                    if (!launched && context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not launch the map link',
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Could not launch the map link - URL cannot be handled',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (kDebugMode) {
                                    print('Error launching URL: $e');
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Error launching map: ${e.toString()}',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                              : null,
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
                        child: Column(
                          crossAxisAlignment:
                              isUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          children: [
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
                            const SizedBox(height: 4),
                            Text(
                              text,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: isUser ? Colors.white : Colors.black87,
                                decoration:
                                    url != null
                                        ? TextDecoration.underline
                                        : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                }
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
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  color: Colors.blue.shade700,
                ),
                IconButton(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.attach_file),
                  color: Colors.blue.shade700,
                ),
                IconButton(
                  onPressed: _shareLocation,
                  icon: const Icon(Icons.location_on),
                  color: Colors.blue.shade700,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: (text) {
                      if (text.trim().isNotEmpty) {
                        _sendChatMessage(text: text.trim());
                        _messageController.clear();
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
                    onPressed:
                        _isSending
                            ? null
                            : () {
                              final text = _messageController.text.trim();
                              if (text.isNotEmpty) {
                                _sendChatMessage(text: text);
                                _messageController.clear();
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
                    'Equipment Details',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoSection('Current Status'),
                  _buildInfoRow('Status', 'Working'),
                  _buildInfoRow('Mode', 'Auto'),
                  _buildInfoRow('Start Pressure', '2.5 kg/cm²'),
                  _buildInfoRow('Stop Pressure', '4.0 kg/cm²'),
                  _buildInfoRow('Suction Valve', 'Open'),
                  _buildInfoRow('Delivery Valve', 'Open'),
                  _buildInfoRow('Pressure Gauge', 'Normal'),
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
