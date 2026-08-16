import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:retroshare/apiUtils/tor_service.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

String deriveApiToken(String locationId, String password) {
  final bytes = utf8.encode('$locationId:$password');
  return sha256.convert(bytes).toString();
}

class AccountCredentials with ChangeNotifier {
  List<Account> _accountsList = [];
  Account? _lastAccountUsed;
  Account? _loggedinAccount;
  AuthToken? _authToken;
  String? _pgpPassword;
  Account? get lastAccountUsed => _lastAccountUsed;
  List<Account> get accountList => _accountsList;
  Account? get loggedinAccount => _loggedinAccount;
  AuthToken? get getAuthToken => _authToken;
  String? get getPgpPassword => _pgpPassword;

  set logginAccount(Account acc) {
    _loggedinAccount = acc;
  }

  AuthToken? get authtoken => _authToken;

  Future<void> fetchAuthAccountList() async {
    try {
      final resp = await RsLoginHelper.getLocations();
      final accountsList = <Account>[];
      resp.forEach((location) {
        if (location != null) {
          accountsList.add(
            Account(
              locationId: location['mLocationId'],
              pgpId: location['mPgpId'],
              locationName: location['mLocationName'],
              pgpName: location['mPgpName'],
            ),
          );
        }
      });
      _accountsList = [];
      _accountsList = accountsList;
      notifyListeners();
      _lastAccountUsed = await setLastAccountUsed();
    } catch (e) {
      throw HttpException(e.toString());
    }
  }

  Account? get getlastAccountUsed => _lastAccountUsed;

  Future<Account?> setLastAccountUsed() async {
    if (_authToken == null) {
      return null;
    }
    final currAccount = await RsAccounts.getCurrentAccountId(_authToken!);
    for (final account in _accountsList) {
      if (account.locationId == currAccount) return account;
    }
    // Return the first account if available, otherwise throw
    if (_accountsList.isNotEmpty) {
      return _accountsList.first;
    }
    throw Exception('No account found for setLastAccountUsed');
  }

  Future<bool> getinitializeAuth(Account account, String password) async {
    // Retry logic as the core might take a moment to initialize the API for the unlocked account
    for (var retry = 0; retry < 3; retry++) {
      if (retry > 0) {
        await Future.delayed(const Duration(seconds: 1));
      }

      // Try pgpName (PGP Username) - most robust for multiple locations without core changes
      _authToken =
          AuthToken(account.pgpName, deriveApiToken(account.pgpName, password));
      final success = await RsJsonApi.isAuthTokenValid(_authToken!);
      if (success) return true;
    }

    // Default back to pgpName if all failed
    _authToken =
        AuthToken(account.pgpName, deriveApiToken(account.pgpName, password));
    return false;
  }

  Future<bool> checkIsValidAuthToken() async {
    return _authToken == null ? false : RsJsonApi.isAuthTokenValid(_authToken!);
  }

  Future<void> login(Account currentAccount, String password) async {
    await _configureTorBeforeLogin();
    final int resp = await RsLoginHelper.requestLogIn(
      currentAccount,
      password,
      currentAccount.pgpName,
      deriveApiToken(currentAccount.pgpName, password),
    );
    logginAccount = currentAccount;
    // Login success 0, already logged in 1
    if (resp == 0 || resp == 1) {
      _pgpPassword = password;
      final isAuthTokenValid =
          await getinitializeAuth(currentAccount, password);
      if (!isAuthTokenValid) {
        throw const HttpException('AUTHTOKEN FAILED');
      }
      notifyListeners();
    } else {
      throw const HttpException('WRONG PASSWORD');
    }
  }

  Future<void> signup(String username, String password, String nodename) async {
    await _configureTorBeforeLogin();
    final resp = await RsLoginHelper.requestAccountCreation(
      username,
      password,
      nodename.isEmpty ? 'mobile' : nodename,
      username,
      deriveApiToken(username, password),
    );
    print('DEBUG signup response: $resp');
    final account = (
      resp['retval']['errorNumber'] == 0,
      Account(
        locationId: resp['locationId'],
        pgpId: resp['pgpId'],
        locationName: username,
        pgpName: username,
      ),
    );
    if (account.$1) {
      _pgpPassword = password;
      _accountsList.add(account.$2);
      logginAccount = account.$2;
      final isAuthTokenValid = await getinitializeAuth(account.$2, password);
      if (!isAuthTokenValid) throw const HttpException('AUTHTOKEN FAILED');

      notifyListeners();
    } else {
      print('DEBUG signup failed. retval: ${resp['retval']}');
      throw const HttpException('DATA INSUFFICIENT');
    }
  }

