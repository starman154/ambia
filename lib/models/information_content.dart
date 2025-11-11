enum ContentType {
  flight,
  meeting,
  task,
  reminder,
  event,
  weather,
  // More types as we expand
}

class InformationContent {
  final ContentType type;
  final String id;
  final int priority; // 0-100, higher = more important
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final List<String> predictions; // AI-generated contextual info

  InformationContent({
    required this.type,
    required this.id,
    required this.priority,
    required this.data,
    required this.timestamp,
    this.predictions = const [],
  });

  // Factory constructor for JSON parsing
  factory InformationContent.fromJson(Map<String, dynamic> json) {
    return InformationContent(
      type: ContentType.values.firstWhere(
        (e) => e.toString() == 'ContentType.${json['type']}',
      ),
      id: json['id'],
      priority: json['priority'],
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
      predictions: List<String>.from(json['predictions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'id': id,
      'priority': priority,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'predictions': predictions,
    };
  }
}
