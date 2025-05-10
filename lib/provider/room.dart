import 'package:flutter/cupertino.dart';
import 'package:retroshare/model/http_exception.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

// Helper function for distant chat ID
String _generateDistantChatId(String id1, String id2) {
  return id1.compareTo(id2) < 0 ? '${id1}_$id2' : '${id2}_$id1';
}

class RoomChatLobby with ChangeNotifier {
  // Lobby participants by lobby ID
  Map<String, List<Identity>> _lobbyParticipants = {};
  // Distant chats by chat ID
  Map<String, Chat> _distanceChat = {};
  // Currently selected chat
  Chat? _currentChat;
  // Messages by chat ID
  Map<String, List<ChatMessage>> _messagesList = {};

  /// Returns a copy of the lobby participants map.
  Map<String, List<Identity>> get lobbyParticipants => {..._lobbyParticipants};

  /// Returns a copy of the distant chat map.
  Map<String, Chat> get distanceChat => {..._distanceChat};

  /// Returns a copy of the messages list map.
  Map<String, List<ChatMessage>> get messagesList => {..._messagesList};

  // All known identities by ID
  Map<String, Identity> _allIdentity = {};
  // Friends (contact) identities
  List<Identity> _friendsIdsList = [];
  // Not-contact identities
  List<Identity> _notContactIds = [];
  // Signed friends identities
  List<Identity> _friendsSignedIdsList = [];

  /// Returns a copy of all known identities.
  Map<String, Identity> get allIdentity => {..._allIdentity};

  /// Returns a copy of the friends IDs list.
  List<Identity> get friendsIdsList => [..._friendsIdsList];

  /// Returns a copy of the not-contact IDs list.
  List<Identity> get notContactIds => [..._notContactIds];

  /// Returns a copy of the signed friends IDs list.
  List<Identity> get friendsSignedIdsList => [..._friendsSignedIdsList];

  late AuthToken _authToken;

  /// Sets the authentication token for API calls.
  set authToken(AuthToken authToken) {
    _authToken = authToken;
  }

  /// Returns the current authentication token.
  AuthToken get authToken => _authToken;

  Future<void> fetchAndUpdate() async {
    try {
      final tupleIds = await getAllIdentities(_authToken);
      _friendsSignedIdsList = tupleIds.$1;
      _friendsIdsList = tupleIds.$2;
      _notContactIds = tupleIds.$3;
      _allIdentity = {
        for (final id in [tupleIds.$1, tupleIds.$2, tupleIds.$3]
            .expand((x) => x)
            .toList())
          id.mId: id,
      };
      notifyListeners();
    } catch (e) {
      debugPrint('Error in fetchAndUpdate: $e');
      rethrow;
    }
  }

  Future<void> setAllIds(Chat chat) async {
    final interlocutorId = chat.interlocutorId;
    if (_allIdentity[interlocutorId] == null) {
      _allIdentity = Map.from(_allIdentity)
        ..[interlocutorId] = Identity(
          mId: interlocutorId,
          signed: false,
          isContact: false,
        );
      notifyListeners();
    }
  }

  Future<void> toggleContacts(String gxsId, bool type) async {
    try {
      final success = await RsIdentity.setContact(gxsId, type, _authToken);
      if (!success) {
        throw HttpException('Failed to toggle contact status.');
      } else {
        await fetchAndUpdate();
      }
    } catch (e) {
      debugPrint('Error in toggleContacts: $e');
      rethrow;
    }
  }

  /// Returns the currently selected chat.
  Chat? get currentChat => _currentChat;

  Future<void> updateParticipants(String lobbyId) async {
    try {
      final participants = <Identity>[];
      final gxsIds = await RsMsgs.getLobbyParticipants(lobbyId, _authToken);

      for (var i = 0; i < gxsIds.length; i++) {
        final key = gxsIds[i]?['key'] as String?;
        if (key == null) continue;

        try {
          var success = false;
          Identity? id;
          var retries = 3;
          do {
            final tuple = await getIdDetails(key, _authToken);
            success = tuple.item1;
            id = tuple.item2;
            if (!success)
              await Future.delayed(const Duration(milliseconds: 200));
            retries--;
          } while (!success && retries > 0);

          participants.add(id);
        } catch (e) {
          debugPrint('Error fetching details for participant key $key: $e');
        }
      }
      _lobbyParticipants = Map.from(_lobbyParticipants)
        ..[lobbyId] = participants;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in updateParticipants for lobby $lobbyId: $e');
      rethrow;
    }
  }

