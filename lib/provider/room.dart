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
  // Track last known status for distant chats to avoid duplicate system messages
  final Map<String, int> _lastDistantChatStatus = {};
  // Track chats that the user explicitly removed
  final Set<String> _hiddenDistantChats = {};

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
      
      // Deduplicate by mId to be safe
      final Map<String, Identity> uniqueFriends = {};
      for (final id in _friendsIdsList) {
        uniqueFriends[id.mId] = id;
      }
      _friendsIdsList = uniqueFriends.values.toList();

      _allIdentity = {
        for (final id in [_friendsSignedIdsList, _friendsIdsList, _notContactIds]
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

  Future<void> removeDistantChat(String chatId) async {
    // Try to close the connection in the core
    try {
      await RsMsgs.closeDistantChatConnexion(chatId, _authToken);
    } catch (e) {
      debugPrint('Core closeDistantChatConnexion failed: $e');
    }

    // Remove from local state and track as hidden
    bool removed = false;
    
    // Find the chat object to get all its identifiers
    Chat? chat = _distanceChat[chatId];
    if (chat == null) {
      for (final entry in _distanceChat.values) {
        if (entry.chatId == chatId) {
          chat = entry;
          break;
        }
      }
    }

    if (chat != null) {
      if (chat.chatId != null) {
        _hiddenDistantChats.add(chat.chatId!);
        _distanceChat.remove(chat.chatId);
        _messagesList.remove(chat.chatId);
      }
      
      if (!chat.isPublic) {
        final compositeId = _generateDistantChatId(chat.interlocutorId, chat.ownIdToUse);
        _hiddenDistantChats.add(compositeId);
        _distanceChat.remove(compositeId);
      }
      
      _hiddenDistantChats.add(chatId);
      _distanceChat.remove(chatId);
      removed = true;
    }

    if (removed) {
      notifyListeners();
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
            if (!success) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
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
      if (chat?.chatId != null) {
        resetUnreadCount(chat!.chatId!);
      }
      notifyListeners();
    }
  }

  void incrementUnreadCount(String chatId) {
    Chat? targetChat = _distanceChat[chatId];
    
    if (targetChat == null) {
      // search by tunnel ID in values
      for (final chat in _distanceChat.values) {
        if (chat.chatId == chatId) {
          targetChat = chat;
          break;
        }
      }
    }

    if (targetChat != null) {
      targetChat.unreadCount++;
      notifyListeners();
    }
  }

  void resetUnreadCount(String chatId) {
    Chat? targetChat = _distanceChat[chatId];
    
    if (targetChat == null) {
      for (final chat in _distanceChat.values) {
        if (chat.chatId == chatId) {
          targetChat = chat;
          break;
        }
      }
    }

    if (targetChat != null) {
      targetChat.unreadCount = 0;
      notifyListeners();
    }
  }

  void addDistanceChat(Chat distantChat) {
    final chatId = distantChat.chatId;
    if (chatId == null) return;

    // Skip if hidden (background heartbeat/status)
    if (_hiddenDistantChats.contains(chatId)) return;

    _distanceChat = Map.from(_distanceChat)..[chatId] = distantChat;

    // Also index by composite ID for distant chats to allow lookup by identities
    if (!distantChat.isPublic) {
      final compositeId =
          _generateDistantChatId(distantChat.interlocutorId, distantChat.ownIdToUse);
      if (_hiddenDistantChats.contains(compositeId)) return;
      _distanceChat[compositeId] = distantChat;
    }

    _messagesList = Map.from(_messagesList)..putIfAbsent(chatId, () => []);
    notifyListeners();
  }

  void addChatMessage(ChatMessage message, String chatId) {
    // Unhide if a new message arrives
    if (_hiddenDistantChats.contains(chatId)) {
      _hiddenDistantChats.remove(chatId);
    }

    final currentList = _messagesList[chatId] ?? [];
    _messagesList = Map.from(_messagesList)
      ..[chatId] = [...currentList, message];
    notifyListeners();
  }

  int getUnreadCount(Identity iden, Identity idToUse) {
    final idenId = iden.mId;
    final idToUseId = idToUse.mId;

    final compositeKey = _generateDistantChatId(idenId, idToUseId);
    if (_distanceChat.containsKey(compositeKey)) {
      return _distanceChat[compositeKey]!.unreadCount;
    }

    // Fallback: search all distant chats for a match by interlocutorId
    for (final chat in _distanceChat.values) {
      if (!chat.isPublic && chat.interlocutorId == idenId) {
        return chat.unreadCount;
      }
    }

    return 0;
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

  Future<Chat?> getChat(
    Identity currentIdentity,
    dynamic to,
  ) async {
    Chat? chat;
    final currentId = currentIdentity.mId;

    if (to is Identity) {
      final toId = to.mId;

      final distantChatId = _generateDistantChatId(toId, currentId);
      // Explicitly unhide if user starts the chat manually
      _hiddenDistantChats.remove(distantChatId);

      if (_distanceChat.containsKey(distantChatId)) {
        chat = _distanceChat[distantChatId];
        if (chat?.chatId != null) {
          _hiddenDistantChats.remove(chat!.chatId);
          refreshDistantChatStatus(chat.chatId!, ChatId(distantChatId: chat.chatId, type: ChatIdType.type2));
        }
      } else {
        final initialChat = Chat(
          interlocutorId: toId,
          isPublic: false,
          chatName: to.name,
          numberOfParticipants: 1,
          ownIdToUse: currentId,
        );
        try {
          final newChatId = await initiateDistantChat(initialChat);
          if (newChatId != null) {
            chat = initialChat.copyWith(chatId: newChatId);
            addDistanceChat(chat);
          } else {
            chat = initialChat;
          }
        } catch (e) {
          debugPrint('Failed to auto-initiate chat: $e');
          chat = initialChat;
        }
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
        try {
          await joinChatLobby(chat, currentId);
        } catch (e) {
          debugPrint('Failed to auto-join lobby $lobbyId: $e');
        }
        addDistanceChat(chat);
      }
    } else if (to is Chat) {
      chat = to;
      if (chat.isPublic) {
        try {
          await joinChatLobby(chat, currentId);
        } catch (e) {
          debugPrint('Failed to auto-join lobby ${chat.chatId}: $e');
        }
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

  Future<void> refreshDistantChatStatus(String distantId, ChatId? chatIdInfo) async {
    try {
      final res = await RsMsgs.getDistantChatStatus(authToken, distantId, const ChatMessage());
      final status = res.status ?? 0;
      debugPrint('DEBUG: Tunnel status for $distantId is $status');

      if (_lastDistantChatStatus[distantId] != status) {
        String? systemMsg;
        if (status == 2) {
          systemMsg = 'Tunnel is secure you can talk!';
        } else if (status == 3) {
          systemMsg = 'Your partner closed the conversation.';
        }

        if (systemMsg != null) {
          // Check if we already have this specific system message in the last few messages
          final existingMessages = _messagesList[distantId] ?? [];
          bool alreadyExists = existingMessages.reversed.take(5).any((m) => m.msg == systemMsg);
          
          if (!alreadyExists) {
            final sysMessage = ChatMessage(
              chatId: chatIdInfo,
              msg: systemMsg,
              incoming: true,
              chatflags: 0x0008, // System message flag
              sendTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              recvTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            );
            addChatMessage(sysMessage, distantId);
          }
        }
        _lastDistantChatStatus[distantId] = status;
      }
    } catch (e) {
      debugPrint('Error in refreshDistantChatStatus: $e');
    }
  }

  Future<void> getDistanceChatStatus(ChatMessage msg) async {
    final distantId = msg.chatId?.distantChatId;
    if (distantId == null) return;

    try {
      DistantChatPeerInfo? res;
      try {
        res = await RsMsgs.getDistantChatStatus(authToken, distantId, msg);
      } catch (e) {
        debugPrint('Warning: getDistantChatStatus API failed for $distantId: $e');
      }

      final toId = res?.toId;
      final ownId = res?.ownId;
      final status = res?.status ?? 0;

      if (!_distanceChat.containsKey(distantId)) {
        // If we don't have details yet, create a temporary placeholder chat
        final chat = Chat(
          interlocutorId: toId ?? distantId,
          ownIdToUse: ownId ?? '',
          chatId: distantId,
          isPublic: false,
          chatName: toId ?? 'Unknown Peer',
        );
        addDistanceChat(chat);
      }

      // Handle system messages based on status
      if (res != null && _lastDistantChatStatus[distantId] != status) {
        String? systemMsg;
        if (status == 2) {
          systemMsg = 'Tunnel is secure you can talk!';
        } else if (status == 3) {
          systemMsg = 'Your partner closed the conversation.';
        }

        if (systemMsg != null) {
          // Check if we already have this specific system message in the last few messages
          final existingMessages = _messagesList[distantId] ?? [];
          bool alreadyExists = existingMessages.reversed.take(5).any((m) => m.msg == systemMsg);
          
          if (!alreadyExists) {
            final sysMessage = ChatMessage(
              chatId: msg.chatId,
              msg: systemMsg,
              incoming: true,
              chatflags: 0x0008, // System message flag
              sendTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              recvTime: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            );
            addChatMessage(sysMessage, distantId);
          }
        }
        _lastDistantChatStatus[distantId] = status;
      }

      addChatMessage(msg, distantId);
    } catch (e) {
      debugPrint('Error in getDistanceChatStatus: $e');
      // Absolute fallback: ensure message is added if we have a distantId
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
