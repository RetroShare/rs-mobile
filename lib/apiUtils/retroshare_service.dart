import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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
  static Process? _process;

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
      if (Platform.isWindows) {
        // Clean up any zombie daemon processes from previous runs
        try {
          await Process.run('taskkill', ['/f', '/im', 'retroshare-service.exe']);
        } catch (_) {}

        final exePath = Platform.resolvedExecutable;
        final exeDir = File(exePath).parent.path;
        final servicePath = '$exeDir/retroshare-service.exe';
        if (await File(servicePath).exists()) {
          print('Starting Retroshare Service at $servicePath');
          final dataDir = '$exeDir/data';
          final dir = Directory(dataDir);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          _process = await Process.start(servicePath, ['--base-dir', dataDir]);

          // Drain stdout and stderr to prevent the process from hanging due to full buffer
          _process!.stdout.listen((data) {
            final output = String.fromCharCodes(data);
            print('RS-Service stdout: $output');
          });
          _process!.stderr.listen((data) {
            final output = String.fromCharCodes(data);
            print('RS-Service stderr: $output');
          });

          unawaited(_process!.exitCode.then((code) {
            print('retroshare-service.exe exited with code $code');
            _process = null;
          }));
        } else {
          print('retroshare-service.exe not found in app directory: $servicePath');
        }
      } else {
        await rsPlatform.invokeMethod('start');
      }
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

  static Future<void> stopRetroshare({bool wait = true}) async {
    try {
      if (Platform.isWindows) {
        if (_process != null) {
          _process!.kill();
          _process = null;
        }
      } else {
        await rsPlatform.invokeMethod('stop');
      }

      if (wait) {
        await Future.delayed(const Duration(milliseconds: 3000));
        final isUp = await rs.isRetroshareRunning();
        if (isUp) throw Exception('The service did not stop after a while');
      }
    } catch (err) {
      throw Exception('The service could not be stopped');
    }
  }

  static Future<void> restartRetroshare() async {
    try {
      if (Platform.isWindows) {
        if (_process != null) {
          _process!.kill();
          _process = null;
        }
        await _doStartRetroshare();
      } else {
        await rsPlatform.invokeMethod('restart');
      }

      await Future.delayed(const Duration(milliseconds: 300));
      final isUp = await rs.isRetroshareRunning();
      if (!isUp) throw Exception('The service did not restart after a while');
    } catch (err) {
      throw Exception('The service could not be restarted');
    }
  }
}
