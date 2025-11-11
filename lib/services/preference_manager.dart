import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preference.dart';

class PreferenceManager {
  static final PreferenceManager _instance = PreferenceManager._internal();
  factory PreferenceManager() => _instance;
  PreferenceManager._internal();

  static const String _preferencesKey = 'user_preferences';
  static const String _conversationMemoryKey = 'conversation_memory';

  List<UserPreference> _preferences = [];
  List<ConversationMemory> _conversationHistory = [];

  // Initialize and load preferences from storage
  Future<void> initialize() async {
    await _loadPreferences();
    await _loadConversationHistory();
  }

  // Load preferences from SharedPreferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? prefsJson = prefs.getString(_preferencesKey);

      if (prefsJson != null) {
        final List<dynamic> decoded = jsonDecode(prefsJson);
        _preferences = decoded
            .map((json) => UserPreference.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Error loading preferences: $e');
      _preferences = [];
    }
  }

  // Load conversation history from SharedPreferences
  Future<void> _loadConversationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? historyJson = prefs.getString(_conversationMemoryKey);

      if (historyJson != null) {
        final List<dynamic> decoded = jsonDecode(historyJson);
        _conversationHistory = decoded
            .map((json) => ConversationMemory.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('Error loading conversation history: $e');
      _conversationHistory = [];
    }
  }

