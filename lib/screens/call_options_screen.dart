import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'call_screen.dart';

class CallOptionsScreen extends StatefulWidget {
  final String channelName;
  final String? token;

  const CallOptionsScreen({
    Key? key,
    required this.channelName,
    this.token,
  }) : super(key: key);

  @override
  State<CallOptionsScreen> createState() => _CallOptionsScreenState();
}

class _CallOptionsScreenState extends State<CallOptionsScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool micEnabled = true;
  bool videoEnabled = true;
  bool isAudioOnly = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _shareInviteLink() {
    final link = kIsWeb
        ? 'https://assetmanagementsystem-tecnvi.web.app/join?channel=${widget.channelName}'
        : 'assetmanagement://join?channel=${widget.channelName}';
    
    Share.share(
      'Join my ${isAudioOnly ? 'voice' : 'video'} call: $link\n\nChannel: ${widget.channelName}',
      subject: 'Video Call Invitation',
    );
  }

  void _startCall() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          channelName: widget.channelName,
          token: widget.token,
          withJoinConfirmation: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text(
          'Call Setup',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
              Color(0xFF0F3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // Channel Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isAudioOnly ? Icons.phone : Icons.videocam,
                        size: 48,
                        color: const Color(0xFF4ECDC4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isAudioOnly ? 'Voice Call' : 'Video Call',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Channel: ${widget.channelName}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Call Type Toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isAudioOnly = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !isAudioOnly
                                  ? const Color(0xFF4ECDC4)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.videocam,
                                  color: !isAudioOnly
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.6),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Video Call',
                                  style: TextStyle(
                                    color: !isAudioOnly
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => isAudioOnly = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isAudioOnly
                                  ? const Color(0xFF4ECDC4)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.phone,
                                  color: isAudioOnly
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.6),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Voice Call',
                                  style: TextStyle(
                                    color: isAudioOnly
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Audio/Video Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlToggle(
                      icon: micEnabled ? Icons.mic : Icons.mic_off,
                      label: 'Microphone',
                      isEnabled: micEnabled,
                      onTap: () => setState(() => micEnabled = !micEnabled),
                    ),
                    if (!isAudioOnly)
                      _buildControlToggle(
                        icon: videoEnabled ? Icons.videocam : Icons.videocam_off,
                        label: 'Camera',
                        isEnabled: videoEnabled,
                        onTap: () => setState(() => videoEnabled = !videoEnabled),
                      ),
                  ],
                ),
                
                const Spacer(),
                
                // Action Buttons
                Column(
                  children: [
                    // Share Invite Link Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _shareInviteLink,
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: const Text(
                          'Share Invite Link',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Start Call Button
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _startCall,
                              icon: Icon(
                                isAudioOnly ? Icons.phone : Icons.videocam,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Start ${isAudioOnly ? 'Voice' : 'Video'} Call',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 8,
                                shadowColor: const Color(0xFF25D366).withOpacity(0.4),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Info Text
                Text(
                  'Participants can join using the shared link',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlToggle({
    required IconData icon,
    required String label,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEnabled
              ? const Color(0xFF4ECDC4).withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled
                ? const Color(0xFF4ECDC4)
                : Colors.red,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isEnabled
                  ? const Color(0xFF4ECDC4)
                  : Colors.red,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isEnabled
                    ? const Color(0xFF4ECDC4)
                    : Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}