import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';

  // User methods
  static Future<Map<String, dynamic>> getOrCreateUser({
    required String deviceId,
    String? email,
    String? phoneNumber,
    String? displayName,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'deviceId': deviceId,
        'email': email,
        'phoneNumber': phoneNumber,
        'displayName': displayName,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to authenticate user');
  }

  // Conversation methods
  static Future<List<dynamic>> getUserConversations(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/conversations'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['conversations'] ?? [];
    }
    throw Exception('Failed to load conversations');
  }

  static Future<Map<String, dynamic>> getConversation(String conversationId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/conversations/$conversationId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['conversation'];
    }
    throw Exception('Failed to load conversation');
  }

  static Future<String> createConversation({
    required String userId,
    String? title,
    Map<String, dynamic>? context,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/conversations'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'title': title ?? 'New Conversation',
        'context': context ?? {},
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['conversationId'];
    }
    throw Exception('Failed to create conversation');
  }

  static Future<void> deleteConversation(String conversationId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/conversations/$conversationId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete conversation');
    }
  }

  // Message methods
  static Future<String> createMessage({
    required String conversationId,
    required String role,
    required String content,
    Map<String, dynamic>? layoutJson,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/messages'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'conversationId': conversationId,
        'role': role,
        'content': content,
        'layoutJson': layoutJson,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['messageId'];
    }
    throw Exception('Failed to create message');
  }

  // Interaction tracking
  static Future<void> trackInteraction({
    required String userId,
    required String conversationId,
    required String messageId,
    required String interactionType,
    int? cardIndex,
    Map<String, dynamic>? metadata,
  }) async {
    await http.post(
      Uri.parse('$baseUrl/interactions'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'conversationId': conversationId,
        'messageId': messageId,
        'interactionType': interactionType,
        'cardIndex': cardIndex,
        'metadata': metadata ?? {},
      }),
    );
  }
}
