import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/identicon.dart';
import 'package:retroshare/provider/identity.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  SettingsScreenState createState() => SettingsScreenState();
}

class SettingsScreenState extends State<SettingsScreen> {
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
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: ClipOval(
                            child: currentId.avatar != null && currentId.avatar!.isNotEmpty
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
                        const SizedBox(height: 16),
                        Text(
                          currentId.name ?? 'Unknown Identity',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            currentId.mId,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontFamily: 'monospace',
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: currentId.signed
                                ? Colors.teal.withAlpha(26)
                                : Colors.orange.withAlpha(26),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            currentId.signed ? 'Signed Identity' : 'Pseudonymous Identity',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: currentId.signed ? Colors.teal : Colors.orange,
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
                          color: theme.colorScheme.outlineVariant.withAlpha(128),
                        ),
                      ),
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
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