  // Save preferences to SharedPreferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        _preferences.map((pref) => pref.toJson()).toList(),
      );
      await prefs.setString(_preferencesKey, encoded);
    } catch (e) {
      print('Error saving preferences: $e');
    }
  }

  // Save conversation history to SharedPreferences
  Future<void> _saveConversationHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        _conversationHistory.map((memory) => memory.toJson()).toList(),
      );
      await prefs.setString(_conversationMemoryKey, encoded);
    } catch (e) {
      print('Error saving conversation history: $e');
    }
  }

  // Add a new preference
  Future<void> addPreference(UserPreference preference) async {
    // Check if a similar preference already exists and update it
    final existingIndex = _preferences.indexWhere(
      (p) => p.category == preference.category &&
             p.context == preference.context &&
             p.preference == preference.preference,
    );

    if (existingIndex != -1) {
      // Update existing preference, increasing its strength
      final existing = _preferences[existingIndex];
      _preferences[existingIndex] = existing.copyWith(
        strength: (existing.strength + 1).clamp(1, 10),
        description: preference.description,
      );
    } else {
      _preferences.add(preference);
    }

    await _savePreferences();
  }

  // Add a conversation to memory
  Future<void> addConversationMemory(ConversationMemory memory) async {
    _conversationHistory.add(memory);

    // Keep only the last 50 conversations to avoid excessive storage
    if (_conversationHistory.length > 50) {
      _conversationHistory = _conversationHistory.skip(_conversationHistory.length - 50).toList();
    }

    await _saveConversationHistory();
  }

  // Update the last conversation memory with user feedback
  Future<void> updateLastConversationFeedback(String feedback) async {
    if (_conversationHistory.isNotEmpty) {
      final last = _conversationHistory.last;
      _conversationHistory[_conversationHistory.length - 1] = last.copyWith(
        userFeedback: feedback,
      );
      await _saveConversationHistory();
    }
  }

  // Get preferences for a specific context
  List<UserPreference> getPreferencesForContext(String context) {
    return _preferences
        .where((p) => p.context == context || p.context == 'general')
        .toList()
      ..sort((a, b) => b.strength.compareTo(a.strength)); // Sort by strength
  }

  // Get all preferences
  List<UserPreference> getAllPreferences() {
    return List.unmodifiable(_preferences);
  }

  // Get recent conversation history
  List<ConversationMemory> getRecentConversations({int limit = 10}) {
    final conversations = _conversationHistory.reversed.take(limit).toList();
    return conversations.reversed.toList();
  }

  // Get last conversation
  ConversationMemory? getLastConversation() {
    return _conversationHistory.isNotEmpty ? _conversationHistory.last : null;
  }

  // Clear all preferences (useful for testing or reset)
  Future<void> clearAllPreferences() async {
    _preferences.clear();
    _conversationHistory.clear();
    await _savePreferences();
    await _saveConversationHistory();
  }

  // Get a formatted string of preferences for inclusion in prompts
  String getPreferencesPromptSection() {
    if (_preferences.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('\nUSER\'S LEARNED PREFERENCES:');
    buffer.writeln('Based on previous interactions, the user has expressed these preferences:');

    // Group preferences by category
    final grouped = <String, List<UserPreference>>{};
    for (final pref in _preferences) {
      grouped.putIfAbsent(pref.category, () => []).add(pref);
    }

    for (final category in grouped.keys) {
      buffer.writeln('\n${category.toUpperCase()}:');
      for (final pref in grouped[category]!) {
        final strengthIndicator = '★' * ((pref.strength / 2).round());
        buffer.writeln('  $strengthIndicator ${pref.description} (${pref.preference})');
      }
    }

    buffer.writeln('\nAPPLY THESE PREFERENCES when generating components.');

    return buffer.toString();
  }

  // Analyze user feedback and extract preferences
  // This will be called when Ambia detects feedback language
  Future<List<UserPreference>> extractPreferencesFromFeedback({
    required String userFeedback,
    required String originalQuery,
    String context = 'general',
  }) async {
    final preferences = <UserPreference>[];
    final timestamp = DateTime.now();

    // Simple keyword-based preference extraction
    // In a production system, you might use Claude API to analyze this more intelligently

    final feedback = userFeedback.toLowerCase();

    // Visual/Layout preferences
    if (feedback.contains('cleaner') || feedback.contains('clean')) {
      preferences.add(UserPreference(
        id: '${timestamp.millisecondsSinceEpoch}_clean',
        category: 'visualization',
        preference: 'cleaner',
        context: context,
        description: 'User prefers cleaner, more minimal layouts',
        createdAt: timestamp,
        strength: 5,
      ));
    }

    if (feedback.contains('organized') || feedback.contains('organize')) {
      preferences.add(UserPreference(
        id: '${timestamp.millisecondsSinceEpoch}_organized',
        category: 'layout',
        preference: 'organized',
        context: context,
        description: 'User prefers well-organized, structured layouts',
        createdAt: timestamp,
        strength: 5,
      ));
    }

    if (feedback.contains('minimal') || feedback.contains('minimalist')) {
      preferences.add(UserPreference(
        id: '${timestamp.millisecondsSinceEpoch}_minimal',
        category: 'visualization',
        preference: 'minimalist',
        context: context,
        description: 'User prefers minimalist design approach',
        createdAt: timestamp,
        strength: 5,
      ));
    }

    if (feedback.contains('more detail') || feedback.contains('detailed')) {
      preferences.add(UserPreference(
        id: '${timestamp.millisecondsSinceEpoch}_detailed',
        category: 'data_presentation',
        preference: 'detailed',
        context: context,
        description: 'User prefers more detailed information',
        createdAt: timestamp,
        strength: 5,
      ));
    }

    if (feedback.contains('simpler') || feedback.contains('simple')) {
      preferences.add(UserPreference(
        id: '${timestamp.millisecondsSinceEpoch}_simple',
        category: 'data_presentation',
        preference: 'simple',
        context: context,
        description: 'User prefers simpler, less complex presentations',
        createdAt: timestamp,
        strength: 5,
      ));
    }

    if (feedback.contains('compact')) {
      preferences.add(UserPreference(
        id: '${timestamp.millisecondsSinceEpoch}_compact',
        category: 'layout',
        preference: 'compact',
        context: context,
        description: 'User prefers compact layouts with less spacing',
        createdAt: timestamp,
        strength: 5,
      ));
    }

    if (feedback.contains('spacious') || feedback.contains('more space')) {
      preferences.add(UserPreference(
        id: '${timestamp.millisecondsSinceEpoch}_spacious',
        category: 'layout',
        preference: 'spacious',
        context: context,
        description: 'User prefers spacious layouts with more breathing room',
        createdAt: timestamp,
        strength: 5,
      ));
    }

    // Save all extracted preferences
    for (final pref in preferences) {
      await addPreference(pref);
    }

    return preferences;
  }
}
