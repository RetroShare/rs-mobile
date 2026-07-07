import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatSettingsScreen extends StatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  ChatSettingsScreenState createState() => ChatSettingsScreenState();
}

class ChatSettingsScreenState extends State<ChatSettingsScreen> {
  int _bubbleStyleIndex = 0; // 0: Bubble, 1: Compact
  bool _distantHistory = false;
  bool _lobbyHistory = false;
  bool _privateHistory = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadBubbleStyle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistorySettings();
    });
  }

  Future<void> _loadBubbleStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt('chat_bubble_style') ?? 0;
      setState(() {
        _bubbleStyleIndex = index;
      });
    } catch (e) {
      debugPrint('Error loading bubble style in settings: $e');
    }
  }

  Future<void> _saveBubbleStyle(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('chat_bubble_style', index);
      setState(() {
        _bubbleStyleIndex = index;
      });
    } catch (e) {
      debugPrint('Error saving bubble style in settings: $e');
    }
  }

  Future<void> _loadHistorySettings() async {
    try {
      final authProvider = Provider.of<AccountCredentials>(context, listen: false);
      final authToken = authProvider.authtoken;
      if (authToken == null) return;

      final distResp = await rsApiCall('/rsHistory/getEnable', authToken: authToken, params: {'chat_type': 3});
      final lobbyResp = await rsApiCall('/rsHistory/getEnable', authToken: authToken, params: {'chat_type': 2});
      final privResp = await rsApiCall('/rsHistory/getEnable', authToken: authToken, params: {'chat_type': 1});

      if (mounted) {
        setState(() {
          _distantHistory = distResp['retval'] as bool? ?? false;
          _lobbyHistory = lobbyResp['retval'] as bool? ?? false;
          _privateHistory = privResp['retval'] as bool? ?? false;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history settings: $e');
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  Future<void> _toggleHistory(int type, bool value) async {
    try {
      final authProvider = Provider.of<AccountCredentials>(context, listen: false);
      final authToken = authProvider.authtoken;
      if (authToken == null) return;

      await rsApiCall(
        '/rsHistory/setEnable',
        authToken: authToken,
        params: {
          'chat_type': type,
          'enable': value,
        },
      );

      setState(() {
        if (type == 3) _distantHistory = value;
        if (type == 2) _lobbyHistory = value;
        if (type == 1) _privateHistory = value;
      });
    } catch (e) {
      debugPrint('Error setting history state: $e');
    }
  }

  Widget _divider(ThemeData theme) {
    return Divider(
      height: 1,
      indent: 64,
      endIndent: 16,
      color: theme.colorScheme.outlineVariant.withAlpha(100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = AdaptiveTheme.of(context).mode.isDark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Chat Settings'),
        backgroundColor: theme.colorScheme.surface,
        shadowColor: Colors.transparent,
        leading: BackButton(
          color: theme.colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Theme Section
              Text(
                'Theme Mode',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(128),
                  ),
                ),
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                child: SwitchListTile(
                  title: Text(
                    isDark ? 'Dark Mode' : 'Light Mode',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isDark ? 'Switch to light mode' : 'Switch to dark mode',
                  ),
                  value: isDark,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (bool value) {
                    if (value) {
                      AdaptiveTheme.of(context).setDark();
                    } else {
                      AdaptiveTheme.of(context).setLight();
                    }
                    setState(() {});
                  },
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.purple.withAlpha(30) : Colors.yellow.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark ? Colors.purple : Colors.orange,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Bubble Style Section
              Text(
                'Message Bubble Style',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(128),
                  ),
                ),
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                child: Column(
                  children: [
                    RadioListTile<int>(
                      title: const Text(
                        'Standard Bubble',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Traditional chat bubble style'),
                      value: 0,
                      groupValue: _bubbleStyleIndex,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (int? value) {
                        if (value != null) {
                          _saveBubbleStyle(value);
                        }
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    _divider(theme),
                    RadioListTile<int>(
                      title: const Text(
                        'Compact Bubble',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Compact layout for denser screens'),
                      value: 1,
                      groupValue: _bubbleStyleIndex,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (int? value) {
                        if (value != null) {
                          _saveBubbleStyle(value);
                        }
                      },
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // History Section
              Text(
                'History Settings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              _isLoadingHistory
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withAlpha(128),
                        ),
                      ),
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text(
                              'Distant Chats History',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text('Save history for distant chats'),
                            value: _distantHistory,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (bool value) => _toggleHistory(3, value),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.forum_rounded, color: Colors.blue),
                            ),
                          ),
                          _divider(theme),
                          SwitchListTile(
                            title: const Text(
                              'Chat Rooms History',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text('Save history for chat rooms'),
                            value: _lobbyHistory,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (bool value) => _toggleHistory(2, value),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.meeting_room_rounded, color: Colors.orange),
                            ),
                          ),
                          _divider(theme),
                          SwitchListTile(
                            title: const Text(
                              'Private Chats History',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text('Save history for private chats with friends'),
                            value: _privateHistory,
                            activeColor: theme.colorScheme.primary,
                            onChanged: (bool value) => _toggleHistory(1, value),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.teal.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_rounded, color: Colors.teal),
                            ),
                          ),
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