  void updateCurrentChat(Chat? chat) {
    if (_currentChat?.chatId != chat?.chatId) {
      _currentChat = chat;
      notifyListeners();
    }
  }

  void addDistanceChat(Chat distantChat) {
    final chatId = distantChat.chatId;
    if (chatId == null) return;

    _distanceChat = Map.from(_distanceChat)..[chatId] = distantChat;
    _messagesList = Map.from(_messagesList)..putIfAbsent(chatId, () => []);
    notifyListeners();
  }

  void addChatMessage(ChatMessage message, String chatId) {
    final currentList = _messagesList[chatId] ?? [];
    _messagesList = Map.from(_messagesList)
      ..[chatId] = [...currentList, message];
    notifyListeners();
  }

  int getUnreadCount(Identity iden, Identity idToUse) {
    final idenId = iden.mId;
    final idToUseId = idToUse.mId;
    if (idToUseId == null) return 0;

    final key = _generateDistantChatId(idenId, idToUseId);
    return _distanceChat[key]?.unreadCount ?? 0;
  }

  Future<void> sendMessage(
    String chatId,
    String msgTxt, [
    ChatIdType type = ChatIdType.type2,
  ]) async {
    try {
      final res = await RsMsgs.sendMessage(chatId, msgTxt, _authToken, type);
      if (res) {
        final message = ChatMessage(
          chatId: ChatId(
            distantChatId: chatId,
            type: type,
          ),
          msg: msgTxt,
          incoming: false,
          sendTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          recvTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        addChatMessage(message, chatId);
      } else {
        throw HttpException('Failed to send message (API returned false).');
      }
    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      rethrow;
    }
  }

  void chatActionMiddleware(Chat distancechat) {
    final interlocutorId = distancechat.interlocutorId;
    if (_allIdentity[interlocutorId] == null) {
      final identity = Identity(
        mId: interlocutorId,
        signed: false,
        isContact: false,
        name: distancechat.chatName,
      );
      callrequestIdentity(identity);
    }
  }

  String getChatSenderName(ChatMessage message) {
    if (message.isLobbyMessage()) {
      final lobbyPeerGxsId = message.lobbyPeerGxsId;
      if (lobbyPeerGxsId == null) return 'Unknown Lobby User';

      final lobbyId = message.chatId?.lobbyId?.xstr64;
      if (lobbyId != null) {
        final participants = _lobbyParticipants[lobbyId];
        Identity? identity;
        if (participants != null) {
          for (final id in participants) {
            if (id.mId == lobbyPeerGxsId) {
              identity = id;
              break;
            }
          }
        }
        return identity?.name ?? lobbyPeerGxsId;
      }
      return lobbyPeerGxsId;
    } else {
      final distantChatId = message.chatId?.distantChatId;
      if (distantChatId == null) return 'Unknown User';

      final chatInfo = _distanceChat[distantChatId];
      final interlocutorIdFromChat = chatInfo?.interlocutorId;
      if (interlocutorIdFromChat == null) return 'Unknown User';

      final identity = _allIdentity[interlocutorIdFromChat];
      if (identity == null) {
        callrequestIdentity(
          Identity(
            mId: interlocutorIdFromChat,
            signed: false,
            isContact: false,
          ),
        );
        return interlocutorIdFromChat;
      }
      return identity.name ?? identity.mId ?? 'Unknown User';
    }
  }

  Future<String?> initiateDistantChat(Chat chat) async {
    final toId = chat.interlocutorId;
    final fromId = chat.ownIdToUse;
    if (fromId == null) {
      throw Exception(
        'Missing interlocutorId or ownIdToUse for initiating chat',
      );
    }

    try {
      final resp = await RsMsgs.c(chat, _authToken);
      if (resp['retval'] == true && resp['pid'] is String) {
        final newChatId = resp['pid'] as String;
        chatActionMiddleware(chat);
        return newChatId;
      } else {
        throw Exception(
          'API error initiating distant chat: ${resp['retval'] ?? 'Unknown'}',
        );
      }
    } catch (e) {
      debugPrint('Error in initiateDistantChat: $e');
      rethrow;
    }
  }

  Chat? getChat(
    Identity currentIdentity,
    dynamic to,
  ) {
    Chat? chat;
    final currentId = currentIdentity.mId;

    if (to is Identity) {
      final toId = to.mId;

      final distantChatId = _generateDistantChatId(toId, currentId);
      if (_distanceChat.containsKey(distantChatId)) {
        chat = _distanceChat[distantChatId];
      } else {
        final initialChat = Chat(
          interlocutorId: toId,
          isPublic: false,
          chatName: to.name,
          numberOfParticipants: 1,
          ownIdToUse: currentId,
        );
        initiateDistantChat(initialChat).then((newChatId) {
          if (newChatId != null) {
            try {
              final finalChat = initialChat.copyWith(chatId: newChatId);
              addDistanceChat(finalChat);
            } catch (e) {
              debugPrint(
                'Error using copyWith on Chat: $e. Is it a freezed class?',
              );
            }
          }
        }).catchError((e) {
          debugPrint('Failed to auto-initiate chat: $e');
        });
        chat = initialChat;
      }
    } else if (to is VisibleChatLobbyRecord) {
      final lobbyId = to.lobbyId?.xstr64;
      if (lobbyId == null) {
        throw Exception('VisibleChatLobbyRecord has null ID');
      }
      if (_distanceChat.containsKey(lobbyId)) {
        chat = _distanceChat[lobbyId];
      } else {
        chat = Chat(
          chatId: lobbyId,
          chatName: to.lobbyName,
          isPublic: Chat.isPublicChat(to.lobbyFlags ?? 0),
          lobbyTopic: to.lobbyTopic,
          numberOfParticipants: to.totalNumberOfPeers,
          ownIdToUse: currentId,
          interlocutorId: '',
        );
        joinChatLobby(chat, currentId).catchError((e) {
          debugPrint('Failed to auto-join lobby $lobbyId: $e');
        });
        addDistanceChat(chat);
      }
    } else if (to is Chat) {
      chat = to;
      if (chat.isPublic ?? false) {
        joinChatLobby(chat, currentId).catchError((e) {
          debugPrint('Failed to auto-join lobby ${chat?.chatId}: $e');
        });
      }
    } else if (to != null) {
      throw Exception("Invalid type for 'to' parameter: ${to.runtimeType}");
    } else {
      throw Exception("Invalid 'to' parameter in getChat: cannot be null");
    }
    return chat;
  }

  Future<void> joinChatLobby(Chat lobby, String idToUse) async {
    final lobbyId = lobby.chatId;
    if (lobbyId == null) {
      throw Exception('Lobby ID is null, cannot join');
    }
    try {
      await RsMsgs.joinChatLobby(lobbyId, idToUse, _authToken);
    } catch (e) {
      debugPrint('Error joining lobby $lobbyId: $e');
      rethrow;
    }
  }

  Future<void> callrequestIdentity(Identity unknownId) async {
    final idToRequest = unknownId.mId;
    try {
      await RsIdentity.requestIdentity(idToRequest, _authToken);
    } catch (e) {
      debugPrint('Error requesting identity $idToRequest: $e');
    }
  }

  Future<void> getDistanceChatStatus(ChatMessage msg) async {
    final distantId = msg.chatId?.distantChatId;
    if (distantId == null) return;

    if (!_distanceChat.containsKey(distantId)) {
      try {
        final res =
            await RsMsgs.getDistantChatStatus(authToken, distantId, msg);
        final toId = res.toId;
        final ownId = res.ownId;
        if (toId == null || ownId == null) {
          throw Exception(
            'Missing required info from getDistantChatStatus response',
          );
        }
        final chat = Chat(
          interlocutorId: toId,
          ownIdToUse: ownId,
          chatId: distantId,
          isPublic: false,
          chatName: res.toId ?? 'Unknown Peer',
        );
        addDistanceChat(chat);
        addChatMessage(msg, distantId);
      } catch (e) {
        debugPrint('Error in getDistanceChatStatus: $e');
      }
    } else {
      addChatMessage(msg, distantId);
    }
  }

  Future<void> chatIdentityCheck(ChatMessage message) async {
    if (message.msg?.isNotEmpty == true && (message.incoming ?? false)) {
      final lobbyPeerId = message.lobbyPeerGxsId;
      final distantChatId = message.chatId?.distantChatId;
      final interlocutorId = distantChatId != null
          ? _distanceChat[distantChatId]?.interlocutorId
          : null;

      if (message.isLobbyMessage() && lobbyPeerId != null) {
        final identity = _allIdentity[lobbyPeerId];
        if (identity == null || identity.mId == identity.name) {
          await callrequestIdentity(
            Identity(
              mId: lobbyPeerId,
              signed: false,
              isContact: false,
            ),
          );
        }
      } else if (!message.isLobbyMessage() && interlocutorId != null) {
        final identity = _allIdentity[interlocutorId];
        if (identity == null || identity.mId == identity.name) {
          await callrequestIdentity(
            Identity(
              mId: interlocutorId,
              signed: false,
              isContact: false,
            ),
          );
        }
      }
    }
  }
}
