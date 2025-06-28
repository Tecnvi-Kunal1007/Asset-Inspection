import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../models/chat_message.dart'; // Ensure this model is updated as per previous instructions
import '../services/auth_service.dart';
import '../services/location_helper.dart';
import 'package:flutter/material.dart';

// Helper function to extract latitude and longitude from a Google Maps link.
(double, double)? _parseCoordinatesFromLink(String link) {
  try {
    final uri = Uri.parse(link);
    final query = uri.queryParameters['query'];
    if (query != null) {
      final parts = query.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) {
          return (lat, lng);
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print("Error parsing coordinate link: $e");
    }
  }
  return null;
}


class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = AuthService();

  // (This part of the code had no errors and remains the same)
  Future<Map<String, dynamic>?> getCurrentUserInfo() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase.rpc('get_current_user_chat_info');
      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      print('RPC error: $e');
    }
    // Fallback to direct database query with enhanced logging
    final contractor = await _supabase
        .from('contractor')
        .select('id, name, email')
        .eq('id', user.id)
        .maybeSingle();
    if (contractor != null) {
      return {
        'id': contractor['id'],
        'name': contractor['name'] ?? 'Unknown Contractor',
        'email': contractor['email'] ?? 'no-email@default.com',
        'type': 'contractor',
      };
    }

    final freelancer = await _supabase
        .from('freelancers')
        .select('id, name, email, role')
        .eq('email', user.email as Object)
        .maybeSingle();
    if (freelancer != null) {
      return {
        'id': freelancer['id'],
        'name': freelancer['name'] ?? 'Unknown Freelancer',
        'email': freelancer['email'] ?? 'no-email@default.com',
        'type': 'freelancer',
        'role': freelancer['role'] ?? 'member',
      };
    }
    return null;
  }

  Future<String?> _uploadAttachment(dynamic attachment, String name) async {
    try {
      String sanitized = name.replaceAll(RegExp(r'[^a-zA-Z0-9\.\-_]'), '');
      if (sanitized.isEmpty) sanitized = 'file';
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$sanitized';
      Uint8List? bytes;
      if (kIsWeb) {
        if (attachment is PlatformFile) bytes = attachment.bytes;
        else if (attachment is Uint8List) bytes = attachment;
      } else {
        if (attachment is File) bytes = await attachment.readAsBytes();
      }
      if (bytes == null || bytes.isEmpty) throw Exception('Invalid file bytes.');
      await _supabase.storage
          .from('chat-attachments')
          .uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
      return _supabase.storage.from('chat-attachments').getPublicUrl(fileName);
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  Future<ChatMessage?> sendMessage({
  required BuildContext context,
  required String receiverId,
  required String receiverType,
  String? messageText,
  dynamic attachment,
  String? attachmentType,
  String? attachmentName,
  String? locationLink,
  String? locationAddress,
}) async {
  final locationHelper = LocationHelper();
  String finalMessageType = 'text';

  if (locationLink != null) {
    finalMessageType = 'location';
    final hasPermission = await locationHelper.requestLocationPermission(context);
    if (!hasPermission) throw Exception('Location permission required');
  } else if (attachment != null) {
    finalMessageType = attachmentType ?? 'attachment';
  }

  final sender = await getCurrentUserInfo();
  if (sender == null) return null;

  final chatMessagePayload = {
    'sender_id': sender['id'],
    'receiver_id': receiverId,
    'sender_type': sender['type'],
    'receiver_type': receiverType,
    'message_text': (finalMessageType == 'location')
        ? (locationAddress ?? 'Shared a location')
        : messageText,
    'message_type': finalMessageType,
    'is_read': false
  };

  if (finalMessageType != 'location' && attachment != null) {
    chatMessagePayload['attachment_url'] = await _uploadAttachment(attachment, attachmentName ?? 'file');
    chatMessagePayload['attachment_type'] = attachmentType;
    chatMessagePayload['attachment_name'] = attachmentName;
  }
  final insertedMessage = await _supabase
      .from('chat_messages')
      .insert(chatMessagePayload)
      .select()
      .single();
  final newMessageId = insertedMessage['id'];
  if (finalMessageType == 'location' && locationLink != null) {
    final coordinates = _parseCoordinatesFromLink(locationLink);
    if (coordinates != null) {
      final locationPayload = {
        'chat_message_id': newMessageId,
        'latitude': coordinates.$1,
        'longitude': coordinates.$2,
        'address': locationAddress,
        'caption': messageText,
        'is_live': false,
      };
      await _supabase.from('location_messages').insert(locationPayload);
    } else {
      if (kDebugMode) {
        print('Warning: Could not parse coordinates from location link: $locationLink');
      }
    }
  }
  final finalMessage = await getMessageById(newMessageId);
  return finalMessage;
}

  Future<ChatMessage?> getMessageById(String messageId) async {
    try {
      final result = await _supabase
          .from('chat_messages')
          .select('*, location_messages!fk_chat_message(*)')
          .eq('id', messageId)
          .maybeSingle();
      return result != null ? ChatMessage.fromJson(result) : null;
    } catch (e) {
      print("Error fetching message by ID $messageId: $e");
      return null;
    }
  }

  Future<List<ChatMessage>> getMessages({
    required String userId1,
    required String userId2,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final result = await _supabase
          .from('chat_messages')
          .select('*, location_messages!fk_chat_message(*)')
          .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return List<ChatMessage>.from(result.map((m) => ChatMessage.fromJson(m)));
    } catch (e) {
      print('Get messages error: $e');
      return [];
    }
  }

  Future<void> markMessagesAsRead({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      await _supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('sender_id', senderId)
          .eq('receiver_id', receiverId)
          .eq('is_read', false);
    } catch (e) {
      print('Mark as read error: $e');
    }
  }

  // =========== FIX #1 IS HERE ===========
  // In services/ChatService.dart, replace the old streamMessages method with this one.

  // In services/ChatService.dart, replace the old streamMessages method with this final version.

  Stream<List<ChatMessage>> streamMessages({
    required String userId1,
    required String userId2,
  }) {
    // The .or() filter is REMOVED because it is not supported by the stream() builder.
    // Instead, we will listen to all changes on the table and filter them inside the .map() function.
    return _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .map((listOfMaps) {
      // This .where() clause now performs the necessary filtering within your app.
      // It looks at all the incoming messages and only keeps the ones that
      // belong to the current conversation.
      final filtered = listOfMaps.where((m) {
        final senderId = m['sender_id'];
        final receiverId = m['receiver_id'];
        return (senderId == userId1 && receiverId == userId2) ||
            (senderId == userId2 && receiverId == userId1);
      }).toList();

      // Sort the filtered list by time before returning it.
      filtered.sort((a, b) => DateTime.parse(a['created_at'])
          .compareTo(DateTime.parse(b['created_at'])));

      // Note: Real-time joins are complex. This stream won't automatically contain
      // the 'location_messages' data for new messages. A full solution for that
      // involves Supabase database functions or views. This will correctly stream the
      // main chat message for now.
      return filtered.map((m) => ChatMessage.fromJson(m)).toList();
    });
  }



  Future<List<Map<String, dynamic>>> getRecentConversations() async {
    final currentUser = await getCurrentUserInfo();
    if (currentUser == null) return [];
    final currentUserId = currentUser['id']?.toString() ?? '';
    final currentUserType = currentUser['type']?.toString() ?? '';
    List<Map<String, dynamic>> conversations = [];
    if (currentUserType == 'freelancer') {
      final partner = await getFreelancerContractor();
      if (partner != null) {
        final conversation = await _buildConversation(
          currentUserId: currentUserId,
          partnerId: partner['id']?.toString() ?? '',
          partnerType: 'contractor',
          partnerName: partner['name']?.toString() ?? 'Contractor',
          partnerEmail: partner['email']?.toString() ?? '',
          partnerRole: 'Contractor',
        );
        if (conversation != null) conversations.add(conversation);
      }
    } else if (currentUserType == 'contractor') {
      final freelancers = await getContractorFreelancers();
      for (final freelancer in freelancers) {
        final conversation = await _buildConversation(
          currentUserId: currentUserId,
          partnerId: freelancer['id']?.toString() ?? '',
          partnerType: 'freelancer',
          partnerName: freelancer['name']?.toString() ?? 'Freelancer',
          partnerEmail: freelancer['email']?.toString() ?? '',
          partnerRole: freelancer['role']?.toString() ?? 'Freelancer',
        );
        if (conversation != null) conversations.add(conversation);
      }
    }
    conversations.sort((a, b) {
      final timeA = DateTime.parse(a['last_message_time'] as String);
      final timeB = DateTime.parse(b['last_message_time'] as String);
      return timeB.compareTo(timeA);
    });
    return conversations;
  }

  Future<Map<String, dynamic>?> _buildConversation({
    required String currentUserId,
    required String partnerId,
    required String partnerType,
    required String partnerName,
    required String partnerEmail,
    required String partnerRole,
  }) async {
    try {
      final messages = await _supabase
          .from('chat_messages')
          .select()
          .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$partnerId),and(sender_id.eq.$partnerId,receiver_id.eq.$currentUserId)')
          .order('created_at', ascending: false)
          .limit(1);
      String lastMessage = '';
      if (messages.isNotEmpty) {
        final messageData = messages.first;
        final messageType = messageData['message_type'];
        final messageText = messageData['message_text'];
        final attachmentName = messageData['attachment_name'];
        if (messageType == 'location') {
          lastMessage = '📍 Location Shared';
        } else if (messageText != null && messageText.toString().isNotEmpty) {
          lastMessage = messageText.toString();
        } else if (attachmentName != null && attachmentName.toString().isNotEmpty) {
          lastMessage = '📎 ${attachmentName.toString()}';
        } else {
          lastMessage = 'Message';
        }
      }
      return {
        'partner_id': partnerId,
        'partner_type': partnerType,
        'last_message': lastMessage,
        'last_message_time': messages.isNotEmpty
            ? messages.first['created_at']
            : DateTime(1970).toIso8601String(),
        'partner_name': partnerName,
        'partner_email': partnerEmail,
        'partner_role': partnerRole,
      };
    } catch (e) {
      print('Error building conversation for partner $partnerId: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getContractorFreelancers() async {
    final currentUser = await getCurrentUserInfo();
    if (currentUser == null || currentUser['type'] != 'contractor') return [];
    try {
      final result = await _supabase
          .from('freelancers')
          .select('id, name, email, role')
          .eq('contractor_id', currentUser['id'])
          .order('name');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('Error getting contractor freelancers: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getContractorFreelancer() async {
    final currentUser = await getCurrentUserInfo();
    if (currentUser == null || currentUser['type'] != 'contractor') return null;
    try {
      final result = await _supabase
          .from('freelancers')
          .select('id, name, email, role')
          .eq('contractor_id', currentUser['id'])
          .limit(1)
          .maybeSingle();
      return result;
    } catch (e) {
      print('Error getting contractor freelancer: $e');
      return null;
    }
  }

  // =========== FIX #2 IS HERE ===========
  Future<int> getUnreadMessageCount() async {
    final currentUser = await getCurrentUserInfo();
    if (currentUser == null) return 0;

    try {
      // The incorrect `select` with `FetchOptions` is replaced by the `.count()` method
      final response = await _supabase
          .from('chat_messages')
          .count(CountOption.exact)
          .eq('receiver_id', currentUser['id'])
          .eq('is_read', false);

      return response;
    } catch (e) {
      print("Error getting unread count: $e");
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getContractorTeam() async {
    final contractor = await _authService.getCurrentContractorInfo();
    if (contractor == null) return [];
    try {
      final res = await _supabase
          .from('freelancers')
          .select('id, name, email, role, profile_photo_url')
          .eq('contractor_id', contractor['id'])
          .order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error getting contractor team: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getFreelancerContractor() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final freelancer = await _supabase
        .from('freelancers')
        .select('contractor_id')
        .eq('email', user.email!)
        .maybeSingle();
    if (freelancer == null) return null;
    final contractor = await _supabase
        .from('contractor')
        .select('id, name, email')
        .eq('id', freelancer['contractor_id'])
        .maybeSingle();
    return contractor;
  }

  Future<String?> getUserNameById(String userId, String? senderType) async {
    try {
      if (senderType == 'contractor') {
        final response = await _supabase
            .from('contractor')
            .select('id, name')
            .eq('id', userId)
            .maybeSingle();
        return response?['name']?.toString() ?? 'Contractor';
      } else if (senderType == 'freelancer') {
        final response = await _supabase
            .from('freelancers')
            .select('id, name')
            .eq('id', userId)
            .maybeSingle();
        return response?['name']?.toString() ?? 'Freelancer';
      } else {
        var response = await _supabase
            .from('contractor')
            .select('id, name')
            .eq('id', userId)
            .maybeSingle();
        if (response != null && response['name'] != null) return response['name'].toString();
        response = await _supabase
            .from('freelancers')
            .select('id, name')
            .eq('id', userId)
            .maybeSingle();
        if (response != null && response['name'] != null) return response['name'].toString();
        return 'Unknown';
      }
    } catch (e) {
      print('getUserNameById Error: $e');
      return senderType == 'contractor' ? 'Contractor' : 'Freelancer';
    }
  }
}



