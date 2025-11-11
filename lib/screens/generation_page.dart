import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:video_player/video_player.dart';
import '../models/ambient_component.dart';
import '../services/ambia_service.dart';
import '../services/api_service.dart';
import '../services/json_renderer.dart';
import '../services/calendar_service.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String? text;
  final List<AmbientComponent>? components;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    this.text,
    this.components,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class GenerationPage extends StatefulWidget {
  const GenerationPage({super.key});

  @override
  State<GenerationPage> createState() => _GenerationPageState();
}

class _GenerationPageState extends State<GenerationPage>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final AmbiaService _ambiaService = AmbiaService();
  final String _userId = '410b2520-e011-70d9-1ef0-10cead18dedd'; // TODO: Get from auth

  late AnimationController _floodController;
  late Animation<double> _floodAnimation;
  late AnimationController _logoScaleController;
  late Animation<double> _logoScaleAnimation;
  VideoPlayerController? _logoController;

  bool _isGenerating = false;
  bool _isButtonPressed = false;
  List<ChatMessage> _messages = [];
  String? _conversationId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Flood animation for input border
    _floodController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _floodAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _floodController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Logo scale-in animation
    _logoScaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoScaleController,
        curve: Curves.easeOutBack,
      ),
    );

    // Initialize video player for animated logo
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _logoController = VideoPlayerController.asset('assets/videos/Ambia.mp4');
      await _logoController!.initialize();
      _logoController!.setLooping(true);
      await _logoController!.play();
      if (mounted) {
        setState(() {});
        // Start scale-in animation after video is loaded
        _logoScaleController.forward();
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _floodController.dispose();
    _logoScaleController.dispose();
    _logoController?.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _handleNewChat() async {
    setState(() {
      _messages = [];
      _conversationId = null;
      _errorMessage = null;
    });
  }

  void _showOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.33,
            decoration: BoxDecoration(
              color: Color(0xFF1C1C1E).withOpacity(0.7),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                // Empty content for now
                Expanded(
                  child: Center(
                    child: Text(
                      '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleGenerate() async {
    if (_textController.text.trim().isEmpty) return;

    final userMessage = _textController.text.trim();
    _textController.clear();

    // Add user message to chat
    setState(() {
      _messages.add(ChatMessage(
        role: 'user',
        text: userMessage,
      ));
      _isGenerating = true;
      _errorMessage = null;
    });

    _focusNode.unfocus();
    _scrollToBottom();
    _floodController.forward();

    try {
      String enrichedMessage = userMessage;

      // Always add current date/time information for every query
      final now = DateTime.now();
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

      // Format time in 12-hour format with AM/PM by default
      final hour24 = now.hour;
      final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
      final period = hour24 >= 12 ? 'PM' : 'AM';
      final currentTime = '${hour12}:${now.minute.toString().padLeft(2, '0')} $period';

      final currentDate = '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
      final timezoneName = now.timeZoneName;

      // Start with the date/time context
      String contextInfo = 'Current Date & Time: $currentDate at $currentTime $timezoneName';

      // Check if calendar access is enabled and query is calendar-related
      final prefs = await SharedPreferences.getInstance();
      final calendarEnabled = prefs.getBool('calendar_enabled') ?? false;

      if (calendarEnabled && _isCalendarRelatedQuery(userMessage)) {
        // Fetch calendar events and calendar metadata
        final calendarService = CalendarService();
        final weekEnd = now.add(const Duration(days: 7));

        // Get all calendars to map IDs to names
        final calendars = await calendarService.getCalendars();
        final calendarMap = <String, String>{};
        for (final cal in calendars) {
          if (cal.id != null && cal.name != null) {
            calendarMap[cal.id!] = cal.name!;
          }
        }

        final events = await calendarService.getAllEvents(
          startDate: now,
          endDate: weekEnd,
        );

        // Add calendar events to context if available
        if (events.isNotEmpty) {
          final calendarContext = _formatCalendarContext(events, calendarMap);
          contextInfo += '\n\nCalendar Context:\n$calendarContext';
        }
      }

      // Add context to the message
      enrichedMessage = '$userMessage\n\n$contextInfo';

      // Note: Backend now handles conversation creation and message saving automatically
      // Generate components using Ambia API (backend creates conversation if needed)
      final result = await _ambiaService.generateComponents(enrichedMessage, conversationId: _conversationId);
      final components = result['components'] as List<AmbientComponent>;
      final conversationId = result['conversationId'] as String?;

      // Store conversation ID for maintaining context across messages
      if (conversationId != null && _conversationId == null) {
        _conversationId = conversationId;
        print('Stored conversation ID: $_conversationId');
      }

      // Add assistant response to chat
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          components: components,
        ));
        _isGenerating = false;
      });

      _floodController.reset();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to generate: ${e.toString()}';
        _isGenerating = false;
        // Remove the last user message on error
        if (_messages.isNotEmpty && _messages.last.role == 'user') {
          _messages.removeLast();
        }
      });
      _floodController.reset();
    }
  }

  bool _isCalendarRelatedQuery(String query) {
    final lowerQuery = query.toLowerCase();
    final calendarKeywords = [
      'week',
      'schedule',
      'calendar',
      'today',
      'tomorrow',
      'event',
      'meeting',
      'appointment',
      'busy',
      'free',
      'plan',
    ];
    return calendarKeywords.any((keyword) => lowerQuery.contains(keyword));
  }

  String _formatCalendarContext(List<Event> events, Map<String, String> calendarMap) {
    final buffer = StringBuffer();
    final now = DateTime.now();

    for (final event in events) {
      if (event.start == null) continue;

      final start = event.start!;
      final daysDifference = start.difference(now).inDays;
      String dateLabel;

      if (daysDifference == 0) {
        dateLabel = 'Today';
      } else if (daysDifference == 1) {
        dateLabel = 'Tomorrow';
      } else {
        // Format as "Monday, Jan 15"
        final weekday = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][start.weekday - 1];
        final month = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][start.month - 1];
        dateLabel = '$weekday, $month ${start.day}';
      }

      final timeStr = event.allDay == true
          ? 'All day'
          : '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

      // Get calendar name for this event
      final calendarName = event.calendarId != null
          ? calendarMap[event.calendarId!] ?? 'Unknown Calendar'
          : 'Unknown Calendar';

      buffer.writeln('- $dateLabel at $timeStr: ${event.title ?? 'Untitled Event'} [Calendar: $calendarName]');
      if (event.location != null && event.location!.isNotEmpty) {
        buffer.writeln('  Location: ${event.location}');
      }
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header with "Ambia" title and new chat button
                Padding(
                  padding: const EdgeInsets.only(left: 80, right: 16, top: 8, bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ambia',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w200,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (_messages.isNotEmpty)
                        GestureDetector(
                          onTap: _handleNewChat,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'New',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Chat messages area
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Hello, I\'m ',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w200,
                                      color: Colors.white.withOpacity(0.9),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6B35),
                                        Color(0xFFEC4899),
                                        Color(0xFFC026D3),
                                        Color(0xFF8B5CF6),
                                      ],
                                    ).createShader(bounds),
                                    child: Text(
                                      'Ambia',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w200,
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Ask me anything',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.5),
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(
                            top: 8,
                            bottom: 140,
                          ),
                          itemCount: _messages.length + (_isGenerating ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show loading indicator as last item when generating
                            if (index == _messages.length && _isGenerating) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: _logoController != null && _logoController!.value.isInitialized
                                            ? ScaleTransition(
                                                scale: _logoScaleAnimation,
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: SizedBox(
                                                    width: 32,
                                                    height: 32,
                                                    child: FittedBox(
                                                      fit: BoxFit.cover,
                                                      child: SizedBox(
                                                        width: _logoController!.value.size.width,
                                                        height: _logoController!.value.size.height,
                                                        child: VideoPlayer(_logoController!),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : const SizedBox(
                                                width: 32,
                                                height: 32,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final message = _messages[index];
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1 - value)),
                                  child: Opacity(
                                    opacity: value,
                                    child: child,
                                  ),
                                );
                              },
                              child: _buildChatMessage(message),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Error message overlay
          if (_errorMessage != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.shade700,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => setState(() => _errorMessage = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),

          // Input field at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Plus button
                  GestureDetector(
                    onTap: _showOptionsBottomSheet,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(27),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        color: Colors.white.withOpacity(0.9),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Text input field
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _floodController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _isGenerating
                                  ? Color.lerp(
                                      Color(0xFFFF6B35),
                                      Color(0xFF8B5CF6),
                                      _floodAnimation.value,
                                    )!
                                  : Colors.white.withOpacity(0.15),
                              width: _isGenerating ? 2 : 1,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.centerRight,
                            children: [
                              TextField(
                                controller: _textController,
                                focusNode: _focusNode,
                                enabled: !_isGenerating,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Ask Ambia...',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.only(
                                    left: 20,
                                    right: 60,
                                    top: 12,
                                    bottom: 12,
                                  ),
                                ),
                                onSubmitted: (_) => _handleGenerate(),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: AnimatedScale(
                                  scale: _isButtonPressed ? 0.85 : 1.0,
                                  duration: const Duration(milliseconds: 100),
                                  curve: Curves.easeInOut,
                                  child: GestureDetector(
                                    onTap: _isGenerating ? null : _handleGenerate,
                                    onTapDown: _isGenerating ? null : (_) {
                                      setState(() => _isButtonPressed = true);
                                    },
                                    onTapUp: _isGenerating ? null : (_) {
                                      setState(() => _isButtonPressed = false);
                                    },
                                    onTapCancel: () {
                                      setState(() => _isButtonPressed = false);
                                    },
                                    child: Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(21),
                                      ),
                                      child: _logoController != null && _logoController!.value.isInitialized
                                          ? ScaleTransition(
                                              scale: _logoScaleAnimation,
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(21),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(3),
                                                  child: FittedBox(
                                                    fit: BoxFit.cover,
                                                    alignment: Alignment.center,
                                                    child: SizedBox(
                                                      width: _logoController!.value.size.width,
                                                      height: _logoController!.value.size.height,
                                                      child: VideoPlayer(_logoController!),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : const SizedBox.expand(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessage(ChatMessage message) {
    if (message.role == 'user') {
      // User message - right aligned
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 48),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF6B35).withOpacity(0.8),
                      Color(0xFFEC4899).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  message.text ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Assistant message - left aligned with components
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: message.components
                    ?.map((component) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: JSONRenderer.renderComponent(component),
                        ))
                    .toList() ??
                    [],
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      );
    }
  }
}
