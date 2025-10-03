import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../services/fetch_agora_token.dart'; // Import fetchAgoraToken
// Conditional imports for web-specific functionality
import '../services/agora_service_web.dart' if (dart.library.io) '../services/agora_service_stub.dart';
import 'dart:html' as html if (dart.library.html) 'dart:html';
import 'dart:ui' as ui if (dart.library.html) 'dart:ui';
// Web-specific imports
import 'dart:ui_web' as ui_web if (dart.library.html) 'dart:ui_web';

const String agoraAppId = 'af46b12f786f45c68dffb85ff61d7527'; // Replace with your Agora App ID

class CallScreen extends StatefulWidget {
  final String channelName;
  final String? token;
  final bool withJoinConfirmation;

  const CallScreen({
    Key? key, // Use Key? instead of super.key
    required this.channelName,
    this.token,
    this.withJoinConfirmation = true,
  }) : super(key: key);

  // Named constructor for deep link navigation
  const CallScreen.withJoinConfirmation({
    required String channelName,
    String? token,
  }) : this(
    channelName: channelName,
    token: token,
    withJoinConfirmation: true,
  );

  // Static method to avoid naming conflict
  static CallScreen createWithJoinConfirmation({
    required String channelName,
    String? token,
  }) {
    return CallScreen(
      channelName: channelName,
      token: token,
      withJoinConfirmation: true,
    );
  }

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;
  AgoraServiceWeb? _webService;
  String? _token;
  bool isJoined = false;
  bool micMuted = false;
  bool videoDisabled = false;
  bool isFrontCamera = true;
  bool isConnected = false;
  List<int> remoteUids = [];
  StreamSubscription? _usersSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await _requestPermissions();

    // Fetch token if not provided via deep link
    _token = widget.token ?? await fetchAgoraToken(widget.channelName);
    if (_token == null) {
      _showError('Failed to fetch token');
      return;
    }

    try {
      if (kIsWeb) {
        // Use web implementation directly for web platform
        _webService = AgoraServiceWeb();
        
        // Register local view factory for Flutter web platform view
        try {
          // Register local view for web only using ui_web
          if (kIsWeb) {
            ui_web.platformViewRegistry.registerViewFactory('local-video-player', (int viewId) {
              final existing = html.document.getElementById('local-video-player');
              if (existing != null) return existing;
              final div = html.DivElement()..id = 'local-video-player';
              div.style.width = '100%';
              div.style.height = '100%';
              div.style.backgroundColor = '#000';
              div.style.borderRadius = '10px';
              return div;
            });
          }
        } catch (e) {
          print('Failed to register local video view: $e');
        }

        await _webService!.initialize(agoraAppId, widget.channelName, _token!, maxRetries: 3);

        // Set up stream subscriptions for web service
        _usersSubscription = _webService!.usersStream.listen((list) {
          if (mounted) {
            setState(() => remoteUids = list);
            // Register remote view factories for new uids
            for (final uid in list) {
              final viewType = 'remote-video-player-$uid';
              try {
                if (kIsWeb) {
                  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
                    final id = 'remote-video-player-$uid';
                    final existing = html.document.getElementById(id);
                    if (existing != null) return existing;
                    final div = html.DivElement()..id = id;
                    div.style.width = '100%';
                    div.style.height = '100%';
                    div.style.backgroundColor = '#000';
                    div.style.borderRadius = '10px';
                    return div;
                  });
                }
              } catch (e) {
                print('Failed to register remote video view for $uid: $e');
              }
            }
          }
        });
        
        _errorSubscription = _webService!.errorStream.listen((error) {
          if (mounted) {
            _showError('Connection Error: $error');
            // Auto-retry connection after error
            if (error.contains('network') || error.contains('connection')) {
              _showInfo('Attempting to reconnect...');
              Timer(Duration(seconds: 3), () {
                if (mounted && !_webService!.isJoined) {
                  _joinChannelWeb();
                }
              });
            }
          }
        });
        
        _connectionSubscription = _webService!.connectionStream.listen((connected) {
          if (mounted) {
            setState(() {
              isConnected = connected;
            });
            if (connected) {
              _showSuccess('Successfully connected to video call');
            } else {
              _showInfo('Disconnected from video call');
            }
          }
        });

