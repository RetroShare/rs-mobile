import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:retroshare/model/http_exception.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FriendLocations with ChangeNotifier {
  static const _pendingFriendNamesKey = 'pending_short_invite_friend_names';
  List<Location> _friendlist = [];
  final Map<String, String> _pendingFriendNames = {};
  bool _pendingFriendNamesLoaded = false;
  List<Location> get friendlist => _friendlist;
  late AuthToken _authToken;

  set authToken(AuthToken authToken) {
    _authToken = authToken;
    notifyListeners();
  }

  AuthToken get authToken => _authToken;

  Future<void> _loadPendingFriendNames() async {
    if (_pendingFriendNamesLoaded) return;
    _pendingFriendNamesLoaded = true;
    final encoded =
        (await SharedPreferences.getInstance()).getString(_pendingFriendNamesKey);
    if (encoded == null) return;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        _pendingFriendNames.addAll(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error loading pending short-invite names: $e');
    }
  }

  Future<void> _savePendingFriendNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pendingFriendNamesKey,
      jsonEncode(_pendingFriendNames),
    );
  }

  Future<void> fetchfriendLocation() async {
    try {
      await _loadPendingFriendNames();
      // Give the native engine a moment to finish disk writes if a friend was just added
      await Future.delayed(const Duration(milliseconds: 500));
      
      final sslIds = await RsPeers.getFriendList(_authToken);
      debugPrint('Fetched ${sslIds.length} friend IDs');
      
      final locations = <Location>[];
      for (var i = 0; i < sslIds.length; i++) {
        try {
          var details = await RsPeers.getPeerFriendDetails(sslIds[i], _authToken);
          try {
            final statusMessage =
                await RsChats.getCustomStateString(sslIds[i], _authToken);
            details = details.copyWith(statusMessage: statusMessage);
          } catch (e) {
            debugPrint(
                'Error fetching status message for friend ${sslIds[i]}: $e',);
          }
          final accountName = details.accountName.trim();
          final pendingName = _pendingFriendNames[sslIds[i]];
          if (accountName.isEmpty && pendingName?.isNotEmpty == true) {
            details = details.copyWith(
              accountName: pendingName ?? '',
              statusMessage: 'Validation pending',
            );
          } else if (accountName.isNotEmpty && pendingName != null) {
            _pendingFriendNames.remove(sslIds[i]);
            await _savePendingFriendNames();
          }
          locations.add(details);
        } catch (e) {
          debugPrint('Error fetching details for friend ${sslIds[i]}: $e');
        }
      }

      // Fetch actual peer statuses (online/away/busy/idle/inactive)
       final statusMap = await RsStatus.getStatusList(_authToken);
       debugPrint('Fetched ${statusMap.length} peer statuses: $statusMap');

      // Merge status into locations
       final locationsWithStatus = <Location>[];
       for (final loc in locations) {
         final peerStatus = statusMap[loc.rsPeerId];
         if (peerStatus != null) {
           locationsWithStatus.add(loc.copyWith(status: peerStatus));
         } else {
           // If no status info, set online (3) if connected, offline (0) if not
           locationsWithStatus.add(
             loc.copyWith(status: loc.isOnline ? 3 : 0),
           );
         }
       }

      _friendlist = locationsWithStatus;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in fetchfriendLocation: $e');
    }
  }

  Future<void> addFriendLocation(String base64Payload) async {
    var isAdded = false;
    var isShortInvite = false;
    String? shortInvitePeerId;
    String? shortInviteName;
    final friendsBefore = (await RsPeers.getFriendList(_authToken)).toSet();
    try {
      var inviteText = base64Payload.trim();
      if (inviteText.contains('%')) {
        try {
          inviteText = Uri.decodeComponent(inviteText);
          debugPrint('Decoded URL-encoded invite: $inviteText');
        } catch (e) {
          debugPrint('Error decoding URL-encoded invite: $e');
        }
      }
      try {
        final shortDetails =
            await RsPeers.parseShortInvite(_authToken, inviteText);
        isShortInvite = true;
        shortInvitePeerId = shortDetails['id'] as String?;
        shortInviteName = shortDetails['name'] as String?;
      } catch (_) {
        isShortInvite = false;
      }

      if (isShortInvite) {
        debugPrint(
          'Adding parsed short invite for peer $shortInvitePeerId',
        );
        isAdded = await RsPeers.acceptShortInvite(_authToken, inviteText);
      } else {
        debugPrint('Adding long invite, length: ${inviteText.length}');
        isAdded = await RsPeers.acceptInvite(
          _authToken,
          inviteText,
        );
      }
    } catch (e) {
      debugPrint('Error in addFriendLocation native call: $e');
      throw HttpException('Failed to add friend: $e');
    }

    if (!isAdded) {
      // Some RetroShare core versions return false after accepting and saving
      // a valid certificate. Verify the authoritative friend list before
      // reporting an error to the user.
      await Future.delayed(const Duration(milliseconds: 500));
      final friendsAfter = (await RsPeers.getFriendList(_authToken)).toSet();
      final newlyAdded = friendsAfter.difference(friendsBefore);
      final shortPeerWasAdded = shortInvitePeerId != null &&
          !friendsBefore.contains(shortInvitePeerId) &&
          friendsAfter.contains(shortInvitePeerId);
      if (newlyAdded.isNotEmpty || shortPeerWasAdded) {
        debugPrint(
          'Friend API returned false, but core added peers: $newlyAdded',
        );
        isAdded = true;
      } else {
        debugPrint(
          'Friend addition returned false; no new peer appeared in friend list',
        );
        throw HttpException('Invalid invite or friend is already added');
      }
    }

    if (isShortInvite &&
        shortInvitePeerId != null &&
        shortInviteName?.trim().isNotEmpty == true) {
      await _loadPendingFriendNames();
      _pendingFriendNames[shortInvitePeerId] = shortInviteName!.trim();
      await _savePendingFriendNames();
    }
    
    try {
      await RsIdentity.setAutoAddFriendIdsAsContact(true, _authToken);
    } catch (e) {
      debugPrint('Error setting auto-add contact: $e');
    }

    // Refresh the list multiple times as the core might take a few seconds to update
    await fetchfriendLocation();
    Future.delayed(const Duration(seconds: 2), fetchfriendLocation);
    Future.delayed(const Duration(seconds: 5), fetchfriendLocation);
  }
}
