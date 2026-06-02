import 'package:flutter/cupertino.dart';
import 'package:retroshare/model/http_exception.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class FriendLocations with ChangeNotifier {
  List<Location> _friendlist = [];
  List<Location> get friendlist => _friendlist;
  late AuthToken _authToken;

  set authToken(AuthToken authToken) {
    _authToken = authToken;
    notifyListeners();
  }

  AuthToken get authToken => _authToken;

  Future<void> fetchfriendLocation() async {
    try {
      // Give the native engine a moment to finish disk writes if a friend was just added
      await Future.delayed(const Duration(milliseconds: 500));
      
      final sslIds = await RsPeers.getFriendList(_authToken);
      debugPrint('Fetched ${sslIds.length} friend IDs');
      
      final locations = <Location>[];
      for (var i = 0; i < sslIds.length; i++) {
        try {
          final details = await RsPeers.getPeerFriendDetails(sslIds[i], _authToken);
          locations.add(details);
        } catch (e) {
          debugPrint('Error fetching details for friend ${sslIds[i]}: $e');
        }
      }
      _friendlist = locations;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in fetchfriendLocation: $e');
    }
  }

  Future<void> addFriendLocation(String base64Payload) async {
    var isAdded = false;
    try {
      final inviteText = base64Payload.trim();
      if (inviteText.length < 100) {
        debugPrint('Adding short invite: $inviteText');
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
      debugPrint('Friend addition returned false');
      throw HttpException('Invalid certificate or already added');
    }
    
    try {
      await RsIdentity.setAutoAddFriendIdsAsContact(true, _authToken);
    } catch (e) {
      debugPrint('Error setting auto-add contact: $e');
    }

    // Refresh the list multiple times as the core might take a few seconds to update
    await fetchfriendLocation();
    Future.delayed(const Duration(seconds: 2), () => fetchfriendLocation());
    Future.delayed(const Duration(seconds: 5), () => fetchfriendLocation());
  }
}
