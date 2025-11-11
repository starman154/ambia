import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/calendar_service.dart';
import '../services/auth_service.dart';
import '../services/outlook_oauth_service.dart';
import 'auth/login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final CalendarService _calendarService = CalendarService();
  final AuthService _authService = AuthService();
  final OutlookOAuthService _outlookService = OutlookOAuthService();

  bool _calendarEnabled = false;
  bool _aiPredictionsEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _dynamicIslandEnabled = false;
  bool _gmailEnabled = false;

  OutlookConnectionStatus? _outlookStatus;
  bool _loadingOutlookStatus = true;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _authService.initialize();
    _loadPreferences();
    _loadUserEmail();
    _loadOutlookStatus();
  }

  Future<void> _loadUserEmail() async {
    final email = await _authService.getUserEmail();
    setState(() {
      _userEmail = email;
    });
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _calendarEnabled = prefs.getBool('calendar_enabled') ?? false;
      _aiPredictionsEnabled = prefs.getBool('ai_predictions_enabled') ?? true;
      _pushNotificationsEnabled = prefs.getBool('push_notifications_enabled') ?? true;
      _dynamicIslandEnabled = prefs.getBool('dynamic_island_enabled') ?? false;
      _gmailEnabled = prefs.getBool('gmail_enabled') ?? false;
    });
  }

  Future<void> _loadOutlookStatus() async {
    try {
      final status = await _outlookService.getConnectionStatus();
      if (mounted) {
        setState(() {
          _outlookStatus = status;
          _loadingOutlookStatus = false;
        });
      }
    } catch (e) {
      print('Error loading Outlook status: $e');
      if (mounted) {
        setState(() {
          _loadingOutlookStatus = false;
        });
      }
    }
  }

  Future<void> _toggleCalendar(bool value) async {
    print('[Settings] Calendar toggle changed to: $value');

    if (value) {
      // Request calendar permissions
      print('[Settings] Requesting calendar permissions...');
      final granted = await _calendarService.requestPermissions();
      print('[Settings] Permission granted: $granted');

      if (!granted) {
        // Show error if permissions denied
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar permission denied'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
    }

    // Show loading state
    if (mounted && value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Syncing calendar...'),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      // Enable/disable calendar sync (this will also sync if enabled)
      print('[Settings] Calling setCalendarEnabled($value)...');
      await _calendarService.setCalendarEnabled(value);
      print('[Settings] setCalendarEnabled completed successfully');

      setState(() {
        _calendarEnabled = value;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(value
                      ? 'Calendar synced! Ambia will now track your events'
                      : 'Calendar sync disabled'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('[Settings] ERROR during calendar toggle: $e');

      // Reset the toggle on error
      setState(() {
        _calendarEnabled = !value;
      });

      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Calendar sync failed: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _toggleCalendar(value),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleAIPredictions(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_predictions_enabled', value);
    setState(() {
      _aiPredictionsEnabled = value;
    });
  }

  Future<void> _togglePushNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications_enabled', value);
    setState(() {
      _pushNotificationsEnabled = value;
    });
  }

  Future<void> _toggleDynamicIsland(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dynamic_island_enabled', value);
    setState(() {
      _dynamicIslandEnabled = value;
    });
  }

  Future<void> _toggleGmail(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gmail_enabled', value);
    setState(() {
      _gmailEnabled = value;
    });

    // Show message to user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
            ? 'Gmail integration enabled - Ambia can scan your Gmail for shipping confirmations'
            : 'Gmail integration disabled'),
          backgroundColor: value ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleOutlookConnect() async {
    if (_outlookStatus?.isConnected == true) {
      // Show disconnect confirmation
      _showDisconnectDialog();
    } else {
      // Show permission dialog then start OAuth
      _showOutlookPermissionDialog();
    }
  }

  Future<void> _showOutlookPermissionDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0078D4), Color(0xFF00BCF2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.mail_outline, color: Colors.white, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                'Connect Outlook',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ambia needs access to your Outlook email to provide intelligent predictions and contextual information.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Permissions Required:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildPermissionItem(
                    icon: Icons.mail,
                    text: 'Read your email messages',
                  ),
                  _buildPermissionItem(
                    icon: Icons.person,
                    text: 'Read your profile information',
                  ),
                  _buildPermissionItem(
                    icon: Icons.sync,
                    text: 'Keep access to synced data',
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.security,
                  size: 16,
                  color: Colors.green.withOpacity(0.8),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your data is encrypted and never shared',
                    style: TextStyle(
                      color: Colors.green.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0078D4), Color(0xFF00BCF2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Start OAuth flow
      _startOutlookOAuth();
    }
  }

  Widget _buildPermissionItem({required IconData icon, required String text}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.white.withOpacity(0.6),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startOutlookOAuth() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0078D4)),
              ),
              SizedBox(height: 16),
              Text(
                'Opening Microsoft Login...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final success = await _outlookService.startOAuthFlow();

      if (mounted) {
        Navigator.pop(context); // Close loading

        if (success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.open_in_browser, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Opening browser. Sign in and authorize Ambia.',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              backgroundColor: Color(0xFF0078D4),
              duration: Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Poll for connection status
          _pollOutlookConnection();
        } else {
          _showErrorSnackBar('Failed to open OAuth page');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    }
  }

  Future<void> _pollOutlookConnection() async {
    // Poll every 3 seconds for 2 minutes
    for (int i = 0; i < 40; i++) {
      await Future.delayed(Duration(seconds: 3));

      if (!mounted) return;

      final status = await _outlookService.getConnectionStatus();
      if (status?.isConnected == true) {
        setState(() {
          _outlookStatus = status;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Outlook connected! (${status!.email})',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }
  }

  Future<void> _showDisconnectDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Disconnect Outlook?',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will remove Ambia\'s access to your Outlook email.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 15,
              ),
            ),
            SizedBox(height: 12),
            Text(
              _outlookStatus?.email ?? '',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Disconnect',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _disconnectOutlook();
    }
  }

  Future<void> _disconnectOutlook() async {
    try {
      final success = await _outlookService.disconnect();

      if (success) {
        setState(() {
          _outlookStatus = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Outlook disconnected'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _showErrorSnackBar('Failed to disconnect Outlook');
      }
    } catch (e) {
      _showErrorSnackBar('Error disconnecting: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Sign Out',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFFFF6B35),
                  Color(0xFFEC4899),
                  Color(0xFFC026D3),
                  Color(0xFF8B5CF6),
                ],
              ).createShader(bounds),
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _authService.signOut();

      if (!mounted) return;

      // Navigate to login page
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 80, right: 16, top: 8, bottom: 16),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Profile Section
                  if (_userEmail != null) ...[
                    _buildSection(
                      title: 'Account',
                      children: [
                        _buildSettingItem(
                          icon: Icons.person,
                          title: _userEmail!,
                          subtitle: 'Signed in',
                          onTap: () {},
                        ),
                        _buildSettingItem(
                          icon: Icons.logout,
                          title: 'Sign Out',
                          subtitle: 'Sign out of your account',
                          onTap: _handleSignOut,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildSection(
                    title: 'Intelligence',
                    children: [
                      _buildSettingItem(
                        icon: Icons.psychology,
                        title: 'AI Predictions',
                        subtitle: 'Enable contextual insights',
                        trailing: Switch(
                          value: _aiPredictionsEnabled,
                          onChanged: _toggleAIPredictions,
                          activeColor: Colors.blue,
                        ),
                      ),
                      _buildSettingItem(
                        icon: Icons.calendar_today,
                        title: 'Calendar Access',
                        subtitle: 'Sync with your calendar',
                        trailing: Switch(
                          value: _calendarEnabled,
                          onChanged: _toggleCalendar,
                          activeColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: 'Mail Integration',
                    children: [
                      _buildSettingItem(
                        icon: Icons.email,
                        title: 'Gmail',
                        subtitle: 'Scan Gmail for shipping confirmations',
                        trailing: Switch(
                          value: _gmailEnabled,
                          onChanged: _toggleGmail,
                          activeColor: Colors.blue,
                        ),
                      ),
                      _buildOutlookConnectionItem(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: 'Notifications',
                    children: [
                      _buildSettingItem(
                        icon: Icons.notifications,
                        title: 'Push Notifications',
                        subtitle: 'Get notified of important events',
                        trailing: Switch(
                          value: _pushNotificationsEnabled,
                          onChanged: _togglePushNotifications,
                          activeColor: Colors.blue,
                        ),
                      ),
                      _buildSettingItem(
                        icon: Icons.phone_iphone,
                        title: 'Dynamic Island',
                        subtitle: 'Show live information',
                        trailing: Switch(
                          value: _dynamicIslandEnabled,
                          onChanged: _toggleDynamicIsland,
                          activeColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    title: 'About',
                    children: [
                      _buildSettingItem(
                        icon: Icons.info_outline,
                        title: 'Version',
                        subtitle: '1.0.0 (Beta)',
                        onTap: () {},
                      ),
                      _buildSettingItem(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'How we protect your data',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 100), // Extra padding for tab bar
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutlookConnectionItem() {
    if (_loadingOutlookStatus) {
      return _buildSettingItem(
        icon: Icons.mail_outline,
        title: 'Outlook',
        subtitle: 'Loading...',
        trailing: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.5)),
          ),
        ),
      );
    }

    final isConnected = _outlookStatus?.isConnected == true;

    if (isConnected) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleOutlookConnect,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0078D4), Color(0xFF00BCF2)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.mail,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Outlook',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 12,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Connected',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _outlookStatus!.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_outlookStatus!.lastSynced != null) ...[
                        SizedBox(height: 2),
                        Text(
                          'Last synced ${_outlookStatus!.lastSyncedText}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.settings,
                  color: Colors.white.withOpacity(0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Not connected - show connect button
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleOutlookConnect,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.mail_outline,
                  color: Colors.white.withOpacity(0.8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outlook',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Connect to scan emails',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0078D4), Color(0xFF00BCF2)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Connect',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white.withOpacity(0.8),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing
              else
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.3),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
