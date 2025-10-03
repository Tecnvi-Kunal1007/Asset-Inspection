// Stub implementation for non-web platforms
// This file provides empty implementations for platforms other than web

class AgoraServiceWeb {
  // Stub implementation - all methods throw unsupported error
  Future<void> initialize() async {
    throw UnsupportedError('AgoraServiceWeb is only supported on web platform');
  }
  
  Future<void> joinChannel(String channelName, String token, {int? uid}) async {
    throw UnsupportedError('AgoraServiceWeb is only supported on web platform');
  }
  
  Future<void> leaveChannel() async {
    throw UnsupportedError('AgoraServiceWeb is only supported on web platform');
  }
  
  Future<void> toggleAudio() async {
    throw UnsupportedError('AgoraServiceWeb is only supported on web platform');
  }
  
  Future<void> toggleVideo() async {
    throw UnsupportedError('AgoraServiceWeb is only supported on web platform');
  }
  
  Future<void> switchCamera() async {
    throw UnsupportedError('AgoraServiceWeb is only supported on web platform');
  }
  
  void dispose() {
    // No-op for stub
  }
  
  // Getters that return default values
  bool get isJoined => false;
  bool get audioMuted => false;
  bool get videoMuted => false;
  bool get isFrontCamera => true;
  String? get currentChannelName => null;
  List<int> get remoteUsers => [];
  bool get isConnected => false;
  int get userCount => 0;
  
  // Stream getters that return empty streams
  Stream<List<int>> get usersStream => Stream.empty();
  Stream<String> get errorStream => Stream.empty();
  Stream<bool> get connectionStream => Stream.empty();
}