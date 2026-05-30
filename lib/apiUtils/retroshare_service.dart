import 'package:flutter/services.dart';
import 'package:retroshare_api_wrapper/retroshare.dart' as rs;
import 'package:retroshare_api_wrapper/retroshare.dart';

const rsPlatform = MethodChannel(rs.RETROSHARE_CHANNEL_NAME);

void setControlCallbacks() {
  rs.setStartCallback(RsServiceControl.startRetroshare);
}

class RsServiceControl {
  static Future<bool> startRetroshare() async {
    try {
      if (await isRetroshareRunning()) return true;
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
        if (await isRetroshareRunning()) return true;
      } catch (_) {}
    }
    return false;
  }

  static Future<void> stopRetroshare() async {
    try {
      await rsPlatform.invokeMethod('stop');

      await Future.delayed(const Duration(milliseconds: 3000));
      final isUp = await isRetroshareRunning();
      if (isUp) throw Exception('The service did not stop after a while');
    } catch (err) {
      throw Exception('The service could not be stopped');
    }
  }

  static Future<void> restartRetroshare() async {
    try {
      await rsPlatform.invokeMethod('restart');

      await Future.delayed(const Duration(milliseconds: 300));
      final isUp = await isRetroshareRunning();
      if (!isUp) throw Exception('The service did not restart after a while');
    } catch (err) {
      throw Exception('The service could not be restarted');
    }
  }
}
