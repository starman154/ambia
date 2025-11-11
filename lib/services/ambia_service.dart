import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import '../models/layout_spec.dart';
import '../models/ambient_component.dart';
import '../models/user_preference.dart';
import './preference_manager.dart';

class AmbiaService {
  // Backend API endpoint (proxy to Claude)
  static const String _backendUrl = 'https://ambia-prod.eba-hwjnqmy5.us-east-2.elasticbeanstalk.com/api/ambia';

  // Fallback to direct Claude API if backend is unavailable
  static const String _claudeApiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-5-20250929';

  final String _apiKey;
  final PreferenceManager _preferenceManager = PreferenceManager();

  // Hardcoded user ID for now - in production this would come from auth
  static const String _userId = '410b2520-e011-70d9-1ef0-10cead18dedd';

  AmbiaService() : _apiKey = dotenv.env['CLAUDE_API_KEY'] ?? '' {
    _preferenceManager.initialize();
  }

  /// Create HTTP client that accepts self-signed certificates (for development)
  /// TODO: Remove this in production and use proper SSL certificates
  http.Client _createHttpClient() {
    final httpClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Allow self-signed certificates for our backend
        return host == 'ambia-prod.eba-hwjnqmy5.us-east-2.elasticbeanstalk.com';
      };
    return IOClient(httpClient);
  }

  Future<List<TimelineItem>> generateLayout(String userQuery) async {
    try {
      final response = await http.post(
        Uri.parse(_claudeApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 4096,
          'messages': [
            {
              'role': 'user',
              'content': _buildPrompt(userQuery),
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['content'][0]['text'];

        // Parse the JSON response
        return _parseLayoutResponse(content);
      } else {
        throw Exception('API call failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error generating layout: $e');
    }
  }

  /// NEW: Generate dynamic UI components (component system)
  Future<Map<String, dynamic>> generateComponents(String userQuery, {String? conversationId}) async {
    final client = _createHttpClient();
    try {
      // Get user preferences to send to backend
      final allPreferences = _preferenceManager.getAllPreferences();
      final preferences = allPreferences.map((pref) => {
        'category': pref.category,
        'preference': pref.preference,
        'context': pref.context,
        'description': pref.description,
        'strength': pref.strength,
      }).toList();

      print('Calling backend API: $_backendUrl/generate');
      if (conversationId != null) {
        print('With conversation ID: $conversationId');
      }

      final response = await client.post(
        Uri.parse('$_backendUrl/generate'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': _userId,
          'conversationId': conversationId,
          'userQuery': userQuery,
          'preferences': preferences,
        }),
      );

      print('Backend response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final components = (data['components'] as List)
              .map((json) => AmbientComponent.fromJson(json))
              .toList();

          final returnedConversationId = data['conversationId'] as String?;

          // DEBUG: Print components
          print('\n=== RECEIVED ${components.length} COMPONENTS FROM BACKEND ===');
          for (var comp in components) {
            print('Component: ${comp.type} - ${comp.id}');
          }
          if (returnedConversationId != null) {
            print('Conversation ID: $returnedConversationId');
          }
          print('=== END COMPONENTS ===\n');

          // Save this conversation to memory (local)
          await _preferenceManager.addConversationMemory(
            ConversationMemory(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              userQuery: userQuery,
              generatedComponents: components.map((c) => c.toJson()).toList(),
              timestamp: DateTime.now(),
            ),
          );

          return {
            'components': components,
            'conversationId': returnedConversationId,
          };
        } else {
          throw Exception('Backend returned error: ${data['error']}');
        }
      } else {
        throw Exception('Backend API call failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error generating components: $e');
      throw Exception('Error generating components: $e');
    } finally {
      client.close();
    }
  }

  List<AmbientComponent> _parseComponentResponse(String jsonResponse) {
    try {
      // Clean the response
      String cleaned = jsonResponse.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      }
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      // DEBUG: Print cleaned JSON
      print('\n=== CLEANED JSON ===');
      print(cleaned);
      print('=== END CLEANED JSON ===\n');

      final parsed = jsonDecode(cleaned);

      // Handle both array format and object with 'components' key
      final components = parsed is List ? parsed : (parsed['components'] as List);

      // DEBUG: Check for chart components
      for (var comp in components) {
        if (comp['type'] == 'chart') {
          print('\n=== CHART COMPONENT FOUND ===');
          print('Chart ID: ${comp['id']}');
          print('Chart Data: ${comp['data']}');
          print('DataPoints: ${comp['data']?['dataPoints']}');
          print('=== END CHART DEBUG ===\n');
        }
      }

      return components.map((json) => AmbientComponent.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to parse component response: $e\nResponse: $jsonResponse');
    }
  }

  String _buildComponentPrompt(String userQuery) {
    // Get user's learned preferences
    final preferencesSection = _preferenceManager.getPreferencesPromptSection();

    return '''You are Ambia, an ambient AI that generates beautiful, dynamic interfaces with COMPLETE information.

User Query: "$userQuery"

CRITICAL PRINCIPLES:
1. PROVIDE ALL REQUESTED INFORMATION - If user asks for a list of 8 movies, generate ALL 8 movies with details
2. FULFILL THE ENTIRE REQUEST - Don't create summary UIs without the actual data
3. COMPONENTS SHOULD CONTAIN DATA - Each component must have real, complete information
4. Think like both an AI assistant AND a UI designer - deliver information beautifully
$preferencesSection

Your task is to generate a JSON array of UI components that FULLY answer the user's query with complete data.

COMPONENT TYPES AVAILABLE:

1. DATA DISPLAY
   - header: Large prominent headers with badges/icons
   - text: Body text with formatting
   - metric: Single stat with label, value, change indicator
   - stat: Multiple stats in a row
   - progress: Progress bars with labels

2. LISTS
   - list: Simple text items
   - person_list: People with avatars, roles, status
   - timeline: Events with timestamps

3. ACTIONS
   - button: Single action button
   - action_row: Multiple buttons in a row
   - chip_row: Tag/chip row

4. MEDIA
   - image: Single image
   - gallery: Scrollable image gallery
   - map: Location map

5. CONTEXTUAL
   - weather: Weather display
   - location: Location info
   - calendar_event: Event with time, attendees

6. VISUAL
   - chart: Data visualization
   - sparkline: Trend indicator

7. CONTAINERS
   - card: Group components
   - section: Titled section

RESPONSE FORMAT:
Return a JSON array of components. Each component has:
{
  "type": "component_type",
  "id": "unique_id",
  "data": {
    // Component-specific data
  },
  "style": {
    "variant": "primary|secondary|urgent|subtle",
    "size": "small|medium|large"
  },
  "actions": [{
    "type": "action_type",
    "params": {}
  }]
}

DESIGN RULES:
1. BE CREATIVE - Every interface should feel unique
2. Combine components cleverly (e.g., header + person_list + action_row for meeting prep)
3. Use appropriate variants: "urgent" for time-sensitive, "primary" for main actions
4. THINK ABOUT CONTEXT - What would the user need to see/do?
5. Keep it clean - Usually 2-4 components max

EXAMPLES:

Query: "I have a meeting in 15 minutes with Sarah"
Response: [
  {
    "type": "header",
    "id": "meeting_header",
    "data": {
      "title": "Meeting in 15 min",
      "subtitle": "Product Review",
      "badge": "Soon",
      "icon": "calendar"
    },
    "style": {"variant": "urgent"}
  },
  {
    "type": "person_list",
    "id": "attendees",
    "data": {
      "title": "Attendees",
      "people": [
        {"name": "Sarah Chen", "role": "PM", "status": "confirmed"},
        {"name": "Mike Ross", "role": "Engineering", "status": "maybe"}
      ]
    }
  },
  {
    "type": "action_row",
    "id": "actions",
    "data": {
      "buttons": [
        {"label": "Join Zoom", "action": {"type": "open_url", "params": {"url": "zoom://join"}}},
        {"label": "View Agenda", "action": {"type": "open_url", "params": {"url": "notion://"}}}
      ]
    }
  }
]

Query: "What's the weather?"
Response: [
  {
    "type": "weather",
    "id": "weather_001",
    "data": {
      "condition": "Partly Cloudy",
      "temperature": 72,
      "location": "San Francisco",
      "icon": "wb_sunny"
    }
  },
  {
    "type": "text",
    "id": "forecast",
    "data": {
      "content": "Perfect day for a walk. Expect sunshine until 5 PM."
    }
  }
]

Query: "hello"
Response: [
  {
    "type": "header",
    "id": "greeting",
    "data": {
      "title": "Hey there!",
      "subtitle": "I'm Ambia. What can I help you with?"
    },
    "style": {"variant": "primary"}
  },
  {
    "type": "chip_row",
    "id": "suggestions",
    "data": {
      "chips": [
        {"label": "Weather"},
        {"label": "Time"},
        {"label": "Calendar"}
      ]
    }
  }
]

Query: "give me a list of movies to watch. include details about them. im a space guy"
Response: [
  {
    "type": "header",
    "id": "space_movies_header",
    "data": {
      "title": "Space Cinema Collection",
      "subtitle": "Epic films for the cosmic explorer",
      "badge": "8 Films",
      "icon": "rocket_launch"
    },
    "style": {"variant": "primary"}
  },
  {
    "type": "list",
    "id": "movie_list",
    "data": {
      "items": [
        {"text": "Interstellar (2014) - Christopher Nolan's masterpiece about humanity's survival through wormholes. IMDb: 8.7"},
        {"text": "2001: A Space Odyssey (1968) - Stanley Kubrick's visionary exploration of evolution and AI. IMDb: 8.3"},
        {"text": "Gravity (2013) - Alfonso Cuarón's intense survival story in orbit. IMDb: 7.7"},
        {"text": "The Martian (2015) - Ridley Scott's scientifically accurate tale of Mars survival. IMDb: 8.0"},
        {"text": "Apollo 13 (1995) - Ron Howard's true story of NASA's finest hour. IMDb: 7.7"},
        {"text": "Arrival (2016) - Denis Villeneuve's thoughtful first contact drama. IMDb: 7.9"},
        {"text": "Contact (1997) - Robert Zemeckis' adaptation of Carl Sagan's vision. IMDb: 7.5"},
        {"text": "Ad Astra (2019) - James Gray's introspective journey to Neptune. IMDb: 6.5"}
      ]
    }
  },
  {
    "type": "chip_row",
    "id": "genres",
    "data": {
      "chips": [
        {"label": "Hard Sci-Fi"},
        {"label": "Space Drama"},
        {"label": "True Story"},
        {"label": "First Contact"}
      ]
    }
  },
  {
    "type": "action_row",
    "id": "actions",
    "data": {
      "buttons": [
        {"label": "Save List"},
        {"label": "Find Streaming"}
      ]
    }
  }
]

Query: "show me a chart of ai use from 2020 to 2025"
Response: [
  {
    "type": "header",
    "id": "ai_header",
    "data": {
      "title": "AI Adoption Growth",
      "subtitle": "Global usage trends 2020-2025"
    },
    "style": {"variant": "primary"}
  },
  {
    "type": "metric",
    "id": "current_rate",
    "data": {
      "label": "Current Adoption Rate",
      "value": "67",
      "unit": "%",
      "change": "+52% since 2020"
    }
  },
  {
    "type": "chart",
    "id": "ai_adoption_chart",
    "data": {
      "title": "Adoption Growth",
      "chartType": "line",
      "dataPoints": [
        {"x": "2020", "y": 15},
        {"x": "2021", "y": 28},
        {"x": "2022", "y": 42},
        {"x": "2023", "y": 58},
        {"x": "2024", "y": 67},
        {"x": "2025", "y": 78}
      ]
    }
  },
  {
    "type": "stat",
    "id": "breakdown",
    "data": {
      "stats": [
        {"label": "Enterprise AI", "value": "89%"},
        {"label": "Consumer Apps", "value": "71%"},
        {"label": "Creative Tools", "value": "58%"}
      ]
    }
  }
]

CHART COMPONENT STRUCTURE:
CRITICAL: When using "chart" type, you MUST include dataPoints with actual numeric data.
{
  "type": "chart",
  "id": "unique_id",
  "data": {
    "title": "Chart Title (optional)",
    "chartType": "line",
    "dataPoints": [
      {"x": "Label1", "y": 10.5},
      {"x": "Label2", "y": 15.2},
      {"x": "Label3", "y": 20.8}
    ]
  }
}

IMPORTANT:
- dataPoints array is REQUIRED and must have at least 2 data points
- Each point needs both "x" (label) and "y" (numeric value)
- Use realistic data based on the user's query
- For forecasts/trends, calculate reasonable projections

NOW: Generate components for the user's query. Return ONLY valid JSON, no other text.
Think about what interface would be most useful for this context.''';
  }

  String _buildPrompt(String userQuery) {
    return '''You are Ambia, an ambient AI that presents information in beautiful, creative ways.

User Query: "$userQuery"

CRITICAL RULES:
1. ONLY answer what was asked - nothing more
2. If user asks for time, show ONLY time (not date)
3. If user asks for weather, show ONLY weather
4. For greetings (hi, hello, hey), respond naturally as an ambient AI - be warm but purposeful
   - Example responses: "Hey there! What can I help you with?", "Hello! Ready to assist.", "Hi! I'm here for you."
5. Be HIGHLY creative with visual design - vary colors, gradients, layouts, heights
6. NEVER reuse the same visual style twice
7. Each generation should look completely different
8. Heights should fit content - short content = shorter cards (100-140px), detailed content = taller cards (180-240px)

Your task:
1. Answer the user's query with accurate, helpful information
2. Present it as a JSON array of ambient cards (usually 1-2 cards, not more unless necessary)
3. Each card should be visually UNIQUE and CREATIVE
4. Experiment with different color combinations from the brand palette
5. Be selective and minimalist - show only what's needed

LayoutSpec Format:
{
  "items": [
    {
      "id": "unique_id",
      "type": "category (time, weather, info, etc)",
      "template": "hero | detailed | compact",
      "priority": 90,
      "visual": {
        "background": "gradient | solid",
        "colors": ["#FF6B35", "#EC4899", "#8B5CF6"],
        "height": 180,
        "corners": "rounded_32 | rounded_24 | rounded_16",
        "glassmorphism": true,
        "blur": 20,
        "opacity": 0.08
      },
      "contentBlocks": [
        {
          "type": "headline | detail | action | temperature | custom",
          "size": "hero | large | medium | small",
          "animation": "gentle_pulse | none",
          "data": {
            "text": "Display text",
            "icon": "icon_name"
          }
        }
      ]
    }
  ]
}

Available Content Block Types:
- "headline": Large text headers
- "detail": Smaller descriptive text with optional icons
- "action": Actionable buttons
- "temperature": Special large number display (for temps, times, counts)
- "custom": Any other text content

Brand Colors (use these in gradients and solids):
- Orange: #FF6B35
- Pink: #EC4899
- Magenta: #C026D3
- Purple: #8B5CF6
- Dark Gray: #1C1C1E, #2C2C2E

Design Philosophy:
- EXTREME creativity - every card should feel fresh and different
- Vary gradient directions and color combinations wildly
- Mix gradient and solid backgrounds strategically
- Heights: 100-140px for compact info, 160-240px for detailed content
- Always use glassmorphism for depth
- Animate hero elements with gentle_pulse sparingly
- Keep it clean and Apple-styled but NEVER repetitive
- Try unusual color pairings: purple+orange, pink+purple, orange+magenta, etc.
- Experiment with 2-color vs 3-color gradients

Icons (use Flutter Icons class names):
- Icons.access_time, Icons.wb_sunny, Icons.cloud, Icons.flight, Icons.local_shipping
- Icons.calendar_today, Icons.notifications, Icons.place, Icons.restaurant
- Icons.traffic, Icons.ac_unit, Icons.sports_basketball, etc.

IMPORTANT:
- Return ONLY valid JSON, no other text
- Answer the actual query (e.g., "what time is it" should show current time)
- Be creative with each generation
- Keep layouts clean and readable
- Use appropriate heights for content amount

Example 1 - "what time is it" (compact, single card):
{
  "items": [
    {
      "id": "time_001",
      "type": "time",
      "template": "hero",
      "priority": 95,
      "visual": {
        "background": "gradient",
        "colors": ["#8B5CF6", "#C026D3"],
        "height": 140,
        "corners": "rounded_24",
        "glassmorphism": true
      },
      "contentBlocks": [
        {
          "type": "temperature",
          "size": "hero",
          "animation": "gentle_pulse",
          "data": {
            "temperature": "8:42",
            "condition": "PM"
          }
        }
      ]
    }
  ]
}

Example 2 - "hello" (natural AI greeting):
{
  "items": [
    {
      "id": "greeting_001",
      "type": "greeting",
      "template": "compact",
      "priority": 80,
      "visual": {
        "background": "gradient",
        "colors": ["#FF6B35", "#EC4899"],
        "height": 110,
        "corners": "rounded_24",
        "glassmorphism": true
      },
      "contentBlocks": [
        {
          "type": "headline",
          "size": "medium",
          "data": {
            "text": "Hey! What can I help you with?"
          }
        }
      ]
    }
  ]
}

Now answer the user's query creatively!''';
  }

  List<TimelineItem> _parseLayoutResponse(String jsonResponse) {
    try {
      // Clean the response - remove any markdown code blocks
      String cleaned = jsonResponse.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      }
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final parsed = jsonDecode(cleaned);
      final items = parsed['items'] as List;

      return items.map((item) => _parseTimelineItem(item)).toList();
    } catch (e) {
      throw Exception('Failed to parse layout response: $e');
    }
  }

  TimelineItem _parseTimelineItem(Map<String, dynamic> json) {
    return TimelineItem(
      id: json['id'],
      type: json['type'],
      template: json['template'],
      priority: json['priority'],
      visual: _parseVisualStyle(json['visual']),
      contentBlocks: (json['contentBlocks'] as List)
          .map((block) => _parseContentBlock(block))
          .toList(),
    );
  }

  VisualStyle _parseVisualStyle(Map<String, dynamic> json) {
    return VisualStyle(
      background: json['background'],
      colors: List<String>.from(json['colors']),
      height: (json['height'] as num).toDouble(),
      corners: json['corners'],
      glassmorphism: json['glassmorphism'] ?? true,
      blur: json['blur']?.toDouble(),
      opacity: json['opacity']?.toDouble(),
    );
  }

  ContentBlock _parseContentBlock(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;

    // Handle icon names - convert string to IconData
    if (data.containsKey('icon') && data['icon'] is String) {
      data['icon'] = _getIconFromName(data['icon']);
    }

    return ContentBlock(
      type: json['type'],
      size: json['size'] ?? 'medium',
      animation: json['animation'],
      data: data,
    );
  }

  IconData _getIconFromName(String iconName) {
    // Map string icon names to actual IconData
    final iconMap = {
      'access_time': Icons.access_time,
      'wb_sunny': Icons.wb_sunny,
      'cloud': Icons.cloud,
      'flight': Icons.flight,
      'local_shipping': Icons.local_shipping,
      'calendar_today': Icons.calendar_today,
      'notifications': Icons.notifications,
      'place': Icons.place,
      'restaurant': Icons.restaurant,
      'traffic': Icons.traffic,
      'ac_unit': Icons.ac_unit,
      'sports_basketball': Icons.sports_basketball,
      'sports_soccer': Icons.sports_soccer,
      'sports_football': Icons.sports_football,
      'music_note': Icons.music_note,
      'movie': Icons.movie,
      'checkroom': Icons.checkroom,
      'shopping_bag': Icons.shopping_bag,
      'attach_money': Icons.attach_money,
      'trending_up': Icons.trending_up,
      'show_chart': Icons.show_chart,
      'battery_charging_full': Icons.battery_charging_full,
      'directions_car': Icons.directions_car,
      'directions_walk': Icons.directions_walk,
      'fitness_center': Icons.fitness_center,
      'water_drop': Icons.water_drop,
      'emoji_events': Icons.emoji_events,
      'star': Icons.star,
      'favorite': Icons.favorite,
      'umbrella': Icons.umbrella,
      'nightlight': Icons.nightlight,
      'wb_twilight': Icons.wb_twilight,
    };

    return iconMap[iconName] ?? Icons.info;
  }

  /// Process user feedback on generated components
  /// This method detects feedback language and extracts preferences
  Future<bool> processFeedback(String feedbackText) async {
    try {
      // Update the last conversation with user feedback
      await _preferenceManager.updateLastConversationFeedback(feedbackText);

      // Get the last conversation to get context
      final lastConversation = _preferenceManager.getLastConversation();
      if (lastConversation == null) {
        return false;
      }

      // Extract preferences from the feedback
      await _preferenceManager.extractPreferencesFromFeedback(
        userFeedback: feedbackText,
        originalQuery: lastConversation.userQuery,
        context: 'general',
      );

      print('✓ Processed feedback and extracted preferences');
      return true;
    } catch (e) {
      print('Error processing feedback: $e');
      return false;
    }
  }

  /// Check if a message looks like feedback about the last generation
  bool isFeedbackMessage(String message) {
    final feedbackKeywords = [
      'cleaner',
      'clean',
      'organized',
      'organize',
      'minimal',
      'minimalist',
      'better',
      'worse',
      'prefer',
      'like',
      'dislike',
      'more detail',
      'detailed',
      'simpler',
      'simple',
      'compact',
      'spacious',
      'more space',
      'less',
      'too much',
      'not enough',
    ];

    final lowerMessage = message.toLowerCase();
    return feedbackKeywords.any((keyword) => lowerMessage.contains(keyword));
  }
}
