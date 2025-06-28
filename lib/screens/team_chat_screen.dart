import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import '../models/chat_message.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:typed_data';

// Import location helper
import '../services/location_helper.dart';

class TeamChatScreen extends StatefulWidget {
  final String userRole; // 'contractor' or 'freelancer'/'employee'
  final String? partnerId; // Optional, for direct conversation navigation
  final String? partnerName;
  final String? partnerRole;
  final String? partnerType;

  const TeamChatScreen({
    Key? key,
    required this.userRole,
    this.partnerId,
    this.partnerName,
    this.partnerRole,
    this.partnerType,
  }) : super(key: key);

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  final ChatService _chatService = ChatService();
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _teamMembers = [];
  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;
  bool _isConversationMode = false;
  String? _currentPartnerId;
  String? _currentPartnerName;
  String? _currentPartnerRole;
  String? _currentPartnerType;
  List<ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.partnerId != null) {
      _isConversationMode = true;
      _currentPartnerId = widget.partnerId;
      _currentPartnerName = widget.partnerName;
      _currentPartnerRole = widget.partnerRole;
      _currentPartnerType = widget.partnerType;
      _loadMessages();
      _markMessagesAsRead();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await _chatService.getCurrentUserInfo();
      if (_currentUser == null) throw Exception('User not authenticated');

      if (widget.userRole == 'contractor') {
        _teamMembers = await _chatService.getContractorTeam();
      } else {
        final contractor = await _chatService.getFreelancerContractor();
        _teamMembers = contractor != null ? [contractor] : [];
      }

      _conversations = await _chatService.getRecentConversations();
    } catch (e) {
      print('Error loading initial data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chat data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages() async {
    if (_currentPartnerId == null || _currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      final messages = await _chatService.getMessages(
        userId1: _currentUser!['id'],
        userId2: _currentPartnerId!,
      );
      print('Loaded ${messages.length} messages for ${_currentUser!['id']} and $_currentPartnerId');
      setState(() {
        _messages = messages.reversed.toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_currentPartnerId == null || _currentUser == null) return;
    try {
      await _chatService.markMessagesAsRead(
        senderId: _currentPartnerId!,
        receiverId: _currentUser!['id'],
      );
      print('Marked messages as read for ${_currentUser!['id']} from $_currentPartnerId');
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  void _scrollToBottom() {
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

  // Modified _sendMessage to handle location messages
  Future<void> _sendMessage({
    String? text,
    dynamic attachment,
    String? attachmentType,
    String? attachmentName,
    String? locationLink, // New parameter for location link
    String? locationAddress, required String messageType, // New parameter for location address
  }) async {
    if ((_currentPartnerId == null || _currentUser == null) ||
        ((text == null || text.trim().isEmpty) && attachment == null && locationLink == null)) return;

    setState(() => _isSending = true);
    try {
      final message = await _chatService.sendMessage(
        context: context,
        receiverId: _currentPartnerId!,
        receiverType: _currentPartnerType!,
        messageText: text?.trim(),
        attachment: attachment,
        attachmentType: attachmentType,
        attachmentName: attachmentName,
        locationLink: locationLink, // Pass new parameter
        locationAddress: locationAddress, // Pass new parameter
      );
      if (message != null) {
        print('Message sent: ${message.id} to $_currentPartnerId');
        setState(() {
          _messages.add(message);
          _messageController.clear();
        });
        _scrollToBottom();
      } else {
        print('Failed to send message, no result returned');
        throw Exception('Message send failed');
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // --- Location Sharing Logic ---
  Future<void> _shareCurrentLocation() async {
    try {
      // Use the LocationHelper class for better location handling
      final locationHelper = LocationHelper();
      
      // Check if location is available and request permission if needed
      bool isAvailable = await locationHelper.isLocationAvailable();
      if (!isAvailable) {
        bool permissionGranted = await locationHelper.requestLocationPermission(context);
        if (!permissionGranted) {
          // User denied permission, exit early
          return;
        }
      }

      // Get location link and address using the helper
      // Get location with enhanced error handling
final locationLink = await locationHelper.generateLocationLink(context)
  .onError((error, stackTrace) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Location error: ${error.toString()}'))
    );
    return null;
  });

if (locationLink != null) {
  final locationAddress = await locationHelper.getCurrentAddressSafely(context)
    ?? 'Shared Location';

  try {
    await _sendMessage(
      messageType: 'location',
      locationLink: locationLink,
      locationAddress: locationAddress,
      text: locationAddress,
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to send location: ${e.toString()}'))
    );
  }
}
      // No need for an else block as the LocationHelper already shows appropriate error messages
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing location: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share location: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
    }
  }
  // --- End Location Sharing Logic ---

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;
          if (file.bytes == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to load image data')),
              );
            }
            return;
          }
          print('Web image selected: ${file.name}');
          _showAttachmentPreview(file, 'image', file.name);
        }
      } else {
        final ImagePicker imagePicker = ImagePicker();
        final pickedFile = await imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        if (pickedFile != null) {
          final file = File(pickedFile.path);
          if (!await file.exists()) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selected file not found')),
              );
            }
            return;
          }
          print('Mobile image selected: ${pickedFile.name}');
          _showAttachmentPreview(file, 'image', pickedFile.name);
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (kIsWeb) {
          if (file.bytes == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to load file data')),
              );
            }
            return;
          }
          print('Web file selected: ${file.name}');
          _showAttachmentPreview(file, 'document', file.name);
        } else {
          if (file.path == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File path not available')),
              );
            }
            return;
          }
          final fileObject = File(file.path!);
          if (!await fileObject.exists()) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selected file not found')),
              );
            }
            return;
          }
          print('Mobile file selected: ${file.name}');
          _showAttachmentPreview(fileObject, 'document', file.name);
        }
      }
    } catch (e) {
      print('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e')),
        );
      }
    }
  }

  void _showAttachmentPreview(dynamic file, String type, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                  child: _buildImagePreview(file),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getFileSizeText(file),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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
              final messageText = _messageController.text.trim();
              try {
                await _sendMessage(
                  text: messageText.isEmpty ? null : messageText,
                  attachment: file,
                  attachmentType: type,
                  attachmentName: fileName, messageType: '',
                );
                _messageController.clear();
              } catch (e) {
                print('Error in send message: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send: $e')),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(dynamic file) {
    if (kIsWeb && file is PlatformFile && file.bytes != null) {
      return Image.memory(
        file.bytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading image preview: $error');
          return Container(
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.error, size: 48)),
          );
        },
      );
    } else if (!kIsWeb && file is File) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('Error loading file image: $error');
          return Container(
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.error, size: 48)),
          );
        },
      );
    }
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.image, size: 48)),
    );
  }

  String _getFileSizeText(dynamic file) {
    try {
      int? sizeInBytes;
      if (kIsWeb && file is PlatformFile) {
        sizeInBytes = file.size;
      } else if (!kIsWeb && file is File) {
        sizeInBytes = file.lengthSync();
      }
      if (sizeInBytes == null) return 'Unknown size';
      if (sizeInBytes < 1024) return '$sizeInBytes B';
      if (sizeInBytes < 1024 * 1024) return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      return 'Unknown size';
    }
  }

  void _startNewConversation(Map<String, dynamic> member) {
    if (_currentUser == null) {
      print('Cannot start conversation: No current user');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to start a conversation')),
        );
      }
      return;
    }
    setState(() {
      _isConversationMode = true;
      _currentPartnerId = member['id'];
      _currentPartnerName = member['name'] ?? 'Unknown';
      _currentPartnerRole = member['role'] ?? 'member';
      _currentPartnerType = member['role'] == 'contractor' ? 'contractor' : 'freelancer';
    });
    _loadMessages();
    _markMessagesAsRead();
  }

  void _openConversation(Map<String, dynamic> conversation) {
    if (_currentUser == null) {
      print('Cannot open conversation: No current user');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to open a conversation')),
        );
      }
      return;
    }
    setState(() {
      _isConversationMode = true;
      _currentPartnerId = conversation['partner_id'];
      _currentPartnerName = conversation['partner_name'] ?? 'Unknown';
      _currentPartnerRole = conversation['partner_role'] ?? 'Unknown';
      _currentPartnerType = conversation['partner_role'] == 'contractor' ? 'contractor' : 'freelancer';
    });
    _loadMessages();
    _markMessagesAsRead();
  }

  void _goBackToList() {
    setState(() {
      _isConversationMode = false;
      _currentPartnerId = null;
      _currentPartnerName = null;
      _currentPartnerRole = null;
      _currentPartnerType = null;
      _messages.clear();
      _messageController.clear();
    });
    _loadInitialData();
  }

  Widget _buildConversationsTab() {
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No conversations yet', style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text('Start a conversation with your team members', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _conversations.length,
        itemBuilder: (context, index) => _buildConversationTile(_conversations[index]),
      ),
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conversation) {
    final lastMessageTime = DateTime.parse(conversation['last_message_time']);
    final timeStr = _formatTime(lastMessageTime);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => _openConversation(conversation),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.blue.shade100,
          backgroundImage: conversation['partner_photo'] != null ? NetworkImage(conversation['partner_photo']) : null,
          child: conversation['partner_photo'] == null ? Icon(conversation['partner_role'] == 'contractor' ? Icons.business : Icons.person, color: Colors.blue.shade700) : null,
        ),
        title: Text(conversation['partner_name'] ?? 'Unknown', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((conversation['partner_role'] ?? 'Unknown').toUpperCase(), style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(conversation['last_message'] ?? '', style: GoogleFonts.poppins(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        trailing: Text(timeStr, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildTeamMembersTab() {
    if (_teamMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No team members found', style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _teamMembers.length,
        itemBuilder: (context, index) => _buildTeamMemberTile(_teamMembers[index]),
      ),
    );
  }

  Widget _buildTeamMemberTile(Map<String, dynamic> member) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => _startNewConversation(member),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.green.shade100,
          backgroundImage: member['profile_photo_url'] != null ? NetworkImage(member['profile_photo_url']) : null,
          child: member['profile_photo_url'] == null ? Icon(member['role'] == 'contractor' ? Icons.business : Icons.person, color: Colors.green.shade700) : null,
        ),
        title: Text(member['name'] ?? 'Unknown', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((member['role'] ?? 'member').toUpperCase(), style: GoogleFonts.poppins(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(member['email'] ?? '', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
        ]),
        trailing: const Icon(Icons.chat_bubble_outline),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) return DateFormat('MMM dd').format(dateTime);
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Now';
  }

  // Modified _buildMessageBubble to handle location messages
  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.senderId == _currentUser!['id'];
    final time = DateFormat('HH:mm').format(message.createdAt);

    return FutureBuilder<String?>(
      future: _chatService.getUserNameById(message.senderId, message.senderType),
      builder: (context, snapshot) {
        final senderName = snapshot.data;
        print('Building message bubble for senderId ${message.senderId}, name: $senderName, senderType: ${message.senderType}, full message: ${message.toJson()}');

        // Apply fallback based on senderType if senderName is null
        final displayName = senderName ?? (message.senderType == 'contractor' ? 'Contractor' : message.senderType == 'freelancer' ? 'Freelancer' : 'Unknown');

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(
                        message.senderType == 'contractor' ? Icons.business : Icons.person,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.blue.shade600 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle LOCATION messages first
                      if (message.messageType == 'location' && message.locationLink != null)
                        _buildLocationMessage(message, isMe)
                      else if (message.hasText) // Existing text message logic
                        Text(
                          message.messageText ?? 'No text',
                          style: GoogleFonts.poppins(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      if (message.hasAttachment) ...[
                        if (message.hasText || message.messageType == 'location') const SizedBox(height: 8),
                        _buildAttachment(message, isMe),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: isMe ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 8),
                Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.green.shade100,
                      child: Icon(
                        Icons.person,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentUser!['name'] ?? 'Me',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // New Widget to build location specific message bubble content
  Widget _buildLocationMessage(ChatMessage message, bool isMe) {
    return GestureDetector(
      onTap: () => message.locationLink != null ? _launchMap(message.locationLink!) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue.shade500 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  color: isMe ? Colors.white : Colors.red, // Red for location icon
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message.locationAddress ?? 'Live Location Shared',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (message.messageText != null && message.messageText!.isNotEmpty && message.messageText != message.locationAddress)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  message.messageText!,
                  style: GoogleFonts.poppins(
                    color: isMe ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ),
            // You could embed a static map image here using Google Static Maps API
            // For now, just a text link or implied link through the tap
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Tap to view on map',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isMe ? Colors.blue.shade100 : Colors.blue.shade700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachment(ChatMessage message, bool isMe) {
    if (message.attachmentType == 'image') {
      return GestureDetector(
        onTap: () => _viewImageFullScreen(message.attachmentUrl!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.attachmentUrl!,
            fit: BoxFit.cover,
            height: 200,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey.shade300,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('Error loading attachment image: $error');
              return Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey.shade300,
                child: const Icon(Icons.error),
              );
            },
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => _downloadFile(message.attachmentUrl!, message.attachmentName ?? 'file'),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? Colors.blue.shade500 : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.download,
                color: isMe ? Colors.white : Colors.black54,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.attachmentName ?? 'Attachment',
                  style: GoogleFonts.poppins(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _viewImageFullScreen(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading full screen image: $error');
                    return const Center(child: Icon(Icons.error, color: Colors.white));
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Row(
                children: [
                  if (!kIsWeb)
                    IconButton(
                      onPressed: () => _downloadImage(imageUrl),
                      icon: const Icon(Icons.download, color: Colors.white),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadImage(String imageUrl) async {
    if (kIsWeb) {
      try {
        await launchUrl(Uri.parse(imageUrl));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open image: $e')),
          );
        }
      }
      return;
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading image...')),
      );
      Directory? downloadsDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      if (Platform.isAndroid && downloadsDir != null) {
        downloadsDir = Directory('${downloadsDir.path}/Download');
        if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${downloadsDir!.path}/image_$timestamp.jpg';
      final response = await http.get(Uri.parse(imageUrl));
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image downloaded: image_$timestamp.jpg')),
        );
      }
    } catch (e) {
      print('Error downloading image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download image: $e')),
        );
      }
    }
  }

  Future<void> _downloadFile(String fileUrl, String fileName) async {
    if (kIsWeb) {
      try {
        await launchUrl(Uri.parse(fileUrl));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to open file: $e')),
          );
        }
      }
      return;
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading file...')),
      );
      Directory? downloadsDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      if (Platform.isAndroid && downloadsDir != null) {
        downloadsDir = Directory('${downloadsDir.path}/Download');
        if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
      }
      final cleanFileName = fileName.contains('.') ? fileName : '${fileName}_${DateTime.now().millisecondsSinceEpoch}';
      final filePath = '${downloadsDir!.path}/$cleanFileName';
      final response = await http.get(Uri.parse(fileUrl));
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File downloaded: $cleanFileName')),
        );
      }
    } catch (e) {
      print('Error downloading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to download file: $e')),
        );
      }
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot open file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      print('Error opening file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error opening file')),
        );
      }
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 4,
            offset: const Offset(0, -2),
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
          // New button for live location
          IconButton(
            onPressed: _shareCurrentLocation, // Call the new function
            icon: const Icon(Icons.location_on),
            color: Colors.blue.shade700,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          _isSending
              ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : IconButton(
            onPressed: () => _sendMessage(text: _messageController.text, messageType: ''),
            icon: const Icon(Icons.send),
            color: Colors.blue.shade700,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _isConversationMode
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToList,
          color: Colors.white,
        )
            : null,
        title: _isConversationMode
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentPartnerName ?? 'Unknown',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              (_currentPartnerRole ?? 'Unknown').toUpperCase(),
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        )
            : Text(
          'Team Chat',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isConversationMode
          ? Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
            ),
          ),
          _buildMessageInput(),
        ],
      )
          : DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: Colors.blue.shade50,
              child: TabBar(
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.blue.shade700,
                tabs: const [
                  Tab(text: 'Conversations', icon: Icon(Icons.chat)),
                  Tab(text: 'Team Members', icon: Icon(Icons.people)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildConversationsTab(),
                  _buildTeamMembersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // These methods are now handled by the LocationHelper class
  // and have been removed to avoid duplication
  
  // Method to launch map URLs
  Future<void> _launchMap(String url) async {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch the map link')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch the map link - URL cannot be handled')),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error launching URL: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching map: ${e.toString()}')),
        );
      }
    }
  }
}


