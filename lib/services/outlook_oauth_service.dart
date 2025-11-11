import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:url_launcher/url_launcher.dart';

/// Outlook OAuth Service
/// Handles OAuth flow for Outlook/Microsoft email integration
class OutlookOAuthService {
  static const String _baseUrl = 'https://ambia-prod.eba-hwjnqmy5.us-east-2.elasticbeanstalk.com/api';

  // Hardcoded user ID for now - in production this would come from auth
  static const String _userId = '410b2520-e011-70d9-1ef0-10cead18dedd';

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

  /// Start Outlook OAuth flow
  /// Opens browser to Microsoft login page
  Future<bool> startOAuthFlow() async {
    try {
      final authUrl = Uri.parse('$_baseUrl/oauth/outlook/authorize?userId=$_userId');

      final canLaunch = await canLaunchUrl(authUrl);
      if (!canLaunch) {
        throw Exception('Cannot launch OAuth URL');
      }

      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );

      return launched;
    } catch (e) {
      print('Error starting OAuth flow: $e');
      return false;
    }
  }

  /// Check Outlook connection status
  /// Returns connection info or null if not connected
  Future<OutlookConnectionStatus?> getConnectionStatus() async {
    final client = _createHttpClient();
    try {
      final response = await client.get(
        Uri.parse('$_baseUrl/oauth/outlook/status?userId=$_userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['connected'] == true) {
          return OutlookConnectionStatus(
            isConnected: true,
            email: data['email'] as String?,
            isActive: data['active'] as bool? ?? true,
            lastSynced: data['lastSynced'] != null
                ? DateTime.parse(data['lastSynced'] as String)
                : null,
          );
        }
      }

      return null;
    } catch (e) {
      print('Error checking Outlook status: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// Disconnect Outlook
  /// Revokes access and removes stored tokens
  Future<bool> disconnect() async {
    final client = _createHttpClient();
    try {
      final response = await client.post(
        Uri.parse('$_baseUrl/oauth/outlook/disconnect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': _userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      return false;
    } catch (e) {
      print('Error disconnecting Outlook: $e');
      return false;
    } finally {
      client.close();
    }
  }
}

/// Outlook connection status model
class OutlookConnectionStatus {
  final bool isConnected;
  final String? email;
  final bool isActive;
  final DateTime? lastSynced;

  OutlookConnectionStatus({
    required this.isConnected,
    this.email,
    required this.isActive,
    this.lastSynced,
  });

  String get lastSyncedText {
    if (lastSynced == null) return 'Never synced';

    final now = DateTime.now();
    final difference = now.difference(lastSynced!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
