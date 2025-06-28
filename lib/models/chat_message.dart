class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderType; // 'contractor' or 'freelancer'
  final String receiverType; // 'contractor' or 'freelancer'
  final String? messageText;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentName;
  final String messageType;
  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderType,
    required this.receiverType,
    this.messageText,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentName,
    required this.messageType,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
    String? locationLink,
    String? locationAddress,
  }) : _locationLink = locationLink, _locationAddress = locationAddress;

  // Additional fields for location data (not stored in the main object)
  final String? _locationLink;
  final String? _locationAddress;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // Check if we have location data from a join
    String? locationLink;
    String? locationAddress;
    
    if (json['location_messages'] != null && json['location_messages'] is List && json['location_messages'].isNotEmpty) {
      final locationData = json['location_messages'][0];
      final double? lat = locationData['latitude'];
      final double? lng = locationData['longitude'];
      
      if (lat != null && lng != null) {
        locationLink = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
        locationAddress = locationData['address'];
      }
    }
    
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      senderType: json['sender_type'] as String,
      receiverType: json['receiver_type'] as String,
      messageText: json['message_text'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      attachmentType: json['attachment_type'] as String?,
      attachmentName: json['attachment_name'] as String?,
      messageType: json['message_type'] as String? ?? 'text',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      locationLink: locationLink,
      locationAddress: locationAddress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sender_type': senderType,
      'receiver_type': receiverType,
      'message_text': messageText,
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
      'attachment_name': attachmentName,
      'message_type': messageType,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? senderType,
    String? receiverType,
    String? messageText,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentName,
    String? messageType,
    bool? isRead,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? locationLink,
    String? locationAddress,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderType: senderType ?? this.senderType,
      receiverType: receiverType ?? this.receiverType,
      messageText: messageText ?? this.messageText,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      attachmentName: attachmentName ?? this.attachmentName,
      messageType: messageType ?? this.messageType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      locationLink: locationLink ?? this._locationLink,
      locationAddress: locationAddress ?? this._locationAddress,
    );
  }

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get hasText => messageText != null && messageText!.isNotEmpty;

  String? get locationLink {
    // First check if we have the location link from joined data
    if (_locationLink != null) {
      return _locationLink;
    }
    
    // Fallback to extracting from message text
    if (messageType == 'location') {
      // Try to extract location link from message text if it contains a URL
      if (messageText != null && messageText!.contains('https://www.google.com/maps')) {
        final urlRegex = RegExp(r'https://www\.google\.com/maps[^\s]+');
        final match = urlRegex.firstMatch(messageText!);
        if (match != null) {
          return match.group(0);
        }
      }
    }
    return null;
  }

  String? get locationAddress {
    // First check if we have the location address from joined data
    if (_locationAddress != null) {
      return _locationAddress;
    }
    
    // Fallback to extracting from message text
    if (messageType == 'location') {
      // For location messages, the address is typically stored in the messageText
      // but we want to exclude any URLs that might be in the text
      if (messageText != null) {
        // Remove any URLs from the text to get just the address
        final cleanText = messageText!.replaceAll(RegExp(r'https://[^\s]+'), '').trim();
        if (cleanText.isNotEmpty) {
          return cleanText;
        }
      }
    }
    return null;
  }
}
