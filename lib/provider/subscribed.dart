import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:retroshare/common/notifications.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class ChatLobby with ChangeNotifier {
  List<Chat> _chatlist = [];
  List<VisibleChatLobbyRecord> _unsubscribedlist = [];
  final Set<String> _notifiedInvites = {};
  List<Chat> get subscribedlist => _chatlist;
  AuthToken authToken = const AuthToken('', '');

  List<VisibleChatLobbyRecord> get unSubscribedlist => _unsubscribedlist;

  Future<void> checkForNewInvites() async {
    if (authToken.username.isEmpty) return;
    try {
      final invites = await RsMsgs.getPendingChatLobbyInvites(authToken);
      if (invites == null || invites.isEmpty) return;

      bool foundNew = false;
      for (final invite in invites) {
        final lobbyId = invite['lobby_id']?['xstr64'] ?? '';
        if (lobbyId.isNotEmpty && !_notifiedInvites.contains(lobbyId)) {
          final lobbyName = invite['lobby_name'] ?? 'Unknown Room';
          final peerId = invite['peer_id']?.toString() ?? '0';
          
          String senderName = 'A friend';
          try {
            final peerDetails = await RsPeers.getPeerDetails(peerId, authToken);
            senderName = peerDetails.accountName;
          } catch (_) {}

          await showLobbyInviteNotification(lobbyId, lobbyName, senderName);
          _notifiedInvites.add(lobbyId);
          foundNew = true;
        }
      }
      if (foundNew) notifyListeners();
    } catch (e) {
      debugPrint('Error checking for invites: $e');
    }
  }

  Future<void> fetchAndUpdate() async {
    final list = await RsMsgs.getSubscribedChatLobbies(authToken);
    final chatsList = <Chat>[];
    for (var i = 0; i < list.length; i++) {
      final chatId = list[i]['xstr64'];
      final chatItem = await RsMsgs.getChatLobbyInfo(chatId, authToken);
      
      // Preserve unread count from existing object if present
      final existingChat = _chatlist.firstWhere(
        (c) => c.chatId == chatId,
        orElse: () => Chat(ownIdToUse: '', interlocutorId: '', isPublic: true),
      );
      final int existingUnread = existingChat.chatId != null ? existingChat.unreadCount : 0;

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
          unreadCount: existingUnread,
        ),
      );
    }
    _chatlist = chatsList;
    notifyListeners();
    unawaited(checkForNewInvites());
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
      final chatId = list[i]['xstr64'];
      final chatItem = await RsMsgs.getChatLobbyInfo(chatId, authToken);
      
      final existingChat = _chatlist.firstWhere(
        (c) => c.chatId == chatId,
        orElse: () => Chat(ownIdToUse: '', interlocutorId: '', isPublic: true),
      );
      final int existingUnread = existingChat.chatId != null ? existingChat.unreadCount : 0;

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
          unreadCount: existingUnread,
        ),
      );
    }
    _chatlist = chatsList;
    await fetchAndUpdateUnsubscribed();
  }

  void incrementUnreadCount(String lobbyId) {
    final index = _chatlist.indexWhere((c) => c.chatId == lobbyId);
    if (index != -1) {
      _chatlist[index].unreadCount++;
      notifyListeners();
    }
  }

  void resetUnreadCount(String lobbyId) {
    final index = _chatlist.indexWhere((c) => c.chatId == lobbyId);
    if (index != -1) {
      _chatlist[index].unreadCount = 0;
      notifyListeners();
    }
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
