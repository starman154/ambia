import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveActivityService {
  static const platform = MethodChannel('com.ambia.live_activity');
  static const String _backendUrl =
      'https://ambia-prod.eba-hwjnqmy5.us-east-2.elasticbeanstalk.com/api/ambient';

  // Singleton pattern
  static final LiveActivityService _instance = LiveActivityService._internal();
  factory LiveActivityService() => _instance;

  late final http.Client _httpClient;

  String? _deviceToken;
  String? _userId;

  // Callback for when a Live Activity is tapped
  Function(String eventId)? onLiveActivityTapped;

  LiveActivityService._internal() {
    // Create HTTP client that accepts bad certificates (for development)
    final httpClient = HttpClient()
      ..badCertificateCallback = (cert, host, port) => true;
    _httpClient = IOClient(httpClient);

    _init();
  }

  /// Initialize the service and listen for device token
  Future<void> _init() async {
    // Get userId from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId') ?? '410b2520-e011-70d9-1ef0-10cead18dedd';

    // Set up method call handler for native -> Flutter communication
    platform.setMethodCallHandler(_handleMethodCall);

    print('[LiveActivity] Service initialized for user: $_userId');

    // Do initial sync
    print('[LiveActivity] Triggering initial sync...');
    await syncActiveEvents();

    // Set up periodic sync every 5 minutes
    print('[LiveActivity] Setting up periodic sync (every 5 minutes)');
    Stream.periodic(const Duration(minutes: 5)).listen((_) {
      print('[LiveActivity] Periodic sync triggered');
      syncActiveEvents();
    });
  }

  /// Handle method calls from native iOS code
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceTokenReceived':
        _deviceToken = call.arguments as String?;
        print('[LiveActivity] Device token received: $_deviceToken');
        if (_deviceToken != null) {
          await registerDevice(_deviceToken!);
        }
        break;
      case 'onLiveActivityTapped':
        final eventId = call.arguments as String?;
        print('[LiveActivity] Live Activity tapped for event: $eventId');
        if (eventId != null && onLiveActivityTapped != null) {
          onLiveActivityTapped!(eventId);
        }
        break;
      default:
        print('[LiveActivity] Unknown method: ${call.method}');
    }
  }

  /// Register device token with backend
  Future<void> registerDevice(String deviceToken) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$_backendUrl/devices/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'deviceToken': deviceToken,
          'deviceType': 'ios',
          'notificationsEnabled': true,
          'liveActivitiesEnabled': true,
          'dynamicIslandEnabled': true,
        }),
      );

      if (response.statusCode == 200) {
        print('[LiveActivity] ✅ Device registered with backend');
      } else {
        print('[LiveActivity] ❌ Failed to register device: ${response.statusCode}');
      }
    } catch (e) {
      print('[LiveActivity] ❌ Error registering device: $e');
    }
  }

  /// Start a Live Activity with event data
  Future<String?> startLiveActivity(Map<String, dynamic> eventData) async {
    try {
      print('[LiveActivity] Starting Live Activity with data: ${eventData['title']}');

      final activityId = await platform.invokeMethod<String>(
        'startLiveActivity',
        eventData,
      );

      print('[LiveActivity] ✅ Live Activity started: $activityId');
      return activityId;
    } on PlatformException catch (e) {
      print('[LiveActivity] ❌ Error starting Live Activity: ${e.message}');
      return null;
    }
  }

  /// Update an active Live Activity
  Future<void> updateLiveActivity(Map<String, dynamic> eventData) async {
    try {
      print('[LiveActivity] Updating Live Activity');

      await platform.invokeMethod('updateLiveActivity', eventData);

      print('[LiveActivity] ✅ Live Activity updated');
    } on PlatformException catch (e) {
      print('[LiveActivity] ❌ Error updating Live Activity: ${e.message}');
    }
  }

  /// End the current Live Activity
  Future<void> endLiveActivity() async {
    try {
      print('[LiveActivity] Ending Live Activity');

      await platform.invokeMethod('endLiveActivity');

      print('[LiveActivity] ✅ Live Activity ended');
    } on PlatformException catch (e) {
      print('[LiveActivity] ❌ Error ending Live Activity: ${e.message}');
    }
  }

  /// Get all active Live Activities
  Future<List<Map<String, dynamic>>> getActiveActivities() async {
    try {
      final result = await platform.invokeMethod('getActiveActivities');

      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      }

      return [];
    } on PlatformException catch (e) {
      print('[LiveActivity] ❌ Error getting active activities: ${e.message}');
      return [];
    }
  }

  /// Fetch active events from backend and start Live Activities for them
  Future<void> syncActiveEvents() async {
    try {
      print('[LiveActivity] ========== SYNC ACTIVE EVENTS ==========');

      final response = await _httpClient.get(
        Uri.parse('$_backendUrl/events/$_userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print('[LiveActivity] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final events = data['events'] as List;

        print('[LiveActivity] Found ${events.length} ambient events');

        if (events.isEmpty) {
          print('[LiveActivity] No active events to display');
          return;
        }

        // Get the highest priority event
        final sortedEvents = List<Map<String, dynamic>>.from(events);
        sortedEvents.sort((a, b) {
          final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
          final aPriority = priorityOrder[a['priority']] ?? 0;
          final bPriority = priorityOrder[b['priority']] ?? 0;
          return bPriority.compareTo(aPriority);
        });

        final topEvent = sortedEvents.first;

        print('[LiveActivity] Starting Live Activity for: ${topEvent['title']}');

        // Start Live Activity with the event
        await startLiveActivity(topEvent);

        // Track interaction
        await _trackInteraction(topEvent['id'], 'shown');

        print('[LiveActivity] ✅ Live Activity started for ambient event');
      } else {
        print('[LiveActivity] ❌ Failed to fetch events: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('[LiveActivity] ❌ Error syncing events: $e');
      print('[LiveActivity] Stack trace: $stackTrace');
    }
  }

  /// Track interaction with an event
  Future<void> _trackInteraction(String eventId, String interactionType) async {
    try {
      await _httpClient.post(
        Uri.parse('$_backendUrl/events/$eventId/interact'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'interactionType': interactionType,
          'metadata': {},
        }),
      );

      print('[LiveActivity] ✅ Tracked $interactionType interaction for event $eventId');
    } catch (e) {
      print('[LiveActivity] ❌ Error tracking interaction: $e');
    }
  }

  /// Schedule periodic sync of ambient events
  Future<void> startPeriodicSync() async {
    print('[LiveActivity] Starting periodic sync (every 5 minutes)');

    // Immediate sync
    await syncActiveEvents();

    // Schedule periodic sync
    // Note: In production, you'd use a background task scheduler
    // For now, the app needs to be running for this to work
    Future.delayed(const Duration(minutes: 5), () async {
      await syncActiveEvents();
      await startPeriodicSync(); // Recursive call to continue scheduling
    });
  }
}
