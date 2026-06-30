import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class NetworkSettingsScreen extends StatefulWidget {
  const NetworkSettingsScreen({super.key});

  @override
  NetworkSettingsScreenState createState() => NetworkSettingsScreenState();
}

class NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  late Future<Map<String, dynamic>> _networkDetailsFuture;

  @override
  void initState() {
    super.initState();
    _refreshDetails();
  }

  void _refreshDetails() {
    setState(() {
      _networkDetailsFuture = _fetchNetworkDetails();
    });
  }

  Future<Map<String, dynamic>> _fetchNetworkDetails() async {
    final authProvider = Provider.of<AccountCredentials>(context, listen: false);
    final authToken = authProvider.authtoken;
    if (authToken == null) {
      throw Exception('Not authenticated. Please log in.');
    }

    final ownSslId = await RsAccounts.getCurrentAccountId(authToken);
    if (ownSslId == null || ownSslId.isEmpty) {
      throw Exception('Could not retrieve local node SSL ID.');
    }

    final peerDetailsResponse = await rsApiCall(
      '/rsPeers/getPeerDetails',
      authToken: authToken,
      params: {'sslId': ownSslId},
    );

    final peerDetails = peerDetailsResponse['det'] ?? {};

    Map<String, dynamic> configNetStatus = {};
    try {
      configNetStatus = await rsApiCall(
        '/rsConfig/getConfigNetStatus',
        authToken: authToken,
      );
    } catch (e) {
      debugPrint('Error calling getConfigNetStatus: $e');
    }

    return {
      'ownSslId': ownSslId,
      'peerDetails': peerDetails,
      'netStatus': configNetStatus,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        shadowColor: Colors.transparent,
        title: Text(
          'Network Settings',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14.5,
          ),
        ),
        leading: BackButton(
          color: theme.colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            color: theme.colorScheme.onSurface,
            onPressed: _refreshDetails,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _networkDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load network status',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.secondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _refreshDetails,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final det = data['peerDetails'] as Map;
          final netStatus = data['netStatus'] as Map;
          final ownSslId = data['ownSslId'] as String;

          // Resolve internal IP & Port
          final localAddr = det['mLocalAddr'] ?? det['localAddr'] ?? netStatus['localAddr'] ?? netStatus['mLocalAddr'] ?? 'Unknown';
          final localPort = det['mLocalPort']?.toString() ?? det['localPort']?.toString() ?? netStatus['localPort']?.toString() ?? netStatus['mLocalPort']?.toString() ?? 'Unknown';

          // Resolve external IP & Port
          final extAddr = det['mExtAddr'] ?? det['extAddr'] ?? netStatus['externalAddr'] ?? netStatus['extAddr'] ?? netStatus['mExtAddr'] ?? 'Unknown';
          final extPort = det['mExtPort']?.toString() ?? det['extPort']?.toString() ?? netStatus['externalPort']?.toString() ?? netStatus['extPort']?.toString() ?? netStatus['mExtPort']?.toString() ?? 'Unknown';

          // Resolve DHT Status
          bool isDhtOn = false;
          final dhtVal = netStatus['dhtActive'] ?? netStatus['dhtStatus'] ?? netStatus['dht'] ?? netStatus['mDhtActive'] ?? netStatus['mDhtStatus'];
          if (dhtVal is bool) {
            isDhtOn = dhtVal;
          } else if (dhtVal is num) {
            isDhtOn = dhtVal != 0;
          } else if (dhtVal is String) {
            isDhtOn = dhtVal.toLowerCase() == 'true' || dhtVal == '1' || dhtVal.toLowerCase() == 'on';
          } else {
            // Fallback: If network mode is public, DHT is usually on
            final netMode = netStatus['netMode'] ?? netStatus['networkMode'] ?? netStatus['mNetMode'] ?? netStatus['mNetworkMode'];
            if (netMode is num && netMode == 2) {
              isDhtOn = true;
            }
          }

          final dhtText = isDhtOn ? 'Active' : 'Inactive';
          final dhtColor = isDhtOn ? Colors.green : Colors.redAccent;
          final dhtIcon = isDhtOn ? Icons.hub_rounded : Icons.hub_outlined;



          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dashboard Badge Header
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: dhtColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: dhtColor.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: dhtColor,
                              boxShadow: [
                                BoxShadow(
                                  color: dhtColor.withOpacity(0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'DHT Status: $dhtText',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: dhtColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cards layout
                  _networkCard(
                    context: context,
                    title: 'Internal Address',
                    subtitle: 'Local IP & Port in your network',
                    ip: localAddr.toString(),
                    port: localPort,
                    icon: Icons.dns_rounded,
                    iconColor: Colors.blueAccent,
                  ),
                  const SizedBox(height: 16),

                  _networkCard(
                    context: context,
                    title: 'External Address',
                    subtitle: 'WAN IP & Port visible to the public internet',
                    ip: extAddr.toString(),
                    port: extPort,
                    icon: Icons.public_rounded,
                    iconColor: Colors.deepPurpleAccent,
                  ),
                  const SizedBox(height: 16),

                  _statusTile(
                    context: context,
                    title: 'Distributed Hash Table (DHT)',
                    value: dhtText,
                    icon: dhtIcon,
                    color: dhtColor,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _networkCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String ip,
    required String port,
    required IconData icon,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    final fullAddress = '$ip:$port';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IP Address',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ip,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Port',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    port,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: 'Copy IP & Port',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: fullAddress));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title copied to clipboard'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusTile({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