        // Show join confirmation or join directly
        if (widget.withJoinConfirmation) {
          final join = await _showJoinConfirmation();
          if (join) {
            await _joinChannelWeb();
          } else {
            if (mounted) Navigator.pop(context);
          }
        } else {
          await _joinChannelWeb();
        }
        return;
      }

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));
      await _engine!.enableVideo();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            setState(() => isJoined = true);
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            setState(() => remoteUids.add(remoteUid));
          },
          onUserOffline: (connection, remoteUid, reason) {
            setState(() => remoteUids.remove(remoteUid));
          },
          onLeaveChannel: (connection, stats) {
            setState(() {
              isJoined = false;
              remoteUids.clear();
            });
          },
          onError: (err, reason) {
            _showError('Agora Error: $reason');
          },
        ),
      );

      if (widget.withJoinConfirmation) {
        final join = await _showJoinConfirmation();
        if (join) {
          _joinChannel();
        } else {
          if (mounted) Navigator.pop(context);
        }
      } else {
        _joinChannel();
      }
    } catch (e) {
      _showError('Failed to initialize Agora: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb) {
      final permissions = await [Permission.microphone, Permission.camera].request();
      if (permissions.values.any((status) => !status.isGranted)) {
        _showError('Camera or microphone permission denied');
      }
    }
  }

  Future<void> _joinChannel() async {
    try {
      final options = const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      );
      await _engine!.joinChannel(
        token: _token!,
        channelId: widget.channelName,
        uid: 0,
        options: options,
      );
    } catch (e) {
      _showError('Failed to join channel: $e');
    }
  }

  Future<void> _joinChannelWeb() async {
    if (_webService == null) {
      _showError('Video service not initialized');
      return;
    }
    
    if (_token == null) {
      _showError('Authentication token not available');
      return;
    }
    
    try {
      _showInfo('Joining video call...');
      await _webService!.joinChannel(_token!, widget.channelName, 0);
      if (mounted) {
        setState(() => isJoined = true);
        _showSuccess('Successfully joined ${widget.channelName}');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to join channel';
        if (e.toString().contains('token')) {
          errorMessage = 'Invalid or expired token. Please try again.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network connection failed. Check your internet.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Camera/microphone permission denied.';
        }
        _showError('$errorMessage: ${e.toString()}');
      }
    }
  }

  Future<void> _retryConnection() async {
    try {
      _showInfo('Retrying connection...');
      
      // First try to get a fresh token
      _token = await fetchAgoraToken(widget.channelName);
      
      if (_token == null) {
        _showError('Failed to get authentication token');
        return;
      }
      
      // If web service exists, try to rejoin
      if (kIsWeb && _webService != null) {
        await _joinChannelWeb();
      } else if (!kIsWeb && _engine != null) {
        // For mobile, try to rejoin the channel
        await _engine!.leaveChannel();
        await Future.delayed(Duration(seconds: 1));
        await _engine!.joinChannel(
          token: _token!,
          channelId: widget.channelName,
          uid: 0,
          options: const ChannelMediaOptions(
            channelProfile: ChannelProfileType.channelProfileCommunication,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
      }
    } catch (e) {
      _showError('Retry failed: ${e.toString()}');
    }
  }

  Future<bool> _showJoinConfirmation() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Join Call?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Do you want to join the call in "${widget.channelName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Join', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showError(String message) {
    if (!mounted) return;
    print('Call Screen Error: $message');
    
    // Determine if this is a recoverable error
    bool isRecoverable = message.contains('network') || 
                        message.contains('connection') || 
                        message.contains('timeout') ||
                        message.contains('token');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: isRecoverable ? 8 : 5),
        action: SnackBarAction(
          label: isRecoverable ? 'Retry' : 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (isRecoverable) {
              _retryConnection();
            }
          },
        ),
      ),
    );
    
    // Only auto-exit for critical non-recoverable errors
    if (message.contains('Failed to initialize') || message.contains('Permission denied')) {
      Timer(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }
  
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _shareInvite() {
    final link = kIsWeb
        ? 'https://assetmanagementsystem-tecnvi.web.app/join?channel=${widget.channelName}'
        : 'assetmanagement://join?channel=${widget.channelName}';
    Share.share('Join my video call: $link');
  }

  Future<void> _toggleCamera() async {
    try {
      if (kIsWeb && _webService != null) {
        await _webService!.switchCamera();
        if (mounted) {
          setState(() {
            isFrontCamera = _webService!.isFrontCamera;
          });
          _showInfo('Switched to ${isFrontCamera ? 'front' : 'back'} camera');
        }
      } else {
        await _engine?.switchCamera();
        if (mounted) {
          setState(() {
            isFrontCamera = !isFrontCamera;
          });
          _showInfo('Switched to ${isFrontCamera ? 'front' : 'back'} camera');
        }
      }
    } catch (e) {
      _showError('Failed to switch camera: $e');
    }
  }

  @override
  void dispose() {
    // Cancel stream subscriptions
    _usersSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionSubscription?.cancel();
    
    if (kIsWeb) {
      _webService?.leaveChannel();
      _webService?.dispose();
    } else {
      _engine?.leaveChannel();
      _engine?.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isJoined) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Connecting to video call...',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please wait while we set up your connection',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Call: ${widget.channelName}', style: const TextStyle(fontSize: 18)),
            if (kIsWeb)
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    isConnected ? 'Connected' : 'Connecting...',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          if (remoteUids.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.white54,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for others to join...',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Share the invite link to get started',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            ),
          if (remoteUids.isNotEmpty)
            GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: remoteUids.length > 4 ? 3 : 2,
                childAspectRatio: 3 / 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: remoteUids.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: kIsWeb
                        ? HtmlElementView(viewType: 'remote-video-player-${remoteUids[index]}')
                        : AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: _engine!,
                              canvas: VideoCanvas(uid: remoteUids[index]),
                              connection: RtcConnection(channelId: widget.channelName),
                            ),
                          ),
                  ),
                );
              },
            ),
          if (!(kIsWeb ? _webService?.videoMuted ?? videoDisabled : videoDisabled))
            Positioned(
              bottom: 100,
              right: 16,
              width: 100,
              height: 140,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: kIsWeb
                      ? HtmlElementView(viewType: 'local-video-player')
                      : AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: _engine!,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.black87,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildControlButton(
              icon: (kIsWeb ? _webService?.audioMuted ?? micMuted : micMuted) ? Icons.mic_off : Icons.mic,
              color: (kIsWeb ? _webService?.audioMuted ?? micMuted : micMuted) ? Colors.red : Colors.white,
              onPressed: () async {
                try {
                  if (kIsWeb) {
                    await _webService?.toggleAudio();
                    if (mounted) {
                      setState(() => micMuted = _webService?.audioMuted ?? micMuted);
                      _showInfo(micMuted ? 'Microphone muted' : 'Microphone unmuted');
                    }
                  } else {
                    setState(() => micMuted = !micMuted);
                    _engine?.muteLocalAudioStream(micMuted);
                    _showInfo(micMuted ? 'Microphone muted' : 'Microphone unmuted');
                  }
                } catch (e) {
                  _showError('Failed to toggle microphone: $e');
                }
              },
            ),
            _buildControlButton(
              icon: (kIsWeb ? _webService?.videoMuted ?? videoDisabled : videoDisabled) ? Icons.videocam_off : Icons.videocam,
              color: (kIsWeb ? _webService?.videoMuted ?? videoDisabled : videoDisabled) ? Colors.red : Colors.white,
              onPressed: () async {
                try {
                  if (kIsWeb) {
                    await _webService?.toggleVideo();
                    if (mounted) {
                      setState(() => videoDisabled = _webService?.videoMuted ?? videoDisabled);
                      _showInfo(videoDisabled ? 'Camera disabled' : 'Camera enabled');
                    }
                  } else {
                    setState(() => videoDisabled = !videoDisabled);
                    _engine?.enableLocalVideo(!videoDisabled);
                    _showInfo(videoDisabled ? 'Camera disabled' : 'Camera enabled');
                  }
                } catch (e) {
                  _showError('Failed to toggle camera: $e');
                }
              },
            ),
            _buildControlButton(
              icon: Icons.flip_camera_ios,
              color: Colors.white,
              onPressed: () async {
                _toggleCamera();
              },
            ),
            _buildControlButton(
              icon: Icons.share,
              color: Colors.white,
              onPressed: _shareInvite,
            ),
            _buildControlButton(
              icon: Icons.call_end,
              color: Colors.red,
              onPressed: () async {
                try {
                  _showInfo('Leaving video call...');
                  if (kIsWeb) {
                    await _webService?.leaveChannel();
                    _webService?.dispose();
                  } else {
                    await _engine?.leaveChannel();
                  }
                  if (mounted) {
                    _showSuccess('Left video call successfully');
                    Navigator.pop(context);
                  }
                } catch (e) {
                  _showError('Error leaving call: $e');
                  // Still navigate back even if there's an error
                  if (mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      child: IconButton(
        icon: Icon(icon, color: color, size: 28),
        onPressed: onPressed,
        padding: const EdgeInsets.all(12),
        style: IconButton.styleFrom(
          backgroundColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}