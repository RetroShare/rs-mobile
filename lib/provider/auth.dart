import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
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
    for (int retry = 0; retry < 3; retry++) {
      if (retry > 0) {
        await Future.delayed(const Duration(seconds: 1));
      }

      // Try locationId (SSL ID) - most robust for multiple locations
      _authToken = AuthToken(account.locationId, deriveApiToken(account.locationId, password));
      bool success = await RsJsonApi.isAuthTokenValid(_authToken!);
      if (success) return true;
    }

    // Default back to locationId if all failed
    _authToken = AuthToken(account.locationId, deriveApiToken(account.locationId, password));
    return false;
  }

  Future<bool> checkIsValidAuthToken() async {
    return _authToken == null ? false : RsJsonApi.isAuthTokenValid(_authToken!);
  }

  Future<void> login(Account currentAccount, String password) async {
    final int resp = await RsLoginHelper.requestLogIn(
      currentAccount,
      password,
      currentAccount.locationId,
      deriveApiToken(currentAccount.locationId, password),
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
      await login(account.$2, password);
    } else {
      print('DEBUG signup failed. retval: ${resp['retval']}');
      throw const HttpException('DATA INSUFFICIENT');
    }
  }

  Future<void> importAccount(String base64Cert, String password) async {
    try {
      final resp = await RsLoginHelper.importLocation(base64Cert, password);
      if (resp['retval'] == true || (resp['retval'] is Map && resp['retval']['errorNumber'] == 0)) {
        await fetchAuthAccountList();
        notifyListeners();
      } else {
        throw HttpException(resp['retval']?['errorMessage'] ?? 'Import failed');
      }
    } catch (e) {
      throw HttpException(e.toString());
    }
  }

  Future<void> importIdentityAndCreateLocation(String pgpKeyContent, String password) async {
    try {
      final importResp = await RsAccounts.importIdentity(pgpKeyContent);
      if (importResp['retval'] != true) {
        throw HttpException(importResp['errorMessage'] ?? 'Import Identity failed');
      }

      final String? gpgId = importResp['gpg_id'];
      if (gpgId == null) {
        throw const HttpException('Import Identity failed: gpg_id not found');
      }

      final createResp = await RsLoginHelper.createLocation(gpgId, password);
      if (createResp['retval'] != true) {
        throw HttpException(createResp['errorMessage'] ?? 'Create Location failed');
      }

      await fetchAuthAccountList();
      notifyListeners();
    } catch (e) {
      throw HttpException(e.toString());
    }
  }
}
