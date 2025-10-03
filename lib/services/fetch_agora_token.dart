import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String?> fetchAgoraToken(String channelName, {int? uid, int maxRetries = 3}) async {
  int retryCount = 0;
  
  while (retryCount < maxRetries) {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        print('fetchAgoraToken: User not authenticated - attempting to refresh session');
        
        // Try to refresh the session
        try {
          await Supabase.instance.client.auth.refreshSession();
          final refreshedSession = Supabase.instance.client.auth.currentSession;
          if (refreshedSession == null) {
            print('fetchAgoraToken: Session refresh failed');
            return null;
          }
        } catch (refreshError) {
          print('fetchAgoraToken: Session refresh error: $refreshError');
          return null;
        }
      }

      const projectRef = 'crvztrqgmqfixzatlkgz';
      final currentSession = Supabase.instance.client.auth.currentSession!;

      print('fetchAgoraToken: Attempt ${retryCount + 1}/$maxRetries - Requesting token for channel: $channelName, uid: ${uid ?? 0}');
      
      final response = await http.post(
        Uri.parse("https://$projectRef.functions.supabase.co/agora-token"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${currentSession.accessToken}',
        },
        body: jsonEncode({
          'channelName': channelName,
          'uid': uid ?? 0,
          'role': 'publisher', // Explicitly set role
          'expireTime': 3600, // 1 hour expiration
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Token request timeout');
        },
      );

      print('fetchAgoraToken: Response status: ${response.statusCode}');
      print('fetchAgoraToken: Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null && data['token'].toString().isNotEmpty) {
          print('fetchAgoraToken: Token fetched successfully (length: ${data["token"].toString().length})');
          return data["token"];
        } else {
          print('fetchAgoraToken: Invalid token received: $data');
          throw Exception('Invalid token received from server');
        }
      } else if (response.statusCode == 401) {
        print('fetchAgoraToken: Authentication failed - token may be expired');
        // Try to refresh session and retry
        await Supabase.instance.client.auth.refreshSession();
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: retryCount));
          continue;
        }
        return null;
      } else {
        print('fetchAgoraToken: HTTP Error ${response.statusCode}: ${response.body}');
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('fetchAgoraToken: Exception on attempt ${retryCount + 1}: $e');
      retryCount++;
      
      if (retryCount < maxRetries) {
        final delay = Duration(seconds: retryCount * 2); // Exponential backoff
        print('fetchAgoraToken: Retrying in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);
      } else {
        print('fetchAgoraToken: All retry attempts failed');
        return null;
      }
    }
  }
  
  return null;
}