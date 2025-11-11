class UserPreference {
  final String id;
  final String category; // e.g., "visualization", "layout", "data_presentation"
  final String preference; // e.g., "cleaner", "more_organized", "minimalist"
  final String context; // What type of query this applies to (e.g., "movie_list", "charts", "general")
  final String description; // Human-readable description of the preference
  final DateTime createdAt;
  final int strength; // 1-10, how strongly this preference should be applied

  UserPreference({
    required this.id,
    required this.category,
    required this.preference,
    required this.context,
    required this.description,
    required this.createdAt,
    this.strength = 5,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'preference': preference,
      'context': context,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'strength': strength,
    };
  }

  factory UserPreference.fromJson(Map<String, dynamic> json) {
    return UserPreference(
      id: json['id'],
      category: json['category'],
      preference: json['preference'],
      context: json['context'],
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
      strength: json['strength'] ?? 5,
    );
  }

  UserPreference copyWith({
    String? id,
    String? category,
    String? preference,
    String? context,
    String? description,
    DateTime? createdAt,
    int? strength,
  }) {
    return UserPreference(
      id: id ?? this.id,
      category: category ?? this.category,
      preference: preference ?? this.preference,
      context: context ?? this.context,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      strength: strength ?? this.strength,
    );
  }
}

class ConversationMemory {
  final String id;
  final String userQuery;
  final List<dynamic> generatedComponents; // The components that were generated
  final String? userFeedback; // User's feedback on this generation
  final DateTime timestamp;

  ConversationMemory({
    required this.id,
    required this.userQuery,
    required this.generatedComponents,
    this.userFeedback,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userQuery': userQuery,
      'generatedComponents': generatedComponents,
      'userFeedback': userFeedback,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ConversationMemory.fromJson(Map<String, dynamic> json) {
    return ConversationMemory(
      id: json['id'],
      userQuery: json['userQuery'],
      generatedComponents: json['generatedComponents'] ?? [],
      userFeedback: json['userFeedback'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  ConversationMemory copyWith({
    String? id,
    String? userQuery,
    List<dynamic>? generatedComponents,
    String? userFeedback,
    DateTime? timestamp,
  }) {
    return ConversationMemory(
      id: id ?? this.id,
      userQuery: userQuery ?? this.userQuery,
      generatedComponents: generatedComponents ?? this.generatedComponents,
      userFeedback: userFeedback ?? this.userFeedback,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
