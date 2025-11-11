/// Conversation Model
/// Represents a chat conversation with Ambia
class ConversationModel {
  final String id;
  final String userId;
  final String title;
  final Map<String, dynamic> context;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastMessageAt;
  final int messageCount;
  final String? lastMessage;

  ConversationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.context,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    this.messageCount = 0,
    this.lastMessage,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      title: json['title'] as String? ?? 'New Conversation',
      context: json['context'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessageAt: DateTime.parse(json['last_message_at'] as String),
      messageCount: json['message_count'] as int? ?? 0,
      lastMessage: json['last_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'context': context,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message_at': lastMessageAt.toIso8601String(),
      'message_count': messageCount,
      'last_message': lastMessage,
    };
  }

  /// Get a preview of the last message (first 60 characters)
  String get lastMessagePreview {
    if (lastMessage == null || lastMessage!.isEmpty) {
      return 'No messages yet';
    }
    if (lastMessage!.length <= 60) {
      return lastMessage!;
    }
    return '${lastMessage!.substring(0, 60)}...';
  }

  /// Get a relative time string for the last message
  String get lastMessageTimeAgo {
    final now = DateTime.now();
    final difference = now.difference(lastMessageAt);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastMessageAt.month}/${lastMessageAt.day}/${lastMessageAt.year}';
    }
  }
}

/// Message Model
/// Represents a single message in a conversation
class MessageModel {
  final String id;
  final String conversationId;
  final String userId;
  final String role; // 'user' or 'assistant'
  final String content;
  final List<dynamic>? layoutJson; // Components for assistant messages
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.userId,
    required this.role,
    required this.content,
    this.layoutJson,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      role: json['role'] as String,
      content: json['content'] as String,
      layoutJson: json['layout_json'] as List<dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'user_id': userId,
      'role': role,
      'content': content,
      'layout_json': layoutJson,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}

/// Conversation with full message history
class ConversationWithMessages {
  final ConversationModel conversation;
  final List<MessageModel> messages;

  ConversationWithMessages({
    required this.conversation,
    required this.messages,
  });

  factory ConversationWithMessages.fromJson(Map<String, dynamic> json) {
    final conversationData = json['conversation'] as Map<String, dynamic>;
    final messagesData = conversationData['messages'] as List<dynamic>?;

    return ConversationWithMessages(
      conversation: ConversationModel.fromJson({
        'id': conversationData['id'],
        'user_id': conversationData['user_id'],
        'title': conversationData['title'],
        'context': conversationData['context'],
        'created_at': conversationData['created_at'],
        'updated_at': conversationData['updated_at'],
        'last_message_at': conversationData['last_message_at'],
      }),
      messages: messagesData != null
          ? messagesData
              .map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
              .toList()
          : [],
    );
  }
}
