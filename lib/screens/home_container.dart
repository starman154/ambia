import 'package:flutter/material.dart';
import 'generation_page.dart';
import 'conversations_page.dart';
import 'settings_page.dart';
import 'ambient_info_page.dart';
import 'dart:ui';
import '../services/conversation_service.dart';
import '../services/live_activity_service.dart';
import '../models/conversation_model.dart';

class HomeContainer extends StatefulWidget {
  const HomeContainer({super.key});

  @override
  State<HomeContainer> createState() => _HomeContainerState();
}

class _HomeContainerState extends State<HomeContainer> with TickerProviderStateMixin {
  int _currentIndex = 1;
  late PageController _pageController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ConversationService _conversationService = ConversationService();
  final LiveActivityService _liveActivityService = LiveActivityService();

  List<ConversationModel> _conversations = [];
  bool _loadingConversations = true;

  // Track current ambient event ID
  String? _currentAmbientEventId;

  List<Widget> get _pages => [
        const ConversationsPage(),
        const GenerationPage(),
        const SettingsPage(),
        AmbientInfoPage(
          key: ValueKey(_currentAmbientEventId),
          eventId: _currentAmbientEventId,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _loadConversations();

    // Set up Live Activity tap handler
    _liveActivityService.onLiveActivityTapped = _handleLiveActivityTap;
  }

  void _handleLiveActivityTap(String eventId) {
    print('[HomeContainer] Live Activity tapped for event: $eventId');

    setState(() {
      _currentAmbientEventId = eventId;
    });

    // Wait for the widget to rebuild with the new eventId before navigating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Navigate directly without closing drawer (might not be open)
        _pageController.animateToPage(
          3,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await _conversationService.getUserConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _loadingConversations = false;
        });
      }
    } catch (e) {
      print('Error loading conversations: $e');
      if (mounted) {
        setState(() {
          _loadingConversations = false;
        });
      }
    }
  }

  Future<void> _createNewConversation() async {
    try {
      await _conversationService.createConversation(title: 'New Chat');
      _loadConversations();
      // Navigate to Generate page for new conversation
      _navigateToPage(1);
      Navigator.pop(context); // Close drawer
    } catch (e) {
      print('Error creating conversation: $e');
    }
  }

  void _openConversation(ConversationModel conversation) {
    // TODO: Navigate to GenerationPage with conversationId
    _navigateToPage(1);
    Navigator.pop(context); // Close drawer
    print('Opening conversation: ${conversation.id}');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _navigateToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    Navigator.pop(context); // Close the drawer
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      extendBody: true,
      extendBodyBehindAppBar: true,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            children: _pages,
          ),
          _buildMenuButton(),
        ],
      ),
    );
  }

  Widget _buildMenuButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 24,
      child: GestureDetector(
        onTap: _openDrawer,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.menu,
            color: Colors.white.withOpacity(0.9),
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.transparent,
      width: MediaQuery.of(context).size.width * 0.60,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Fixed Top Section - Menu Items
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        _buildTopMenuItem(
                          icon: Icons.edit_outlined,
                          label: 'New Chat',
                          onTap: _createNewConversation,
                        ),
                        _buildTopMenuItem(
                          icon: Icons.view_list,
                          label: 'All Conversations',
                          onTap: () => _navigateToPage(0),
                        ),
                        _buildTopMenuItem(
                          icon: Icons.auto_awesome,
                          label: 'Ambia',
                          onTap: () => _navigateToPage(1),
                        ),
                        _buildTopMenuItem(
                          icon: Icons.info_outline,
                          label: 'Ambient Info',
                          onTap: () => _navigateToPage(3),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                  // Scrollable Chats Section
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text(
                            'Chats',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Expanded(
                          child: _loadingConversations
                              ? Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFEC4899),
                                    ),
                                  ),
                                )
                              : _conversations.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.chat_bubble_outline,
                                              size: 48,
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'No chats yet',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.5),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: EdgeInsets.symmetric(vertical: 4),
                                      itemCount: _conversations.length,
                                      itemBuilder: (context, index) {
                                        return _buildConversationItem(_conversations[index]);
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),

                  // Fixed Bottom Section - Settings
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: _buildTopMenuItem(
                      icon: Icons.settings,
                      label: 'Settings',
                      onTap: () => _navigateToPage(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.white.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationItem(ConversationModel conversation) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openConversation(conversation),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: Colors.white.withOpacity(0.6),
                size: 16,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.title,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (conversation.lastMessage != null) ...[
                      SizedBox(height: 2),
                      Text(
                        conversation.lastMessagePreview,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
