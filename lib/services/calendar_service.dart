import 'dart:convert';
import 'dart:io';
import 'package:device_calendar/device_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CalendarService {
  final DeviceCalendarPlugin _deviceCalendarPlugin = DeviceCalendarPlugin();

  static const String _backendUrl =
      'https://ambia-prod.eba-hwjnqmy5.us-east-2.elasticbeanstalk.com/api/calendar';
  static const String _calendarEnabledKey = 'calendar_enabled';
  static const String _lastSyncKey = 'calendar_last_sync';

  // Request calendar permissions
  Future<bool> requestPermissions() async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.hasPermissions();

      if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
        permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
        if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
          return false;
        }
      }

      return permissionsGranted.data ?? false;
    } catch (e) {
      print('Error requesting calendar permissions: $e');
      return false;
    }
  }

  // Get all calendars
  Future<List<Calendar>> getCalendars() async {
    try {
      final permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        return [];
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      return calendarsResult.data ?? [];
    } catch (e) {
      print('Error retrieving calendars: $e');
      return [];
    }
  }

  // Get events from a calendar within a date range
  Future<List<Event>> getEvents({
    required String calendarId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        return [];
      }

      final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now().add(const Duration(days: 365));

      final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(startDate: start, endDate: end),
      );

      return eventsResult.data ?? [];
    } catch (e) {
      print('Error retrieving events: $e');
      return [];
    }
  }

  // Get all events from all calendars
  Future<List<Event>> getAllEvents({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final calendars = await getCalendars();
      final allEvents = <Event>[];

      for (final calendar in calendars) {
        if (calendar.id != null) {
          final events = await getEvents(
            calendarId: calendar.id!,
            startDate: startDate,
            endDate: endDate,
          );
          allEvents.addAll(events);
        }
      }

      // Sort events by start date
      allEvents.sort((a, b) {
        if (a.start == null || b.start == null) return 0;
        return a.start!.compareTo(b.start!);
      });

      return allEvents;
    } catch (e) {
      print('Error retrieving all events: $e');
      return [];
    }
  }

  // Create a new event
  Future<bool> createEvent({
    required String calendarId,
    required String title,
    String? description,
    String? location,
    required DateTime startDate,
    required DateTime endDate,
    bool allDay = false,
  }) async {
    try {
      final permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        return false;
      }

      final event = Event(calendarId)
        ..title = title
        ..description = description
        ..location = location
        ..start = TZDateTime.from(startDate, local)
        ..end = TZDateTime.from(endDate, local)
        ..allDay = allDay;

      final createEventResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      return createEventResult?.isSuccess ?? false;
    } catch (e) {
      print('Error creating event: $e');
      return false;
    }
  }

  // Update an existing event
  Future<bool> updateEvent({
    required String calendarId,
    required String eventId,
    String? title,
    String? description,
    String? location,
    DateTime? startDate,
    DateTime? endDate,
    bool? allDay,
  }) async {
    try {
      final permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        return false;
      }

      // First retrieve the event
      final eventsResult = await _deviceCalendarPlugin.retrieveEvents(
        calendarId,
        RetrieveEventsParams(
          eventIds: [eventId],
        ),
      );

      if (eventsResult.data == null || eventsResult.data!.isEmpty) {
        return false;
      }

      final event = eventsResult.data!.first;

      // Update fields if provided
      if (title != null) event.title = title;
      if (description != null) event.description = description;
      if (location != null) event.location = location;
      if (startDate != null) event.start = TZDateTime.from(startDate, local);
      if (endDate != null) event.end = TZDateTime.from(endDate, local);
      if (allDay != null) event.allDay = allDay;

      final updateResult = await _deviceCalendarPlugin.createOrUpdateEvent(event);
      return updateResult?.isSuccess ?? false;
    } catch (e) {
      print('Error updating event: $e');
      return false;
    }
  }

  // Delete an event
  Future<bool> deleteEvent({
    required String calendarId,
    required String eventId,
  }) async {
    try {
      final permissionsGranted = await requestPermissions();
      if (!permissionsGranted) {
        return false;
      }

      final deleteResult = await _deviceCalendarPlugin.deleteEvent(
        calendarId,
        eventId,
      );

      return deleteResult?.isSuccess ?? false;
    } catch (e) {
      print('Error deleting event: $e');
      return false;
    }
  }

  // Get the default calendar (usually the primary calendar)
  Future<Calendar?> getDefaultCalendar() async {
    try {
      final calendars = await getCalendars();

      // Try to find the default calendar
      final defaultCalendar = calendars.firstWhere(
        (cal) => cal.isDefault ?? false,
        orElse: () => calendars.isNotEmpty ? calendars.first : Calendar(),
      );

      return defaultCalendar.id != null ? defaultCalendar : null;
    } catch (e) {
      print('Error getting default calendar: $e');
      return null;
    }
  }

  // ========== BACKEND SYNC FUNCTIONALITY ==========

  /// Check if calendar sync is enabled
  Future<bool> isCalendarEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_calendarEnabledKey) ?? false;
  }

  /// Enable/disable calendar sync
  Future<void> setCalendarEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_calendarEnabledKey, enabled);

    if (enabled) {
      // Request permission and sync immediately
      final hasPermission = await requestPermissions();
      if (hasPermission) {
        await syncCalendar();
      }
    }
  }

  /// Sync calendar events to backend
  Future<bool> syncCalendar() async {
    print('[CalendarService] ========== SYNC CALENDAR STARTED ==========');

    // TEMPORARY: Allow insecure SSL connections for development
    HttpOverrides.global = _DevHttpOverrides();

    try {
      final isEnabled = await isCalendarEnabled();
      print('[CalendarService] Calendar enabled check: $isEnabled');
      if (!isEnabled) {
        print('[CalendarService] Calendar sync disabled - aborting');
        return false;
      }

      final hasPermission = await requestPermissions();
      print('[CalendarService] Permission check: $hasPermission');
      if (!hasPermission) {
        print('[CalendarService] Calendar permission not granted - aborting');
        return false;
      }

      print('[CalendarService] Starting calendar sync to backend...');

      // Get upcoming events (next 30 days)
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30));
      print('[CalendarService] Fetching events from $now to $endDate');

      final events = await getAllEvents(startDate: now, endDate: endDate);
      print('[CalendarService] Found ${events.length} calendar events');

      if (events.isEmpty) {
        print('[CalendarService] No events to sync');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        return true;
      }

      // Convert to JSON
      final eventsJson = events.map((event) => _eventToJson(event)).toList();
      print('[CalendarService] Converted ${eventsJson.length} events to JSON');

      // Get user ID
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '410b2520-e011-70d9-1ef0-10cead18dedd';
      print('[CalendarService] User ID: $userId');

      // Send to backend
      final url = '$_backendUrl/sync';
      print('[CalendarService] Sending POST to: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'events': eventsJson,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timed out after 10 seconds');
        },
      );

      print('[CalendarService] Response status: ${response.statusCode}');
      print('[CalendarService] Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('[CalendarService] ✅ Calendar synced successfully!');
        await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
        return true;
      } else {
        print('[CalendarService] ❌ Calendar sync failed: ${response.statusCode} - ${response.body}');
        throw Exception('Backend returned ${response.statusCode}: ${response.body}');
      }
    } catch (e, stackTrace) {
      print('[CalendarService] ❌ ERROR syncing calendar: $e');
      print('[CalendarService] Stack trace: $stackTrace');
      rethrow; // Re-throw so calling code can handle the error
    } finally {
      print('[CalendarService] ========== SYNC CALENDAR ENDED ==========');
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    if (lastSyncStr != null) {
      return DateTime.parse(lastSyncStr);
    }
    return null;
  }

  /// Convert Event to JSON for backend
  Map<String, dynamic> _eventToJson(Event event) {
    try {
      return {
        'id': event.eventId,
        'calendarId': event.calendarId,
        'title': event.title,
        'description': event.description,
        'start': event.start?.toIso8601String(),
        'end': event.end?.toIso8601String(),
        'location': event.location,
        'allDay': event.allDay,
        'attendees': event.attendees?.map((a) => {
          'name': a?.name,
          'emailAddress': a?.emailAddress,
          'role': a?.role?.toString(),
        }).toList(),
        // Convert recurrenceRule to string to avoid _DataUri serialization issues
        'recurrenceRule': event.recurrenceRule != null
            ? event.recurrenceRule.toString()
            : null,
        // Convert url to string to avoid _DataUri serialization issues
        'url': event.url?.toString(),
      };
    } catch (e) {
      print('[CalendarService] Error converting event to JSON: $e');
      // Return minimal event data if conversion fails
      return {
        'id': event.eventId,
        'calendarId': event.calendarId,
        'title': event.title ?? 'Untitled Event',
        'start': event.start?.toIso8601String(),
        'end': event.end?.toIso8601String(),
        'allDay': event.allDay ?? false,
      };
    }
  }
}

// TEMPORARY: Allow insecure SSL connections for development
class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        print('[SSL] Allowing certificate for $host:$port');
        return true; // Allow all certificates for development
      };
  }
}
