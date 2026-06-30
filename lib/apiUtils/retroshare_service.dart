import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:retroshare_api_wrapper/retroshare.dart' as rs;

const rsPlatform = MethodChannel(rs.RETROSHARE_CHANNEL_NAME);

void setControlCallbacks() {
  rs.setStartCallback(RsServiceControl.startRetroshare);
}

// The wrapper's isRetroshareRunning() only accepts 2xx responses, but the RS
// JSON API root returns a non-2xx status. Accept any HTTP response as proof
// the service is up.
Future<bool> _isRsApiReachable() async {
  try {
    await http
        .get(Uri.parse('http://${rs.RETROSHARE_HOST}:${rs.RETROSHARE_PORT}'))
        .timeout(const Duration(seconds: 3));
    return true;
  } catch (_) {
    return false;
  }
}

class RsServiceControl {
  static Future<bool>? _startFuture;

  static Future<bool> startRetroshare() {
    _startFuture ??= _doStartRetroshare().whenComplete(() {
      _startFuture = null;
    });
    return _startFuture!;
  }

  static Future<bool> _doStartRetroshare() async {
    try {
      if (await _isRsApiReachable()) return true;
    } catch (_) {}

    try {
      await rsPlatform.invokeMethod('start');
    } catch (err) {
      print('Failed to invoke RS start: $err');
    }

    for (var attempts = 20; attempts > 0; attempts--) {
      print('Starting Retroshare Service. Attempts countdown $attempts');
      await Future.delayed(const Duration(seconds: 2));
      try {
        if (await _isRsApiReachable()) return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<void> stopRetroshare() async {
    try {
      await rsPlatform.invokeMethod('stop');

      await Future.delayed(const Duration(milliseconds: 3000));
      final isUp = await rs.isRetroshareRunning();
      if (isUp) throw Exception('The service did not stop after a while');
    } catch (err) {
      throw Exception('The service could not be stopped');
    }
  }

  static Future<void> restartRetroshare() async {
    try {
      await rsPlatform.invokeMethod('restart');

      await Future.delayed(const Duration(milliseconds: 300));
      final isUp = await rs.isRetroshareRunning();
      if (!isUp) throw Exception('The service did not restart after a while');
    } catch (err) {
      throw Exception('The service could not be restarted');
    }
  }
}

Future<void> copyBdbootToConfigDir() async {
  try {
    final supportDir = await getApplicationSupportDirectory();
    final parentDir = supportDir.parent;

    // We will copy to both the parent directory and the files directory config locations
    final configPaths = [
      Directory('${parentDir.path}/.retroshare'),
      Directory('${supportDir.path}/.retroshare'),
    ];

    final data = await rootBundle.load('assets/bdboot.txt');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    for (final rsConfigDir in configPaths) {
      if (!await rsConfigDir.exists()) {
        await rsConfigDir.create(recursive: true);
      }

      final bdbootFile = File('${rsConfigDir.path}/bdboot.txt');
      await bdbootFile.writeAsBytes(bytes);
      print('Successfully copied bdboot.txt to config root: ${rsConfigDir.path}');

      // List all entities in the `.retroshare` directory to copy into individual location folders
      await for (final entity in rsConfigDir.list(recursive: false)) {
        if (entity is Directory) {
          final dirName = entity.path.split(Platform.pathSeparator).lastWhere((element) => element.isNotEmpty);
          if (dirName.startsWith('LOC06_')) {
            final targetBdboot = File('${entity.path}/bdboot.txt');
            await targetBdboot.writeAsBytes(bytes);
            print('Successfully copied bdboot.txt to location directory: ${entity.path}');
          }
        }
      }
    }
  } catch (e) {
    print('Error copying bdboot.txt to config directories: $e');
  }
}