  Future<void> _configureTorBeforeLogin() async {
    if (!Platform.isAndroid) return;
    final configuration = await TorServiceControl.getConfiguration(status: true);
    if (configuration.mode == TorMode.embedded && !configuration.reachable) {
      // Tor bootstrapping continues asynchronously. The control listener is
      // created before circuits are ready, so libretroshare can attach now.
      await Future.delayed(const Duration(milliseconds: 500));
    }
    await TorServiceControl.configureBackend(null, configuration);
  }

  Future<void> importAccount(String base64Cert, String password) async {
    try {
      final resp = await RsLoginHelper.importLocation(base64Cert, password);
      if (resp['retval'] == true ||
          (resp['retval'] is Map && resp['retval']['errorNumber'] == 0)) {
        await fetchAuthAccountList();
        notifyListeners();
      } else {
        throw HttpException(resp['retval']?['errorMessage'] ?? 'Import failed');
      }
    } catch (e) {
      throw HttpException(e.toString());
    }
  }

  Future<void> importIdentityAndCreateLocation(
    String pgpKeyContent,
    String password, {
    String nodeName = 'mobile',
  }) async {
    try {
      final importResp = await rsApiCall(
        '/rsAccounts/importIdentityFromString',
        params: {'data': pgpKeyContent},
      );
      if (!_isSuccessfulResult(importResp['retval'])) {
        throw HttpException(
          _apiErrorMessage(importResp, 'The PGP profile could not be imported'),
        );
      }

      final pgpId = (importResp['pgpId'] ?? importResp['gpgId'])?.toString();
      if (pgpId == null || pgpId.isEmpty) {
        throw const HttpException(
            'The imported profile did not return a PGP ID');
      }

      final locationName = nodeName.trim().isEmpty ? 'mobile' : nodeName.trim();
      final apiUser = 'mobile-$pgpId';
      final apiPass = deriveApiToken(apiUser, password);
      final createResp = await rsApiCall(
        '/rsLoginHelper/createLocationV2',
        params: {
          'pgpId': pgpId,
          'locationName': locationName,
          // The core ignores pgpName when an existing pgpId is supplied.
          'pgpName': '',
          'password': password,
          'apiUser': apiUser,
          'apiPass': apiPass,
        },
      );
      if (!_isSuccessfulResult(createResp['retval'])) {
        throw HttpException(
          _apiErrorMessage(
              createResp, 'Could not create a location from this profile'),
        );
      }

      _pgpPassword = password;
      _authToken = AuthToken(apiUser, apiPass);
      await fetchAuthAccountList();

      final locationId = createResp['locationId']?.toString();
      Account? importedAccount;
      for (final account in _accountsList) {
        if ((locationId != null && account.locationId == locationId) ||
            account.pgpId == pgpId) {
          importedAccount = account;
          if (locationId != null && account.locationId == locationId) break;
        }
      }
      if (importedAccount == null) {
        throw const HttpException(
          'The new location was created but could not be found in the account list',
        );
      }
      _loggedinAccount = importedAccount;
      _lastAccountUsed = importedAccount;
      notifyListeners();
    } catch (e) {
      if (e is HttpException) rethrow;
      throw HttpException(e.toString());
    }
  }

  bool _isSuccessfulResult(dynamic result) {
    if (result is bool) return result;
    if (result is num) return result == 1 || result == 0;
    if (result is Map) return result['errorNumber'] == 0;
    return false;
  }

  String _apiErrorMessage(Map response, String fallback) {
    final retval = response['retval'];
    final message = response['errorMsg'] ??
        response['errorMessage'] ??
        (retval is Map ? retval['errorMessage'] : null);
    final text = message?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }
}
