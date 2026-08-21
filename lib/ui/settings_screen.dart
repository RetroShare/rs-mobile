import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/identicon.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
  String _statusMessage = '';
  int _presenceStatus = 0;
  bool _isLoadingStatus = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStatusMessage());
  }

  Future<void> _loadStatusMessage() async {
    try {
      final authToken =
          Provider.of<AccountCredentials>(context, listen: false).authtoken;
      if (authToken == null) return;
      final status = await RsChats.getOwnCustomStateString(authToken);
      final presenceStatus = await RsStatus.getOwnStatus(authToken);
      if (mounted) {
        setState(() {
          _statusMessage = status;
          _presenceStatus = presenceStatus;
        });
      }
    } catch (error) {
      debugPrint('Failed to load own status message: $error');
    } finally {
      if (mounted) setState(() => _isLoadingStatus = false);
    }
  }

  Color _presenceColor() {
    switch (_presenceStatus) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.red;
      case 3:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _setPresenceStatus(int status) async {
    try {
      final authToken =
          Provider.of<AccountCredentials>(context, listen: false).authtoken;
      if (authToken == null) return;
      final success = await RsStatus.sendStatus(status, authToken);
      if (!success) throw Exception('sendStatus returned false');
      if (mounted) setState(() => _presenceStatus = status);
    } catch (error) {
      debugPrint('Failed to update own presence status: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update online status.')),
        );
      }
    }
  }

  Future<void> _editStatusMessage() async {
    final controller = TextEditingController(text: _statusMessage);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit status message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 160,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Status shown to your direct friends',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // showDialog may complete before its focused TextField is fully unmounted.
    // Disposing synchronously can trigger a framework _dependents assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (value == null || !mounted) return;

    try {
      final authToken =
          Provider.of<AccountCredentials>(context, listen: false).authtoken;
      if (authToken == null) return;
      await RsChats.setCustomStateString(value, authToken);
      if (mounted) setState(() => _statusMessage = value);
    } catch (error) {
      debugPrint('Failed to update own status message: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update status message.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identitiesProvider = Provider.of<Identities>(context);
    final currentId = identitiesProvider.currentIdentity;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surface,
        shadowColor: Colors.transparent,
        leading: BackButton(
          color: theme.colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: currentId == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Profile Header Section
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(26),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                              ),
                              child: ClipOval(
                                child: currentId.avatar != null &&
                                        currentId.avatar!.isNotEmpty
                                    ? Image.memory(
                                        base64.decode(currentId.avatar!),
                                        fit: BoxFit.cover,
                                      )
                                    : Identicon(
                                        id: currentId.mId,
                                        borderRadius: 50,
                                      ),
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: PopupMenuButton<int>(
                                tooltip: 'Change online status',
                                initialValue: _presenceStatus,
                                onSelected: _setPresenceStatus,
                                itemBuilder: (context) => [
                                  _presenceMenuItem(
                                    value: 3,
                                    label: 'Online',
                                    color: Colors.green,
                                  ),
                                  _presenceMenuItem(
                                    value: 1,
                                    label: 'Away',
                                    color: Colors.amber,
                                  ),
                                  _presenceMenuItem(
                                    value: 2,
                                    label: 'Busy',
                                    color: Colors.red,
                                  ),
                                ],
                                child: Container(
                                  width: 27,
                                  height: 27,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _presenceColor(),
                                    border: Border.all(
                                      color: theme.colorScheme.surface,
                                      width: 4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentId.name ?? 'Unknown Identity',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _isLoadingStatus ? null : _editStatusMessage,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _isLoadingStatus
                                          ? 'Loading status…'
                                          : _statusMessage.isEmpty
                                              ? 'Add a status message'
                                              : _statusMessage,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: _statusMessage.isEmpty
                                            ? theme.colorScheme.onSurfaceVariant
                                            : theme.colorScheme.onSurface,
                                        fontStyle: _statusMessage.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.edit_rounded,
                                    size: 17,
                                    color: theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: currentId.signed
                                ? Colors.teal.withAlpha(26)
                                : Colors.orange.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            currentId.signed
                                ? 'Signed Identity'
                                : 'Pseudonymous Identity',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: currentId.signed
                                  ? Colors.teal
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Settings Options Container
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color:
                              theme.colorScheme.outlineVariant.withAlpha(128),
                        ),
                      ),
                      color: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(50),
                      child: Column(
                        children: [
                          _settingsTile(
                            context: context,
                            icon: Icons.person_rounded,
                            iconBgColor: Colors.blue,
                            title: 'Account',
                            subtitle: 'PGP ID, mId, profile details',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/profile',
                                arguments: {'id': currentId},
                              );
                            },
                          ),
                          _divider(theme),
                          _settingsTile(
                            context: context,
                            icon: Icons.chat_rounded,
                            iconBgColor: Colors.orange,
                            title: 'Chat Settings',
                            subtitle: 'Theme, bubble style',
                            onTap: () {
                              Navigator.pushNamed(context, '/chat_settings');
                            },
                          ),
                          _divider(theme),
                          _settingsTile(
                            context: context,
                            icon: Icons.wifi_rounded,
                            iconBgColor: Colors.teal,
                            title: 'Network',
                            subtitle: 'IP Address, Port, DHT status',
                            onTap: () {
                              Navigator.pushNamed(context, '/network_settings');
                            },
                          ),
                          _divider(theme),
                          _settingsTile(
                            context: context,
                            icon: Icons.query_stats_rounded,
                            iconBgColor: Colors.purple,
                            title: 'Statistics',
                            subtitle: 'Transfer rates and totals',
                            onTap: () {
                              Navigator.pushNamed(context, '/statistics');
                            },
                          ),
                          _divider(theme),
                          _settingsTile(
                            context: context,
                            icon: Icons.widgets_rounded,
                            iconBgColor: Colors.indigo,
                            title: 'Mobile Services',
                            subtitle: 'Forums, channels, boards',
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/mobile_services_settings',
                              );
                            },
                          ),
                          _divider(theme),
                          _settingsTile(
                            context: context,
                            icon: Icons.security_rounded,
                            iconBgColor: Colors.green,
                            title: 'Privacy & Security',
                            subtitle: 'Manage and switch identities',
                            onTap: () {
                              Navigator.pushNamed(context, '/change_identity');
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final version = snapshot.data!.version;
                        final buildNumber = snapshot.data!.buildNumber;
                        return Center(
                          child: Text(
                            'RetroShare Mobile v$version ($buildNumber)',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withAlpha(150),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _divider(ThemeData theme) {
    return Divider(
      height: 1,
      indent: 64,
      endIndent: 16,
      color: theme.colorScheme.outlineVariant.withAlpha(100),
    );
  }

  PopupMenuItem<int> _presenceMenuItem({
    required int value,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem<int>(
      value: value,
      child: Row(
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _settingsTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBgColor.withAlpha(30),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: iconBgColor,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}
