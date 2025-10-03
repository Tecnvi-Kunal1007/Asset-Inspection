import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:js_util' as js_util;
import 'fetch_agora_token.dart';

class AgoraServiceWeb {
  static const String agoraAppId = 'af46b12f786f45c68dffb85ff61d7527';

  dynamic _client;
  dynamic _localVideoTrack;
  dynamic _localAudioTrack;
  bool _isInitialized = false;
  bool _isJoined = false;
  bool _audioMuted = false;
  bool _videoMuted = false;
  bool _isFrontCamera = true;
  String? _currentChannelName;
  int? _currentUid;

  final StreamController<List<int>> _usersController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get usersStream => _usersController.stream;

  final StreamController<String> _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  final List<int> _remoteUsers = [];
  final Map<int, dynamic> _remoteVideoTracks = {};
  final Map<int, dynamic> _remoteAudioTracks = {};
  
  // Connection monitoring
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 5;
  bool _isReconnecting = false;

  // Getters for current state
  bool get isJoined => _isJoined;
  bool get audioMuted => _audioMuted;
  bool get videoMuted => _videoMuted;
  bool get isFrontCamera => _isFrontCamera;
  String? get currentChannelName => _currentChannelName;
  List<int> get remoteUsers => List.from(_remoteUsers);

  Future<void> initialize(String appId, String channelName, String token, {int maxRetries = 3}) async {
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        print('AgoraServiceWeb: Starting initialization attempt ${retryCount + 1}/$maxRetries...');

        // Wait for SDK to be available
        await _waitForAgoraSDK();

        // Use JavaScript eval to create client as a fallback
        await _initializeWithJavaScript(appId, channelName, token);
        
        print('AgoraServiceWeb: Initialization successful on attempt ${retryCount + 1}');
        return;

      } catch (e) {
        print('AgoraServiceWeb: Initialization attempt ${retryCount + 1} failed: $e');
        retryCount++;
        
        if (retryCount < maxRetries) {
          final delay = Duration(seconds: retryCount * 2);
          print('AgoraServiceWeb: Retrying initialization in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        } else {
          print('AgoraServiceWeb: All initialization attempts failed');
          _errorController.add('Failed to initialize video calling after $maxRetries attempts: $e');
          throw Exception('Failed to initialize Agora Web SDK after $maxRetries attempts: $e');
        }
      }
    }
  }

  Future<void> _initializeWithJavaScript(String appId, String channelName, String token) async {
    print('AgoraServiceWeb: Attempting JavaScript initialization...');

    try {
      // Use JavaScript to create the client directly
      final clientScript = '''
        (function() {
          try {
            console.log('Creating AgoraRTC client...');
            const client = window.AgoraRTC.createClient({mode: "rtc", codec: "vp8"});
            window.agoraClient = client;
            return client;
          } catch (e) {
            console.error('Failed to create client:', e);
            throw e;
          }
        })()
      ''';

      _client = js.context.callMethod('eval', [clientScript]);

      if (_client == null) {
        throw Exception('Failed to create AgoraRTC client');
      }

      print('AgoraServiceWeb: Client created successfully and stored globally');

      await _setupEventListeners();
      _startNetworkMonitoring();
      _isInitialized = true;

      print('AgoraServiceWeb: Initialization complete with network monitoring, ready to join channel');

    } catch (e) {
      print('AgoraServiceWeb: JavaScript initialization failed: $e');
      rethrow;
    }
  }



  Future<T> _promiseToFuture<T>(dynamic promise) {
    final completer = Completer<T>();
    final callbackId = DateTime.now().millisecondsSinceEpoch.toString();

    // Create unique callback names to avoid conflicts
    final resolveCallback = 'dartResolve_$callbackId';
    final rejectCallback = 'dartReject_$callbackId';

    js.context[resolveCallback] = js.allowInterop((dynamic result) {
      if (!completer.isCompleted) {
        // Clean up callbacks
        js.context[resolveCallback] = null;
        js.context[rejectCallback] = null;
        completer.complete(result);
      }
    });

    js.context[rejectCallback] = js.allowInterop((dynamic error) {
      if (!completer.isCompleted) {
        // Clean up callbacks
        js.context[resolveCallback] = null;
        js.context[rejectCallback] = null;
        completer.completeError(Exception(error.toString()));
      }
    });

    // Execute promise handling with proper parameter passing
    final handlePromiseScript = '''
      (function() {
        var promise = arguments[0];
        var resolveCallback = arguments[1];
        var rejectCallback = arguments[2];
        
        if (promise && typeof promise.then === 'function') {
          promise.then(function(result) {
            window[resolveCallback](result);
          }).catch(function(error) {
            window[rejectCallback](error);
          });
        } else {
          // Not a promise, resolve immediately
          window[resolveCallback](promise);
        }
      })
    ''';

    js.context.callMethod('eval', [handlePromiseScript])(promise, resolveCallback, rejectCallback);

    return completer.future;
  }

  bool _isAgoraSDKLoaded() {
    try {
      // Simple check using JavaScript
      final checkScript = '''
        (function() {
          return typeof window.AgoraRTC !== 'undefined' && 
                 typeof window.AgoraRTC.createClient === 'function';
        })()
      ''';

      final result = js.context.callMethod('eval', [checkScript]);
      return result == true;
    } catch (e) {
      print('AgoraServiceWeb: Error checking SDK: $e');
      return false;
    }
  }

  Future<void> _waitForAgoraSDK() async {
    print('AgoraServiceWeb: Checking for Agora SDK availability...');

    // If SDK is already loaded, return immediately
    if (_isAgoraSDKLoaded()) {
      print('AgoraServiceWeb: SDK already available');
      return;
    }

    // Wait up to 10 seconds for SDK to become available
    for (int i = 0; i < 20; i++) {
      await Future.delayed(Duration(milliseconds: 500));
      print('AgoraServiceWeb: Attempt ${i + 1}/20 - checking SDK...');
      if (_isAgoraSDKLoaded()) {
        print('AgoraServiceWeb: SDK became available after ${(i + 1) * 500}ms');
        return;
      }
    }

    throw Exception('Agora SDK not available after 10 seconds. Please ensure the SDK is loaded in index.html');
  }

  Future<void> _setupEventListeners() async {
    if (_client == null) return;

    try {
      print('AgoraServiceWeb: Setting up event listeners...');

      // First, set up Dart callbacks before JavaScript tries to use them
      final connectionStateCallback = js.allowInterop((String curState, String reason) {
        print('AgoraServiceWeb: Connection state changed: $curState, reason: $reason');
        _connectionController.add(curState == 'CONNECTED');
        
        if (curState == 'DISCONNECTED' || curState == 'FAILED') {
          _errorController.add('Connection lost: $reason');
          _handleConnectionLoss(reason);
        } else if (curState == 'RECONNECTING') {
          print('AgoraServiceWeb: Attempting to reconnect...');
        } else if (curState == 'CONNECTED') {
          print('AgoraServiceWeb: Successfully connected/reconnected');
          _connectionController.add(true);
        }
      });
      js.context['dartConnectionStateChanged'] = connectionStateCallback;

      final userJoinedCallback = js.allowInterop((int uid) {
        print('AgoraServiceWeb: User joined: $uid');
        if (!_remoteUsers.contains(uid)) {
          _remoteUsers.add(uid);
          _usersController.add(List.from(_remoteUsers));
        }
      });
      js.context['dartUserJoined'] = userJoinedCallback;

      final userLeftCallback = js.allowInterop((int uid, String reason) {
        print('AgoraServiceWeb: User left: $uid, reason: $reason');
        _remoteUsers.remove(uid);
        _remoteVideoTracks.remove(uid);
        _remoteAudioTracks.remove(uid);
        _usersController.add(List.from(_remoteUsers));

        final videoElement = html.document.getElementById('remote-video-player-$uid');
        videoElement?.remove();
      });
      js.context['dartUserLeft'] = userLeftCallback;

      final userPublishedCallback = js.allowInterop((int uid, String mediaType, dynamic user) {
        print('AgoraServiceWeb: User published: $uid, mediaType: $mediaType');
        _handleUserPublished(uid, mediaType, user);
      });
      js.context['dartUserPublished'] = userPublishedCallback;

      final userUnpublishedCallback = js.allowInterop((int uid, String mediaType) {
        print('AgoraServiceWeb: User unpublished: $uid, mediaType: $mediaType');
        if (mediaType == 'video') {
          _remoteVideoTracks.remove(uid);
          final videoElement = html.document.getElementById('remote-video-player-$uid');
          if (videoElement != null) {
            videoElement.style.display = 'none';
          }
        } else if (mediaType == 'audio') {
          _remoteAudioTracks.remove(uid);
        }
      });
      js.context['dartUserUnpublished'] = userUnpublishedCallback;

      final exceptionCallback = js.allowInterop((dynamic code, String msg) {
        print('AgoraServiceWeb: Exception: $code, message: $msg');
        _errorController.add('Video call error: $msg');
      });
      js.context['dartException'] = exceptionCallback;
      js.context['window']['dartException'] = exceptionCallback;

      print('AgoraServiceWeb: Dart callbacks registered successfully');

      // Add a small delay to ensure callbacks are fully registered
      await Future.delayed(Duration(milliseconds: 100));

      // Now set up JavaScript event listeners after callbacks are ready
      js.context.callMethod('eval', ['''
        (function() {
          const client = window.agoraClient;
          if (!client) {
            console.error('Client not available for event listeners');
            return;
          }
          
          console.log('Setting up JavaScript event listeners...');
          
          client.on('connection-state-change', function(curState, revState, reason) {
            console.log('Connection state changed:', curState, reason);
            if (window.dartConnectionStateChanged) {
              window.dartConnectionStateChanged(curState, reason);
            } else {
              console.error('dartConnectionStateChanged not available');
            }
          });
          
          client.on('user-joined', function(user) {
            console.log('User joined:', user.uid);
            if (window.dartUserJoined) {
              window.dartUserJoined(user.uid);
            } else {
              console.error('dartUserJoined not available');
            }
          });
          
          client.on('user-left', function(user, reason) {
            console.log('User left:', user.uid, reason);
            if (window.dartUserLeft) {
              window.dartUserLeft(user.uid, reason);
            } else {
              console.error('dartUserLeft not available');
            }
          });
          
          client.on('user-published', function(user, mediaType) {
            console.log('User published:', user.uid, mediaType);
            if (window.dartUserPublished) {
              window.dartUserPublished(user.uid, mediaType, user);
            } else {
              console.error('dartUserPublished not available');
            }
          });
          
          client.on('user-unpublished', function(user, mediaType) {
            console.log('User unpublished:', user.uid, mediaType);
            if (window.dartUserUnpublished) {
              window.dartUserUnpublished(user.uid, mediaType);
            } else {
              console.error('dartUserUnpublished not available');
            }
          });
          
          client.on('exception', function(evt) {
            console.log('Exception:', evt.code, evt.msg);
            if (window.dartException) {
              window.dartException(evt.code, evt.msg);
            } else {
              console.error('dartException not available');
            }
          });
          
          console.log('JavaScript event listeners set up successfully');
        })()
      ''']);

    } catch (e) {
      print('AgoraServiceWeb: Error setting up event listeners: $e');
    }
  }

  void _handleUserPublished(int uid, String mediaType, dynamic user) {
    try {
      // Subscribe using JavaScript
      final subscribeScript = '''
        (function(user, mediaType) {
          const client = window.agoraClient;
          return client.subscribe(user, mediaType).then(function() {
            if (mediaType === 'video') {
              return user.videoTrack;
            } else if (mediaType === 'audio') {
              if (user.audioTrack) {
                user.audioTrack.play();
              }
              return user.audioTrack;
            }
          });
        })
      ''';

      final subscribePromise = js.context.callMethod('eval', [subscribeScript])(user, mediaType);

      _promiseToFuture(subscribePromise).then((track) {
        if (mediaType == 'video' && track != null) {
          _remoteVideoTracks[uid] = track;
          _playRemoteVideo(uid, track);
        } else if (mediaType == 'audio' && track != null) {
          _remoteAudioTracks[uid] = track;
        }
      }).catchError((e) {
        print('AgoraServiceWeb: Failed to subscribe to user $uid $mediaType: $e');
        _errorController.add('Failed to receive $mediaType from user $uid');
      });
    } catch (e) {
      print('AgoraServiceWeb: Error handling user published: $e');
    }
  }

  void _playRemoteVideo(int uid, dynamic videoTrack) {
    Timer(Duration(milliseconds: 100), () {
      try {
        final containerId = 'remote-video-player-$uid';
        js.context.callMethod('eval', ['''
          (function() {
            const track = arguments[0];
            const containerId = '$containerId';
            console.log('Attempting to play remote video for UID $uid:', track);
            const videoElement = document.getElementById(containerId);
            console.log('Remote video element found for $uid:', videoElement);
            if (track && track.play && videoElement) {
              track.play(containerId);
              console.log('Remote video track played successfully for UID $uid');
            } else {
              console.error('Cannot play remote video for $uid - track:', track, 'element:', videoElement);
            }
          })
        '''])(videoTrack);
      } catch (e) {
        print('AgoraServiceWeb: Failed to play remote video for $uid: $e');
      }
    });
  }

  Future<void> joinChannel(String token, String channelName, int uid) async {
    if (!_isInitialized) {
      throw Exception('Service not initialized. Call initialize() first.');
    }

    if (_isJoined) {
      print('AgoraServiceWeb: Already joined a channel. Leaving first...');
      await leaveChannel();
    }

    try {
      print('AgoraServiceWeb: Joining channel: $channelName with uid: $uid');

      _currentChannelName = channelName;
      _currentUid = uid;

      // First, actually join the Agora channel
      final joinScript = '''
        (function() {
          const client = window.agoraClient;
          if (!client) {
            throw new Error('Agora client not initialized');
          }
          console.log('Joining channel with client:', client);
          return client.join('${AgoraServiceWeb.agoraAppId}', '$channelName', '$token', $uid);
        })()
      ''';

      final joinPromise = js.context.callMethod('eval', [joinScript]);
      await _promiseToFuture(joinPromise);
      print('AgoraServiceWeb: Successfully joined Agora channel');

      // Then create and publish local tracks
      await _createLocalTracks();
      await _publishLocalTracks();

      _isJoined = true;
      _connectionController.add(true);

      print('AgoraServiceWeb: Fully joined and publishing to channel: $channelName');
    } catch (e) {
      print('AgoraServiceWeb: Failed to join channel: $e');
      _errorController.add('Failed to join video call: $e');
      throw Exception('Failed to join channel: $e');
    }
  }

  Future<void> _createLocalTracks() async {
    try {
      print('AgoraServiceWeb: Creating local tracks...');

      // Reset muted states when creating new tracks
      _audioMuted = false;
      _videoMuted = false;

      // Create audio track first
      final audioTrackScript = '''
        (function() {
          return window.AgoraRTC.createMicrophoneAudioTrack({
            encoderConfig: {
              sampleRate: 48000,
              stereo: true,
              bitrate: 128,
            }
          });
        })()
      ''';

      final audioPromise = js.context.callMethod('eval', [audioTrackScript]);
      _localAudioTrack = await _promiseToFuture(audioPromise);

      // Ensure audio track is enabled
      if (_localAudioTrack != null) {
        final enableAudioScript = '''
          (function(track) {
            return track.setEnabled(true);
          })
        ''';
        final enableAudioPromise = js.context.callMethod('eval', [enableAudioScript])(_localAudioTrack);
        await _promiseToFuture(enableAudioPromise);
        print('AgoraServiceWeb: Audio track enabled');
      }

      // Create video track
      final videoTrackScript = '''
        (function() {
          return window.AgoraRTC.createCameraVideoTrack({
            encoderConfig: {
              width: 640,
              height: 480,
              frameRate: 30,
              bitrateMin: 400,
              bitrateMax: 1000,
            },
            facingMode: '${_isFrontCamera ? 'user' : 'environment'}'
          });
        })()
      ''';

      final videoPromise = js.context.callMethod('eval', [videoTrackScript]);
      _localVideoTrack = await _promiseToFuture(videoPromise);

      // Ensure video track is enabled and play local video
      if (_localVideoTrack != null) {
        final enableVideoScript = '''
          (function(track) {
            return track.setEnabled(true);
          })
        ''';
        final enableVideoPromise = js.context.callMethod('eval', [enableVideoScript])(_localVideoTrack);
        await _promiseToFuture(enableVideoPromise);
        print('AgoraServiceWeb: Video track enabled');

        Timer(Duration(milliseconds: 100), () {
          try {
            js.context.callMethod('eval', ['''
              (function(track) {
                console.log('Attempting to play local video track:', track);
                const videoElement = document.getElementById('local-video-player');
                console.log('Local video element found:', videoElement);
                if (track && track.play && videoElement) {
                  track.play('local-video-player');
                  console.log('Local video track played successfully');
                } else {
                  console.error('Cannot play local video - track:', track, 'element:', videoElement);
                }
              })
            '''])(_localVideoTrack);
          } catch (e) {
            print('AgoraServiceWeb: Failed to play local video: $e');
          }
        });
      }

      print('AgoraServiceWeb: Local tracks created and enabled successfully');
    } catch (e) {
      print('AgoraServiceWeb: Failed to create local tracks: $e');
      _errorController.add('Failed to access camera/microphone: $e');
      throw Exception('Failed to create local tracks: $e');
    }
  }

  Future<void> _publishLocalTracks() async {
    if (_client == null) return;

    try {
      final tracksToPublish = <dynamic>[];

      if (_localAudioTrack != null) {
        tracksToPublish.add(_localAudioTrack);
      }

      if (_localVideoTrack != null && !_videoMuted) {
        tracksToPublish.add(_localVideoTrack);
      }

      if (tracksToPublish.isNotEmpty) {
        final publishScript = '''
          (function(tracks) {
            const client = window.agoraClient;
            return client.publish(tracks);
          })
        ''';

        final publishPromise = js.context.callMethod('eval', [publishScript])(js_util.jsify(tracksToPublish));
        await _promiseToFuture(publishPromise);
        print('AgoraServiceWeb: Published ${tracksToPublish.length} local tracks');
      }
    } catch (e) {
      print('AgoraServiceWeb: Failed to publish local tracks: $e');
      _errorController.add('Failed to share your video/audio: $e');
      throw Exception('Failed to publish local tracks: $e');
    }
  }

  Future<void> toggleAudio() async {
    if (_localAudioTrack == null) {
      _errorController.add('Microphone not available');
      return;
    }

    try {
      _audioMuted = !_audioMuted;

      final toggleScript = '''
        (function() {
          const track = arguments[0];
          const enabled = arguments[1];
          return track.setEnabled(enabled);
        })
      ''';

      final togglePromise = js.context.callMethod('eval', [toggleScript])(_localAudioTrack, !_audioMuted);
      await _promiseToFuture(togglePromise);

      print('AgoraServiceWeb: Audio ${_audioMuted ? "muted" : "unmuted"}');
    } catch (e) {
      print('AgoraServiceWeb: Failed to toggle audio: $e');
      _errorController.add('Failed to toggle microphone: $e');
      _audioMuted = !_audioMuted;
    }
  }

  Future<void> toggleVideo() async {
    if (_localVideoTrack == null) {
      _errorController.add('Camera not available');
      return;
    }

    try {
      _videoMuted = !_videoMuted;

      if (_videoMuted) {
        // Unpublish and disable video track
        if (_isJoined) {
          final unpublishScript = '''
            (function() {
              const client = window.agoraClient;
              const track = arguments[0];
              return client.unpublish(track);
            })
          ''';

          final unpublishPromise = js.context.callMethod('eval', [unpublishScript])(_localVideoTrack);
          await _promiseToFuture(unpublishPromise);
        }

        final disableScript = '''
          (function() {
            const track = arguments[0];
            return track.setEnabled(false);
          })
        ''';

        final disablePromise = js.context.callMethod('eval', [disableScript])(_localVideoTrack);
        await _promiseToFuture(disablePromise);

      } else {
        // Enable and publish video track
        final enableScript = '''
          (function() {
            const track = arguments[0];
            return track.setEnabled(true);
          })
        ''';

        final enablePromise = js.context.callMethod('eval', [enableScript])(_localVideoTrack);
        await _promiseToFuture(enablePromise);

        if (_isJoined) {
          final publishScript = '''
            (function() {
              const client = window.agoraClient;
              const track = arguments[0];
              return client.publish(track);
            })
          ''';

          final publishPromise = js.context.callMethod('eval', [publishScript])(_localVideoTrack);
          await _promiseToFuture(publishPromise);
        }
      }

      print('AgoraServiceWeb: Video ${_videoMuted ? "disabled" : "enabled"}');
    } catch (e) {
      print('AgoraServiceWeb: Failed to toggle video: $e');
      _errorController.add('Failed to toggle camera: $e');
      _videoMuted = !_videoMuted;
    }
  }

  Future<void> switchCamera() async {
    if (_localVideoTrack == null) {
      _errorController.add('Camera not available');
      return;
    }

    try {
      final switchScript = '''
        (function() {
          const track = arguments[0];
          return window.AgoraRTC.getCameras().then(function(cameras) {
            if (cameras.length > 1) {
              const currentFacing = arguments[1];
              const targetCamera = cameras.find(function(camera) {
                return camera.facingMode === (currentFacing ? 'environment' : 'user');
              });
              
              if (targetCamera) {
                return track.switchDevice(targetCamera.deviceId);
              } else {
                // Fallback: switch to next camera
                return track.switchDevice(cameras[1].deviceId);
              }
            } else {
              throw new Error('Only one camera available');
            }
          });
        })
      ''';

      final switchPromise = js.context.callMethod('eval', [switchScript])(_localVideoTrack, _isFrontCamera);
      await _promiseToFuture(switchPromise);

      _isFrontCamera = !_isFrontCamera;
      print('AgoraServiceWeb: Camera switched to ${_isFrontCamera ? "front" : "back"}');
    } catch (e) {
      print('AgoraServiceWeb: Failed to switch camera: $e');
      _errorController.add('Failed to switch camera: $e');
    }
  }

  Future<void> leaveChannel() async {
    if (!_isJoined) return;

    try {
      print('AgoraServiceWeb: Leaving channel...');

      // Stop and close local tracks
      if (_localAudioTrack != null) {
        try {
          js.context.callMethod('eval', ['''
            (function() {
              const track = arguments[0];
              track.stop();
              track.close();
            })
          '''])(_localAudioTrack);
        } catch (e) {
          print('AgoraServiceWeb: Error closing audio track: $e');
        }
        _localAudioTrack = null;
      }

      if (_localVideoTrack != null) {
        try {
          js.context.callMethod('eval', ['''
            (function() {
              const track = arguments[0];
              track.stop();
              track.close();
            })
          '''])(_localVideoTrack);
        } catch (e) {
          print('AgoraServiceWeb: Error closing video track: $e');
        }
        _localVideoTrack = null;
      }

      // Clean up remote tracks
      _remoteVideoTracks.clear();
      _remoteAudioTracks.clear();

      // Leave channel
      if (_client != null) {
        final leaveScript = '''
          (function() {
            const client = window.agoraClient;
            return client.leave();
          })
        ''';

        final leavePromise = js.context.callMethod('eval', [leaveScript])();
        await _promiseToFuture(leavePromise);
      }

      // Reset state
      _isJoined = false;
      _audioMuted = false;
      _videoMuted = false;
      _currentChannelName = null;
      _currentUid = null;
      _remoteUsers.clear();
      _usersController.add([]);
      _connectionController.add(false);

      // Clean up video elements
      final localVideo = html.document.getElementById('local-video-player');
      localVideo?.children.clear();

      print('AgoraServiceWeb: Successfully left channel');
    } catch (e) {
      print('AgoraServiceWeb: Error leaving channel: $e');
      _errorController.add('Error leaving call: $e');
    }
  }

  void _handleConnectionLoss(String reason) {
    if (_isReconnecting) {
      print('AgoraServiceWeb: Already attempting reconnection');
      return;
    }
    
    _isReconnecting = true;
    _reconnectionAttempts = 0;
    
    print('AgoraServiceWeb: Connection lost: $reason. Starting reconnection attempts...');
    _attemptReconnection();
  }
  
  void _attemptReconnection() {
    if (_reconnectionAttempts >= _maxReconnectionAttempts) {
      print('AgoraServiceWeb: Max reconnection attempts reached. Giving up.');
      _isReconnecting = false;
      _errorController.add('Unable to reconnect after $_maxReconnectionAttempts attempts');
      return;
    }
    
    _reconnectionAttempts++;
    final delay = Duration(seconds: _reconnectionAttempts * 2); // Exponential backoff
    
    print('AgoraServiceWeb: Reconnection attempt $_reconnectionAttempts/$_maxReconnectionAttempts in ${delay.inSeconds} seconds');
    
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(delay, () async {
      try {
        if (_currentChannelName != null && _currentUid != null) {
          print('AgoraServiceWeb: Attempting to rejoin channel: $_currentChannelName');
          
          // Try to leave first, then rejoin
          await leaveChannel();
          await Future.delayed(Duration(seconds: 1));
          
          // Fetch a new token
          final newToken = await fetchAgoraToken(_currentChannelName!);
          if (newToken != null) {
            await joinChannel(newToken, _currentChannelName!, _currentUid!);
            _isReconnecting = false;
            _reconnectionAttempts = 0;
            print('AgoraServiceWeb: Successfully reconnected to channel');
          } else {
            throw Exception('Failed to fetch new token for reconnection');
          }
        }
      } catch (e) {
        print('AgoraServiceWeb: Reconnection attempt $_reconnectionAttempts failed: $e');
        _attemptReconnection(); // Try again
      }
    });
  }
  
  // Add network state monitoring
  void _startNetworkMonitoring() {
    // Monitor network connectivity using JavaScript
    js.context.callMethod('eval', ['''
      (function() {
        function updateNetworkStatus() {
          const isOnline = navigator.onLine;
          console.log('Network status:', isOnline ? 'online' : 'offline');
          
          if (typeof dartNetworkStatusChanged === 'function') {
            dartNetworkStatusChanged(isOnline);
          }
        }
        
        window.addEventListener('online', updateNetworkStatus);
        window.addEventListener('offline', updateNetworkStatus);
        
        // Initial check
        updateNetworkStatus();
      })()
    ''']);
    
    // Set up Dart callback for network status changes
    final networkCallback = js.allowInterop((bool isOnline) {
      print('AgoraServiceWeb: Network status changed: ${isOnline ? 'online' : 'offline'}');
      
      if (!isOnline) {
        _errorController.add('Network connection lost');
      } else if (_isJoined && !isOnline) {
        print('AgoraServiceWeb: Network restored, checking connection...');
        _handleNetworkRestored();
      }
    });
    
    js.context['dartNetworkStatusChanged'] = networkCallback;
  }
  
  void _handleNetworkRestored() {
    // Give some time for network to stabilize
    Timer(Duration(seconds: 2), () {
      if (_isJoined && _currentChannelName != null) {
        print('AgoraServiceWeb: Network restored, attempting to verify connection...');
        _verifyConnection();
      }
    });
  }
  
  void _verifyConnection() {
    try {
      // Check connection state using JavaScript
      js.context.callMethod('eval', ['''
        (function() {
          const client = window.agoraClient;
          if (client && client.connectionState) {
            console.log('Current connection state:', client.connectionState);
            if (client.connectionState === 'DISCONNECTED' || client.connectionState === 'FAILED') {
              console.log('Connection verification failed, triggering reconnection');
              if (window.dartConnectionStateChanged) {
                window.dartConnectionStateChanged('FAILED', 'Network verification failed');
              }
            }
          }
        })()
      ''']);
    } catch (e) {
      print('AgoraServiceWeb: Error verifying connection: $e');
    }
  }

  void dispose() {
    print('AgoraServiceWeb: Disposing service...');

    leaveChannel();

    _reconnectionTimer?.cancel();
    _usersController.close();
    _errorController.close();
    _connectionController.close();

    _localAudioTrack = null;
    _localVideoTrack = null;
    _client = null;
    _isInitialized = false;

    // Clean up JavaScript references
    js.context['agoraClient'] = null;
    js.context['dartConnectionStateChanged'] = null;
    js.context['dartUserJoined'] = null;
    js.context['dartUserLeft'] = null;
    js.context['dartUserPublished'] = null;
    js.context['dartUserUnpublished'] = null;
    js.context['dartException'] = null;
    js.context['dartPromiseResolve'] = null;
    js.context['dartPromiseReject'] = null;

    print('AgoraServiceWeb: Service disposed');
  }

  // Utility method to get connection status
  bool get isConnected => _isJoined;

  // Method to get current user count
  int get userCount => _remoteUsers.length + (_isJoined ? 1 : 0);
}