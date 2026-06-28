import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class FriendLocationDetailScreen extends StatelessWidget {
  const FriendLocationDetailScreen({super.key, required this.location});

  final Location location;

  static String _statusText(int status, bool isOnline) {
    if (!isOnline && status == 0) return 'Offline';
    switch (status) {
      case 3:
        return 'Online';
      case 1:
        return 'Away';
      case 2:
        return 'Busy';
      case 4:
        return 'Inactive';
      default:
        return isOnline ? 'Online' : 'Offline';
    }
  }

  static Color _statusColor(int status, bool isOnline) {
    if (!isOnline && status == 0) return Colors.grey;
    switch (status) {
      case 3:
        return Colors.lightGreenAccent;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.red;
      case 4:
        return Colors.grey.withOpacity(0.8);
      default:
        return isOnline ? Colors.lightGreenAccent : Colors.grey;
    }
  }

  static IconData _statusIcon(int status, bool isOnline) {
    if (!isOnline && status == 0) return Icons.cloud_off;
    switch (status) {
      case 3:
        return Icons.cloud_done;
      case 1:
        return Icons.access_time;
      case 2:
        return Icons.do_not_disturb;
      case 4:
        return Icons.nights_stay;
      default:
        return isOnline ? Icons.cloud_done : Icons.cloud_off;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusStr = _statusText(location.status, location.isOnline);
    final statusClr = _statusColor(location.status, location.isOnline);
    final statusIcn = _statusIcon(location.status, location.isOnline);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        shadowColor: Colors.transparent,
        title: Text(
          'Friend Details',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14.5,
          ),
        ),
        leading: BackButton(
          color: theme.colorScheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- Status badge ---
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surfaceContainerHighest,
                  boxShadow: [
                    BoxShadow(
                      color: statusClr.withOpacity(0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: statusClr, width: 3),
                ),
                child: Icon(
                  Icons.devices,
                  size: 40,
                  color: statusClr,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // --- Account name ---
            Text(
              location.accountName.isNotEmpty
                  ? location.accountName
                  : 'Unknown',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // --- Location name ---
            Text(
              location.locationName.isNotEmpty
                  ? location.locationName
                  : 'No location name',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 12),

            // --- Status chip ---
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusClr.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusClr.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcn, size: 18, color: statusClr),
                  const SizedBox(width: 8),
                  Text(
                    statusStr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: statusClr,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // --- Detail tiles ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _infoTile(
                    context,
                    'Account Name',
                    location.accountName.isNotEmpty
                        ? location.accountName
                        : '—',
                    Icons.person,
                  ),
                  _infoTile(
                    context,
                    'Location Name',
                    location.locationName.isNotEmpty
                        ? location.locationName
                        : '—',
                    Icons.location_on,
                  ),
                  _infoTile(
                    context,
                    'SSL Peer ID',
                    location.rsPeerId.isNotEmpty ? location.rsPeerId : '—',
                    Icons.vpn_key,
                  ),
                  _infoTile(
                    context,
                    'PGP ID',
                    location.rsGpgId.isNotEmpty ? location.rsGpgId : '—',
                    Icons.security,
                  ),
                  _infoTile(
                    context,
                    'Connection',
                    location.isOnline ? 'Connected' : 'Not connected',
                    location.isOnline ? Icons.link : Icons.link_off,
                  ),
                  _infoTile(
                    context,
                    'Status',
                    statusStr,
                    statusIcn,
                    valueColor: statusClr,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: valueColor ?? theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'Oxygen',
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy to clipboard',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copied'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
