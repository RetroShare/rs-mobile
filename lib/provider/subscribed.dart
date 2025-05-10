import 'package:flutter/cupertino.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class ChatLobby with ChangeNotifier {
  List<Chat> _chatlist = [];
  List<VisibleChatLobbyRecord> _unsubscribedlist = [];
  List<Chat> get subscribedlist => _chatlist;
  AuthToken authToken = const AuthToken('', '');

  List<VisibleChatLobbyRecord> get unSubscribedlist => _unsubscribedlist;

  Future<void> fetchAndUpdate() async {
    final list = await RsMsgs.getSubscribedChatLobbies(authToken);
    final chatsList = <Chat>[];
    for (var i = 0; i < list.length; i++) {
      final chatItem =
          await RsMsgs.getChatLobbyInfo(list[i]['xstr64'], authToken);

      chatsList.add(
        Chat(
          chatId: chatItem['lobby_id']['xstr64'],
          chatName: chatItem['lobby_name'],
          lobbyTopic: chatItem['lobby_topic'],
          ownIdToUse: chatItem['gxs_id'],
          autoSubscribe: await RsMsgs.getLobbyAutoSubscribe(
            chatItem['lobby_id']['xstr64'],
            authToken,
          ),
          lobbyFlags: chatItem['lobby_flags'],
          isPublic:
              chatItem['lobby_flags'] == 4 || chatItem['lobby_flags'] == 20,
          interlocutorId: chatItem['gxs_id'],
        ),
      );
    }
    _chatlist = chatsList;
    notifyListeners();
  }

  Future<void> fetchAndUpdateUnsubscribed() async {
    _unsubscribedlist = await RsMsgs.getUnsubscribedChatLobbies(authToken);
    notifyListeners();
  }

  Future<void> unsubscribed(String lobbyId) async {
    await RsMsgs.unsubscribeChatLobby(lobbyId, authToken);
    final list = await RsMsgs.getSubscribedChatLobbies(authToken);
    final chatsList = <Chat>[];
    for (var i = 0; i < list.length; i++) {
      final chatItem =
          await RsMsgs.getChatLobbyInfo(list[i]['xstr64'], authToken);
      chatsList.add(
        Chat(
          chatId: chatItem['lobby_id']['xstr64'],
          chatName: chatItem['lobby_name'],
          lobbyTopic: chatItem['lobby_topic'],
          ownIdToUse: chatItem['gxs_id'],
          autoSubscribe: await RsMsgs.getLobbyAutoSubscribe(
            chatItem['lobby_id']['xstr64'],
            authToken,
          ),
          lobbyFlags: chatItem['lobby_flags'],
          isPublic:
              chatItem['lobby_flags'] == 4 || chatItem['lobby_flags'] == 20,
          interlocutorId: chatItem['gxs_id'],
        ),
      );
    }
    _chatlist = chatsList;
    await fetchAndUpdateUnsubscribed();
  }

  Future<void> createChatlobby(
    String lobbyName,
    String idToUse,
    String lobbyTopic, {
    List<Location> inviteList = const <Location>[],
    bool public = true,
    bool anonymous = true,
  }) async {
    try {
      final success = await RsMsgs.createChatLobby(
        authToken,
        lobbyName,
        idToUse,
        lobbyTopic,
        inviteList: inviteList,
        anonymous: anonymous,
        public: public,
      );
      if (success) await fetchAndUpdate();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
