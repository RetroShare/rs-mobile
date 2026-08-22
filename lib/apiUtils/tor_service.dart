import 'dart:io';

import 'package:flutter/services.dart';
import 'package:retroshare/apiUtils/retroshare_service.dart' show rsPlatform;
import 'package:retroshare_api_wrapper/retroshare.dart';

enum TorMode { disabled, embedded, external }

class TorConfiguration {
  const TorConfiguration({
    required this.mode,
    required this.host,
    required this.socksPort,
    required this.controlPort,
    this.version = '',
    this.reachable = false,
    this.startRequested = false,
  });

  final TorMode mode;
  final String host;
  final int socksPort;
  final int controlPort;
  final String version;
  final bool reachable;
  final bool startRequested;

  factory TorConfiguration.fromMap(Map<Object?, Object?> value) {
    final modeName = value['mode']?.toString() ?? 'disabled';
    return TorConfiguration(
      mode: TorMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => TorMode.disabled,
      ),
      host: value['host']?.toString() ?? '127.0.0.1',
      socksPort: (value['socksPort'] as num?)?.toInt() ?? 9050,
      controlPort: (value['controlPort'] as num?)?.toInt() ?? 9051,
      version: value['version']?.toString() ?? '',
      reachable: value['reachable'] == true,
      startRequested: value['startRequested'] == true,
    );
  }
}

class TorServiceControl {
  static Future<bool> isHiddenLocation(String locationId) async {
    if (!Platform.isAndroid) return false;
    return await rsPlatform.invokeMethod<bool>(
          'isHiddenLocation',
          {'locationId': locationId},
        ) ??
        false;
  }

  static Future<void> startConfiguredRuntime() async {
    if (!Platform.isAndroid) return;
    await rsPlatform.invokeMethod<void>('startTor');
  }

  static Future<void> stopRuntime() async {
    if (!Platform.isAndroid) return;
    await rsPlatform.invokeMethod<void>('stopTor');
  }

  static Future<TorConfiguration> getConfiguration({bool status = false}) async {
    if (!Platform.isAndroid) {
      return const TorConfiguration(
        mode: TorMode.disabled,
        host: '127.0.0.1',
        socksPort: 9050,
        controlPort: 9051,
      );
    }
    final value = await rsPlatform.invokeMapMethod<Object?, Object?>(
      status ? 'getTorStatus' : 'getTorConfiguration',
    );
    return TorConfiguration.fromMap(value ?? const {});
  }

  static Future<TorConfiguration> configure({
    required TorMode mode,
    String host = '127.0.0.1',
    int socksPort = 9050,
    int controlPort = 9051,
  }) async {
    final value = await rsPlatform.invokeMapMethod<Object?, Object?>(
      'setTorConfiguration',
      {
        'mode': mode.name,
        'host': host,
        'socksPort': socksPort,
        'controlPort': controlPort,
      },
    );
    return TorConfiguration.fromMap(value ?? const {});
  }

  /// Pass the selected runtime to libretroshare. This endpoint is intentionally
  /// best-effort so the UI also works with older AARs. Hidden-node login needs
  /// libretroshare with RsTor::setExternalTorConnection exposed as JSON API.
  static Future<bool> configureBackend(
    AuthToken? authToken,
    TorConfiguration configuration,
  ) async {
    if (configuration.mode == TorMode.disabled) return true;
    try {
      final response = await rsApiCall(
        '/rsTor/setExternalTorConnection',
        authToken: authToken,
        params: {
          'controlAddress': configuration.host,
          'controlPort': configuration.controlPort,
          'socksAddress': configuration.host,
          'socksPort': configuration.socksPort,
          'controlPassword': '',
        },
      );
      return response['retval'] == true;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
