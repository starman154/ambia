import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'dart:io';
import '../widgets/ambient_layout_renderer.dart';

class AmbientInfoPage extends StatefulWidget {
  final String? eventId;

  const AmbientInfoPage({super.key, this.eventId});

  @override
  State<AmbientInfoPage> createState() => _AmbientInfoPageState();
}

class _AmbientInfoPageState extends State<AmbientInfoPage> {
  bool _isLoading = false;
  Map<String, dynamic>? _layoutData;
  String? _error;

  late final http.Client _httpClient;

  @override
  void initState() {
    super.initState();

    // Create HTTP client that accepts bad certificates (for development)
    final httpClient = HttpClient();
    httpClient.badCertificateCallback = (cert, host, port) => true;
    httpClient.connectionTimeout = const Duration(seconds: 60);
    httpClient.idleTimeout = const Duration(seconds: 60);
    _httpClient = IOClient(httpClient);

    // Load layout when eventId is set
    if (widget.eventId != null) {
      _loadLayout();
    }
  }

  @override
  void didUpdateWidget(AmbientInfoPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload layout if eventId changes
    if (widget.eventId != oldWidget.eventId && widget.eventId != null) {
      _loadLayout();
    }
  }

  Future<void> _loadLayout() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Create a fresh HTTP client for this request
    final httpClient = HttpClient();
    httpClient.badCertificateCallback = (cert, host, port) => true;
    httpClient.connectionTimeout = const Duration(seconds: 60);
    httpClient.idleTimeout = const Duration(seconds: 60);
    final client = IOClient(httpClient);

    try {
      print('[AmbientInfo] Loading layout for event: ${widget.eventId}');

      final url = 'https://ambia-prod.eba-hwjnqmy5.us-east-2.elasticbeanstalk.com/api/ambient/layout/${widget.eventId}';
      print('[AmbientInfo] Requesting: $url');

      final response = await client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 60), // Give Claude plenty of time
        onTimeout: () {
          throw Exception('Request timed out after 60 seconds');
        },
      );

      print('[AmbientInfo] Response received - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[AmbientInfo] Layout loaded successfully');

        if (mounted) {
          setState(() {
            _layoutData = data;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load layout: ${response.statusCode}');
      }
    } catch (e) {
      print('[AmbientInfo] Error loading layout: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    } finally {
      client.close();
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('[AmbientInfo] build - eventId: ${widget.eventId}, isLoading: $_isLoading, error: $_error, hasData: ${_layoutData != null}');

    return Container(
      color: Colors.black,
      child: widget.eventId == null
          ? _buildEmptyState()
          : _isLoading
              ? _buildLoadingState()
              : _error != null
                  ? _buildErrorState()
                  : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Tap a Live Activity',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your ambient info will appear here',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
          ),
          const SizedBox(height: 24),
          Text(
            'Generating your ambient view...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.7),
            ),
            const SizedBox(height: 24),
            Text(
              'Error loading content',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadLayout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC4899),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    print('[AmbientInfo] _buildContent called');

    if (_layoutData == null) {
      print('[AmbientInfo] _layoutData is null');
      return Center(
        child: Text(
          'No layout data available',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    print('[AmbientInfo] _layoutData keys: ${_layoutData!.keys}');

    // Extract layout from response
    final layout = _layoutData!['layout'] as Map<String, dynamic>?;

    if (layout == null) {
      print('[AmbientInfo] layout is null');
      return Center(
        child: Text(
          'Invalid layout format',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    print('[AmbientInfo] Rendering layout with keys: ${layout.keys}');

    // Render the Claude-generated layout
    return AmbientLayoutRenderer(layoutData: layout);
  }
}
