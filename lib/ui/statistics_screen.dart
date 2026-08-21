import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const _friendlyServiceNames = <int, String>{
    0x0011: 'Discovery',
    0x0012: 'Chat',
    0x0013: 'Messages',
    0x0014: 'Turtle Router',
    0x0016: 'Heartbeat',
    0x0017: 'File Transfer',
    0x0018: 'Global Router',
    0x0019: 'File Database',
    0x0020: 'Service Info',
    0x0021: 'Bandwidth',
    0x0028: 'GXS Tunnels',
    0x0101: 'Banlist',
    0x0102: 'Status',
    0x0211: 'GXS Identity',
    0x0213: 'GXS Wiki',
    0x0214: 'GXS Wire',
    0x0215: 'GXS Forums',
    0x0216: 'GXS Boards',
    0x0217: 'GXS Channels',
    0x0218: 'GXS Circles',
    0x0219: 'GXS Reputation',
    0x0230: 'GXS Mails',
    0x1011: 'RTT',
    0x2003: 'FeedReader',
  };

  static const _chartColors = <Color>[
    Color(0xFF6750A4),
    Color(0xFF006A6A),
    Color(0xFFBA1A1A),
    Color(0xFF825500),
    Color(0xFF0061A4),
    Color(0xFF386A20),
    Color(0xFF7D5260),
    Color(0xFF5F5E2B),
  ];

  Timer? _refreshTimer;
  double _downloadRate = 0;
  double _uploadRate = 0;
  double _downloadedBytes = 0;
  double _uploadedBytes = 0;
  List<_ServiceTraffic> _serviceTraffic = const [];
  int _touchedSection = -1;
  bool _loading = true;
  bool _requestInProgress = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_requestInProgress) return;
    _requestInProgress = true;
    try {
      final authToken =
          Provider.of<AccountCredentials>(context, listen: false).authtoken;
      if (authToken == null) throw Exception('Not authenticated');

      final responses = await Future.wait([
        rsApiCall(
          '/rsConfig/getTotalBandwidthRates',
          authToken: authToken,
        ),
        rsApiCall(
          '/rsConfig/getCumulativeTrafficByService',
          authToken: authToken,
        ),
        rsApiCall(
          '/rsServiceControl/getOwnServices',
          authToken: authToken,
        ),
      ]);
      final rawRates = responses[0]['rates'];
      if (rawRates is! Map) throw Exception('Traffic data is unavailable');
      final serviceNames = _parseServiceNames(responses[2]);
      final serviceTraffic = _parseServiceTraffic(
        responses[1]['stats'],
        serviceNames,
      );

      if (!mounted) return;
      setState(() {
        _downloadRate = _number(rawRates['mRateIn'] ?? rawRates['rateIn']);
        _uploadRate = _number(rawRates['mRateOut'] ?? rawRates['rateOut']);
        _downloadedBytes = _number(rawRates['mTotalIn'] ?? rawRates['totalIn']);
        _uploadedBytes = _number(rawRates['mTotalOut'] ?? rawRates['totalOut']);
        _serviceTraffic = serviceTraffic;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      _requestInProgress = false;
    }
  }

  static double _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    if (value is Map) {
      return _number(value['xuint64'] ?? value['xint64'] ?? value['xstr64']);
    }
    return 0;
  }

  static List<MapEntry<Object?, Object?>> _mapEntries(Object? value) {
    if (value is List) {
      return value.whereType<Map>().map((entry) {
        return MapEntry(entry['key'], entry['value']);
      }).toList();
    }
    if (value is Map) return value.entries.toList();
    return const [];
  }

  static Map<int, String> _parseServiceNames(Map<String, dynamic> response) {
    final info = response['info'];
    if (info is! Map) return const {};
    final result = <int, String>{};
    for (final entry in _mapEntries(info['mServiceList'])) {
      if (entry.value is! Map) continue;
      final service = entry.value! as Map;
      final fullType = _number(service['mServiceType']).toInt();
      final serviceId = (fullType >> 8) & 0xffff;
      final name = service['mServiceName']?.toString().trim();
      if (name != null && name.isNotEmpty) result[serviceId] = name;
    }
    return result;
  }

  static List<_ServiceTraffic> _parseServiceTraffic(
    Object? rawStats,
    Map<int, String> serviceNames,
  ) {
    final result = <_ServiceTraffic>[];
    for (final entry in _mapEntries(rawStats)) {
      if (entry.value is! Map) continue;
      final stats = entry.value! as Map;
      final serviceId = _number(entry.key).toInt();
      final received = _number(stats['bytesIn']);
      final sent = _number(stats['bytesOut']);
      if (received + sent <= 0) continue;
      result.add(
        _ServiceTraffic(
          name: _friendlyServiceNames[serviceId] ??
              serviceNames[serviceId] ??
              'Service 0x${serviceId.toRadixString(16).padLeft(4, '0')}',
          receivedBytes: received,
          sentBytes: sent,
        ),
      );
    }
    result.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    return result;
  }

  static String _formatRate(double kiloBytesPerSecond) {
    if (kiloBytesPerSecond >= 1024) {
      return '${(kiloBytesPerSecond / 1024).toStringAsFixed(1)} MB/s';
    }
    return '${kiloBytesPerSecond.toStringAsFixed(1)} kB/s';
  }

  static String _formatBytes(double bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    var value = bytes;
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final digits = unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(digits)} ${units[unit]}';
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
          'Statistics',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14.5,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _requestInProgress ? null : _refresh,
            tooltip: 'Refresh statistics',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    _error!,
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ),
              ),
            Text('Current traffic', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    context,
                    icon: Icons.arrow_downward_rounded,
                    color: Colors.green,
                    label: 'Download',
                    value: _formatRate(_downloadRate),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    context,
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.blue,
                    label: 'Upload',
                    value: _formatRate(_uploadRate),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('Traffic by service', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _serviceChart(context),
            const SizedBox(height: 28),
            Text('Transferred', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _totalTile(
                    context,
                    icon: Icons.download_rounded,
                    color: Colors.green,
                    label: 'Downloaded',
                    value: _formatBytes(_downloadedBytes),
                  ),
                  const Divider(height: 1, indent: 64),
                  _totalTile(
                    context,
                    icon: Icons.upload_rounded,
                    color: Colors.blue,
                    label: 'Uploaded',
                    value: _formatBytes(_uploadedBytes),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rates update every 5 seconds. Transferred values are cumulative '
              'totals reported by RetroShare Core.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceChart(BuildContext context) {
    final theme = Theme.of(context);
    if (_serviceTraffic.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No per-service traffic has been recorded yet.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 48,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      final index =
                          response?.touchedSection?.touchedSectionIndex ?? -1;
                      if (index != _touchedSection && mounted) {
                        setState(() => _touchedSection = index);
                      }
                    },
                  ),
                  sections: [
                    for (var index = 0; index < _serviceTraffic.length; index++)
                      PieChartSectionData(
                        value: _serviceTraffic[index].totalBytes,
                        color: _chartColors[index % _chartColors.length],
                        radius: index == _touchedSection ? 62 : 54,
                        title: _serviceTraffic[index].percentageOf(
                          _serviceTraffic.fold(
                            0,
                            (sum, item) => sum + item.totalBytes,
                          ),
                        ),
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < _serviceTraffic.length; index++)
              _serviceLegend(context, _serviceTraffic[index], index),
          ],
        ),
      ),
    );
  }

  Widget _serviceLegend(
    BuildContext context,
    _ServiceTraffic traffic,
    int index,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 3, right: 10),
            decoration: BoxDecoration(
              color: _chartColors[index % _chartColors.length],
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  traffic.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '↓ ${_formatBytes(traffic.receivedBytes)}  '
                  '↑ ${_formatBytes(traffic.sentBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatBytes(traffic.totalBytes),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(35),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(height: 12),
            Text(label, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(35),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ServiceTraffic {
  const _ServiceTraffic({
    required this.name,
    required this.receivedBytes,
    required this.sentBytes,
  });

  final String name;
  final double receivedBytes;
  final double sentBytes;

  double get totalBytes => receivedBytes + sentBytes;

  String percentageOf(double total) {
    if (total <= 0) return '';
    final percentage = totalBytes / total * 100;
    return percentage < 3 ? '' : '${percentage.toStringAsFixed(0)}%';
  }
}
