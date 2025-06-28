import 'package:flutter/material.dart';
import '../screens/team_chat_screen.dart';
import '../services/chat_service.dart';

class FloatingChat extends StatefulWidget {
  final String userRole; // 'contractor' or 'site_manager'

  const FloatingChat({Key? key, required this.userRole}) : super(key: key);

  @override
  State<FloatingChat> createState() => _FloatingChatState();
}

class _FloatingChatState extends State<FloatingChat> {
  final ChatService _chatService = ChatService();
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    // Refresh unread count every 30 seconds
    _startPeriodicUpdate();
  }

  void _startPeriodicUpdate() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadUnreadCount();
        _startPeriodicUpdate();
      }
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _chatService.getUnreadMessageCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      print('Error loading unread count: $e');
    }
  }

  void _openChatScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeamChatScreen(userRole: widget.userRole),
      ),
    ).then((_) {
      // Refresh unread count when returning from chat
      _loadUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FloatingActionButton(
          onPressed: _openChatScreen,
          backgroundColor: Colors.blue.shade700,
          child: const Icon(Icons.chat, color: Colors.white),
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
