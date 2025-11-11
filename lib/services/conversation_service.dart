import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/conversation_model.dart';

/// Conversation Service
/// Handles all API calls related to conversations
class ConversationService {
  static const String _baseUrl = 'http://ambia-prod.eba-hwjnqmy5.us-east-2.elasticbeanstalk.com/api';

  // Hardcoded user ID for now - in production this would come from auth
  static const String _userId = '410b2520-e011-70d9-1ef0-10cead18dedd';

  /// Get all conversations for the current user
  Future<List<ConversationModel>> getUserConversations() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$_userId/conversations'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final conversations = (data['conversations'] as List)
              .map((json) => ConversationModel.fromJson(json))
              .toList();
          return conversations;
        } else {
          throw Exception(data['error'] ?? 'Failed to fetch conversations');
        }
      } else {
        throw Exception('Failed to fetch conversations: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching conversations: $e');
      throw Exception('Error fetching conversations: $e');
    }
  }

  /// Get a specific conversation with all messages
  Future<ConversationWithMessages> getConversation(String conversationId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/conversations/$conversationId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return ConversationWithMessages.fromJson(data);
        } else {
          throw Exception(data['error'] ?? 'Failed to fetch conversation');
        }
      } else {
        throw Exception('Failed to fetch conversation: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching conversation: $e');
      throw Exception('Error fetching conversation: $e');
    }
  }

  /// Create a new conversation
  Future<String> createConversation({String? title}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/conversations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'title': title ?? 'New Conversation',
          'context': {},
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['conversationId'] as String;
        } else {
          throw Exception(data['error'] ?? 'Failed to create conversation');
        }
      } else {
        throw Exception('Failed to create conversation: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating conversation: $e');
      throw Exception('Error creating conversation: $e');
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/conversations/$conversationId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete conversation: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting conversation: $e');
      throw Exception('Error deleting conversation: $e');
    }
  }

  /// Send a message in a conversation and get AI response
  /// This wraps the existing Ambia service but includes conversation context
  Future<Map<String, dynamic>> sendMessage({
    String? conversationId,
    required String message,
    List<Map<String, dynamic>>? preferences,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/ambia/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'conversationId': conversationId,
          'userQuery': message,
          'preferences': preferences ?? [],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return {
            'conversationId': data['conversationId'],
            'messageId': data['messageId'],
            'components': data['components'],
            'metadata': data['metadata'],
          };
        } else {
          throw Exception(data['error'] ?? 'Failed to send message');
        }
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending message: $e');
      throw Exception('Error sending message: $e');
    }
  }
}
