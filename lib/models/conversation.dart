class Conversation {
  final String id;
  final String userId;
  final String? title;
  final Map<String, dynamic> context;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastMessageAt;
  final int messageCount;
  final String? lastMessage;

  Conversation({
    required this.id,
    required this.userId,
    this.title,
    required this.context,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    required this.messageCount,
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      context: json['context'] is Map ? Map<String, dynamic>.from(json['context']) : {},
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastMessageAt: DateTime.parse(json['last_message_at']),
      messageCount: json['message_count'] ?? 0,
      lastMessage: json['last_message'],
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(lastMessageAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}

class Message {
  final String id;
  final String conversationId;
  final String role;
  final String content;
  final Map<String, dynamic>? layoutJson;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.layoutJson,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversation_id'],
      role: json['role'],
      content: json['content'],
      layoutJson: json['layout_json'] is Map ? Map<String, dynamic>.from(json['layout_json']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}
