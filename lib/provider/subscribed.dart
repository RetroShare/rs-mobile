import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:retroshare/common/notifications.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class ChatLobby with ChangeNotifier {
  List<Chat> _chatlist = [];
  List<VisibleChatLobbyRecord> _unsubscribedlist = [];
  final Set<String> _notifiedInvites = {};
  int _pendingInviteCount = 0;
  List<Chat> get subscribedlist => _chatlist;
  int get pendingInviteCount => _pendingInviteCount;
  AuthToken authToken = const AuthToken('', '');

  List<VisibleChatLobbyRecord> get unSubscribedlist => _unsubscribedlist;

  Future<void> checkForNewInvites() async {
    if (authToken.username.isEmpty) return;
    try {
      final invites = await RsMsgs.getPendingChatLobbyInvites(authToken);
      final inviteCount = invites?.length ?? 0;
      var stateChanged = inviteCount != _pendingInviteCount;
      _pendingInviteCount = inviteCount;

      if (invites == null || invites.isEmpty) {
        _notifiedInvites.clear();
        if (stateChanged) notifyListeners();
        return;
      }

      for (final invite in invites) {
        final lobbyId = invite['lobby_id']?['xstr64'] ?? '';
        if (lobbyId.isNotEmpty && !_notifiedInvites.contains(lobbyId)) {
          final lobbyName = invite['lobby_name'] ?? 'Unknown Room';
          final peerId = invite['peer_id']?.toString() ?? '0';
          
          var senderName = 'A friend';
          try {
            final peerDetails = await RsPeers.getPeerDetails(peerId, authToken);
            senderName = peerDetails.accountName;
          } catch (_) {}

          await showLobbyInviteNotification(lobbyId, lobbyName, senderName);
          _notifiedInvites.add(lobbyId);
          stateChanged = true;
        }
      }
      if (stateChanged) notifyListeners();
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
      final existingUnread = existingChat.chatId != null ? existingChat.unreadCount : 0;

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

  /// Makes a newly joined room visible immediately, then reconciles with the
  /// backend once RetroShare has moved it into the subscribed lobby list.
  void recordJoinedChat(Chat chat) {
    final lobbyId = chat.chatId;
    if (lobbyId == null || lobbyId.isEmpty) return;

    if (!_chatlist.any((item) => item.chatId == lobbyId)) {
      _chatlist = [..._chatlist, chat];
    }
    _unsubscribedlist = _unsubscribedlist
        .where((item) => item.lobbyId?.xstr64 != lobbyId)
        .toList();
    notifyListeners();
    unawaited(_reconcileJoinedLobby(lobbyId));
  }

  Future<void> _reconcileJoinedLobby(String lobbyId) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final subscribed = await RsMsgs.getSubscribedChatLobbies(authToken);
        final isAvailable = subscribed.any(
          (item) => item is Map && item['xstr64']?.toString() == lobbyId,
        );
        if (isAvailable) {
          await fetchAndUpdate();
          await fetchAndUpdateUnsubscribed();
          return;
        }
      } catch (e) {
        debugPrint('Error reconciling joined lobby $lobbyId: $e');
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
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
      final existingUnread = existingChat.chatId != null ? existingChat.unreadCount : 0;

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
