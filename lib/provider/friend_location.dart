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
    final sslIds = await RsPeers.getFriendList(_authToken);
    final locations = <Location>[];
    for (var i = 0; i < sslIds.length; i++) {
      locations.add(await RsPeers.getPeerFriendDetails(sslIds[i], _authToken));
    }
    _friendlist = locations;
    notifyListeners();
  }

  Future<void> addFriendLocation(String base64Payload) async {
    var isAdded = false;
    if (base64Payload.length < 100) {
      isAdded = await RsPeers.acceptShortInvite(_authToken, base64Payload);
    } else {
      isAdded = await RsPeers.acceptInvite(
        _authToken,
        base64Payload,
      );
    }

    if (!isAdded) throw HttpException('WRONG Certi');
    await RsIdentity.setAutoAddFriendIdsAsContact(true, _authToken);
    await fetchfriendLocation();
  }
}
