import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/apiUtils/tor_service.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class NetworkSettingsScreen extends StatefulWidget {
  const NetworkSettingsScreen({super.key});

  @override
  NetworkSettingsScreenState createState() => NetworkSettingsScreenState();
}

class NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  late Future<Map<String, dynamic>> _networkDetailsFuture;
  TorConfiguration? _torConfiguration;
  bool _savingTor = false;
  bool _checkingTor = false;
  bool _refreshingDetails = false;
  bool _hiddenLocationDetected = false;
  bool _hiddenAddressReady = false;
  Timer? _torStatusTimer;

  @override
  void initState() {
    super.initState();
    _refreshDetails();
    _refreshTor();
    _torStatusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        _refreshTor();
        if (_hiddenLocationDetected && !_hiddenAddressReady) {
          _refreshDetails();
        }
      },
    );
  }

  Future<void> _refreshTor() async {
    if (_checkingTor) return;
    _checkingTor = true;
    try {
      final configuration =
          await TorServiceControl.getConfiguration(status: true);
      if (mounted) setState(() => _torConfiguration = configuration);
    } finally {
      _checkingTor = false;
    }
  }

  @override
  void dispose() {
    _torStatusTimer?.cancel();
    super.dispose();
  }

  Future<void> _setTorMode(TorMode? mode, {required bool hiddenLocation}) async {
    if (mode == null) return;
    if (hiddenLocation && mode == TorMode.disabled) return;
    setState(() => _savingTor = true);
    try {
      await TorServiceControl.configure(mode: mode);
      await _refreshTor();
    } finally {
      if (mounted) setState(() => _savingTor = false);
    }
  }

  Future<void> _refreshDetails() async {
    if (_refreshingDetails) return;
    _refreshingDetails = true;
    final future = _fetchNetworkDetails();
    setState(() {
      _networkDetailsFuture = future;
    });
    try {
      final data = await future;
      final details = data['peerDetails'] as Map;
      final torService = data['torHiddenService'] as Map? ?? const {};
      _hiddenLocationDetected = details['isHiddenNode'] == true ||
          details['mIsHiddenNode'] == true ||
          details['hiddenNode'] == true ||
          details['mExtAddr']?.toString().toLowerCase() == 'hidden' ||
          details['extAddr']?.toString().toLowerCase() == 'hidden';
      final address = torService['service_onion_address'] ??
          torService['serviceOnionAddress'] ??
          details['hiddenNodeAddress'] ??
          details['mHiddenNodeAddress'] ??
          details['hiddenAddress'];
      _hiddenAddressReady =
          address != null && address.toString().trim().isNotEmpty;
      _hiddenLocationDetected =
          _hiddenLocationDetected || _hiddenAddressReady;
    } catch (_) {
      // FutureBuilder displays the API error. Keep polling so a temporarily
      // unavailable core can recover without leaving stale network details.
    } finally {
      _refreshingDetails = false;
    }
  }

  Future<Map<String, dynamic>> _fetchNetworkDetails() async {
    final authProvider =
        Provider.of<AccountCredentials>(context, listen: false);
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

    var torHiddenService = <String, dynamic>{};
    try {
      final response = await rsApiCall(
        '/rsTor/getHiddenServiceInfo',
        authToken: authToken,
      );
      if (response['retval'] == true) {
        torHiddenService = Map<String, dynamic>.from(response);
      }
    } catch (e) {
      // Older AARs do not expose the live AutoTor hidden-service getter.
      debugPrint('AutoTor hidden-service info is unavailable: $e');
    }

    var configNetStatus = <String, dynamic>{};
    try {
      final response = await rsApiCall(
        '/rsConfig/getConfigNetStatus',
        authToken: authToken,
      );
      configNetStatus = response['status'] as Map<String, dynamic>? ?? response;
    } catch (e) {
      debugPrint('Error calling getConfigNetStatus: $e');
    }

    return {
      'ownSslId': ownSslId,
      'peerDetails': peerDetails,
      'torHiddenService': torHiddenService,
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
          'Network',
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
            onPressed: () {
              _refreshDetails();
              _refreshTor();
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _networkDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load network status',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.secondary),
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
          final torHiddenService =
              data['torHiddenService'] as Map? ?? const {};
          final netStatus = data['netStatus'] as Map;
          final ownSslId = data['ownSslId'] as String;
          final hiddenAddress =
              (torHiddenService['service_onion_address'] ??
                      torHiddenService['serviceOnionAddress'] ??
                      det['hiddenNodeAddress'] ??
                  det['mHiddenNodeAddress'] ??
                  det['hiddenAddress'] ??
                  '')
              .toString();
          final isHiddenLocation =
              det['isHiddenNode'] == true ||
              det['mIsHiddenNode'] == true ||
              det['hiddenNode'] == true ||
              det['mExtAddr']?.toString().toLowerCase() == 'hidden' ||
              det['extAddr']?.toString().toLowerCase() == 'hidden' ||
              hiddenAddress.trim().isNotEmpty;
          final hiddenPort = (torHiddenService['service_port'] ??
                  torHiddenService['servicePort'] ??
                  det['hiddenNodePort'] ??
                  det['mHiddenNodePort'] ??
                  det['hiddenPort'] ??
                  0)
              .toString();
          final torEnabled =
              isHiddenLocation &&
              _torConfiguration?.mode != null &&
              _torConfiguration!.mode != TorMode.disabled;

          // Resolve internal IP & Port
          final localAddr = det['mLocalAddr'] ??
              det['localAddr'] ??
              netStatus['localAddr'] ??
              netStatus['mLocalAddr'] ??
              'Unknown';
          final localPort = det['mLocalPort']?.toString() ??
              det['localPort']?.toString() ??
              netStatus['localPort']?.toString() ??
              netStatus['mLocalPort']?.toString() ??
              'Unknown';

          // Resolve external IP & Port
          final extAddr = det['mExtAddr'] ??
              det['extAddr'] ??
              netStatus['externalAddr'] ??
              netStatus['extAddr'] ??
              netStatus['mExtAddr'] ??
              'Unknown';
          final extPort = det['mExtPort']?.toString() ??
              det['extPort']?.toString() ??
              netStatus['externalPort']?.toString() ??
              netStatus['extPort']?.toString() ??
              netStatus['mExtPort']?.toString() ??
              'Unknown';

          // Resolve DHT Status
          var isDhtEnabled = false;
          var isDhtConnected = false;

          final dhtVal = netStatus['DHTActive'] ??
              netStatus['dhtActive'] ??
              netStatus['dhtStatus'] ??
              netStatus['dht'] ??
              netStatus['mDhtActive'] ??
              netStatus['mDhtStatus'];
          if (dhtVal is bool) {
            isDhtEnabled = dhtVal;
          } else if (dhtVal is num) {
            isDhtEnabled = dhtVal != 0;
          } else if (dhtVal is String) {
            isDhtEnabled = dhtVal.toLowerCase() == 'true' ||
                dhtVal == '1' ||
                dhtVal.toLowerCase() == 'on';
          } else {
            // Fallback: If network mode is public, DHT is usually on
            final netMode = netStatus['netMode'] ??
                netStatus['networkMode'] ??
                netStatus['mNetMode'] ??
                netStatus['mNetworkMode'];
            if (netMode is num && netMode == 2) {
              isDhtEnabled = true;
            }
          }

          final netDhtOkVal = netStatus['netDhtOk'] ??
              netStatus['netDhtOK'] ??
              netStatus['mNetDhtOk'];
          if (netDhtOkVal is bool) {
            isDhtConnected = netDhtOkVal;
          } else if (netDhtOkVal is num) {
            isDhtConnected = netDhtOkVal != 0;
          } else if (netDhtOkVal is String) {
            isDhtConnected =
                netDhtOkVal.toLowerCase() == 'true' || netDhtOkVal == '1';
          }

          final dhtRsNetworkSize = _readInt(
            netStatus['netDhtRsNetSize'] ?? netStatus['mNetDhtRsNetSize'],
          );
          final dhtNetworkSize = _readInt(
            netStatus['netDhtNetSize'] ?? netStatus['mNetDhtNetSize'],
          );
          final dhtNetworkValues = isDhtEnabled && isDhtConnected
              ? '${_friendlyCount(dhtRsNetworkSize)} (${_friendlyCount(dhtNetworkSize)})'
              : null;

          String dhtText;
          Color dhtColor;
          IconData dhtIcon;

          if (!isDhtEnabled) {
            dhtText = 'Inactive';
            dhtColor = Colors.redAccent;
            dhtIcon = Icons.hub_outlined;
          } else if (!isDhtConnected) {
            dhtText = 'Active (Searching...)';
            dhtColor = Colors.orangeAccent;
            dhtIcon = Icons.sensors_rounded;
          } else {
            dhtText = 'Active';
            dhtColor = Colors.green;
            dhtIcon = Icons.hub_rounded;
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isHiddenLocation) ...[
                    _torCard(
                      context,
                      hiddenLocation: true,
                      hiddenAddress: hiddenAddress,
                      hiddenPort: hiddenPort,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (!torEnabled) ...[
                    // DHT only applies to normal, non-hidden locations.
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: dhtColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: dhtColor.withOpacity(0.3),
                            width: 1.5,
                          ),
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
                  ],

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

                  if (!torEnabled)
                    _statusTile(
                      context: context,
                      title: 'DHT',
                      subtitle: dhtNetworkValues,
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

  Widget _torCard(
    BuildContext context, {
    required bool hiddenLocation,
    required String hiddenAddress,
    required String hiddenPort,
  }) {
    final theme = Theme.of(context);
    final tor = _torConfiguration;
    final torEnabled = tor != null && tor.mode != TorMode.disabled;
    final statusColor = tor?.reachable == true
        ? Colors.green
        : tor?.startRequested == true
            ? Colors.orange
            : torEnabled
                ? Colors.redAccent
                : theme.colorScheme.outline;
    final statusText = tor?.reachable == true
        ? 'Tor Active'
        : tor?.startRequested == true
            ? 'Starting Tor…'
            : torEnabled
                ? 'Tor Not Running'
                : 'Tor Disabled';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, color: statusColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tor runtime',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_savingTor)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  tooltip: 'About Tor modes',
                  onPressed: () => _showTorInfo(context),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TorMode>(
            value: hiddenLocation && tor?.mode == TorMode.disabled
                ? null
                : tor?.mode ??
                    (hiddenLocation ? null : TorMode.disabled),
            hint: const Text('Select Tor runtime'),
            items: [
              if (!hiddenLocation)
                const DropdownMenuItem(
                  value: TorMode.disabled,
                  child: Text('Disabled'),
                ),
              const DropdownMenuItem(
                value: TorMode.embedded,
                child: Text('Embedded Tor'),
              ),
              const DropdownMenuItem(
                value: TorMode.external,
                child: Text('External Tor / Orbot'),
              ),
            ],
            onChanged: _savingTor
                ? null
                : (mode) => _setTorMode(
                      mode,
                      hiddenLocation: hiddenLocation,
                    ),
          ),
          if (tor != null && tor.mode != TorMode.disabled) ...[
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: statusColor.withOpacity(0.45),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_rounded, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                '${tor.host}:${tor.socksPort} SOCKS  ·  '
                '${tor.host}:${tor.controlPort} control',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (tor.version.isNotEmpty) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Tor ${tor.version}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            if (hiddenLocation) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Onion service',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (hiddenAddress.isEmpty)
                      Text(
                        'Creating onion address…',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.orange,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              hiddenPort == '0' || hiddenPort.isEmpty
                                  ? hiddenAddress
                                  : '$hiddenAddress:$hiddenPort',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded),
                            tooltip: 'Copy onion address',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: hiddenAddress),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Onion address copied'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _showTorInfo(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.shield_rounded, color: Colors.deepPurple),
        title: const Text('Tor runtime'),
        content: const Text(
          'Embedded Tor runs the bundled Tor binary inside the RetroShare app. '
          'External Tor connects to Orbot or another Tor service.\n\n'
          'Hidden RetroShare locations require Tor, so Tor cannot be disabled '
          'while a hidden location is active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
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
    String? subtitle,
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
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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

  int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is Map) {
      return _readInt(value['xint64'] ?? value['xstr64'] ?? value['value']);
    }
    return 0;
  }

  String _friendlyCount(int value) {
    if (value < 1000) return value.toString();

    const suffixes = ['k', 'M', 'G', 'T'];
    var scaled = value.toDouble();
    var suffixIndex = -1;
    while (scaled >= 1000 && suffixIndex < suffixes.length - 1) {
      scaled /= 1000;
      suffixIndex++;
    }
    return '${scaled.toStringAsFixed(1)} ${suffixes[suffixIndex]}';
  }
}
