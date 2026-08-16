import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/badge_helper.dart';
import 'package:retroshare/common/notifications.dart';
import 'package:retroshare/model/app_life_cycle_state.dart';
import 'package:retroshare/provider/friend_location.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

// register chat event
Future<void> registerChatEvent(
  BuildContext context,
  AuthToken authToken,
) async {
  await eventsRegisterChatMessage(
    listenCb: (var json, ChatMessage? msg) {
      if (msg == null) return;
      final roomChatLobby = Provider.of<RoomChatLobby>(context, listen: false);
      final chatLobby = Provider.of<ChatLobby>(context, listen: false);
      debugPrint(
        '[ChatUnread] event type=${msg.chatId?.type} '
        'lobby=${msg.chatId?.lobbyId?.xstr64} '
        'distant=${msg.chatId?.distantChatId} '
        'peer=${msg.chatId?.peerId} '
        'broadcastPeer=${msg.chatId?.broadcastStatusPeerId} '
        'incoming=${msg.incoming} current=${roomChatLobby.currentChat?.chatId}',
      );

      // Check if is a lobby chat
      if (msg.isLobbyMessage()) {
        final lobbyId = msg.chatId?.lobbyId?.xstr64 ?? '';
        debugPrint('[ChatUnread] classified=room id=$lobbyId');
        
        roomChatLobby.chatIdentityCheck(msg);
        showChatNotify(msg, context);
        roomChatLobby.addChatMessage(msg, lobbyId);

        // Increment unread count if not current chat
        if (roomChatLobby.currentChat?.chatId != lobbyId) {
          chatLobby.incrementUnreadCount(lobbyId);
          debugPrint('[ChatUnread] room incremented id=$lobbyId');
          BadgeHelper.updateAppBadge(context);
        }
      }
      // Direct peer events can also contain zero-filled distant-chat fields,
      // so identify them before checking distantChatId.
      else if ((msg.chatId?.distantChatId == null ||
              msg.chatId!.distantChatId!.isEmpty ||
              RegExp(r'^0+$').hasMatch(msg.chatId!.distantChatId!)) &&
          (msg.chatId?.type == ChatIdType.type1 ||
              (msg.chatId?.type == null &&
                  msg.chatId?.peerId?.isNotEmpty == true &&
                  !RegExp(r'^0+$').hasMatch(msg.chatId!.peerId!)) ||
              (msg.chatId?.type == null &&
                  msg.chatId?.broadcastStatusPeerId?.isNotEmpty == true &&
                  !RegExp(r'^0+$')
                      .hasMatch(msg.chatId!.broadcastStatusPeerId!)))) {
        final rawPeerId = msg.chatId?.peerId;
        final peerId = rawPeerId != null &&
                rawPeerId.isNotEmpty &&
                !RegExp(r'^0+$').hasMatch(rawPeerId)
            ? rawPeerId
            : msg.chatId?.broadcastStatusPeerId;
        if (peerId == null ||
            peerId.isEmpty ||
            RegExp(r'^0+$').hasMatch(peerId)) {
          return;
        }
        debugPrint('[ChatUnread] classified=peer id=$peerId');
        roomChatLobby.discardMisclassifiedDistantChat(
          msg.chatId?.distantChatId,
        );
        final locations =
            Provider.of<FriendLocations>(context, listen: false).friendlist;
        final location = locations.firstWhereOrNull(
          (item) => item.rsPeerId.toLowerCase() == peerId.toLowerCase(),
        );
        roomChatLobby.addPeerChat(
          Chat(
            chatId: peerId,
            chatName: location == null
                ? 'Direct chat'
                : location.accountName.trim().isNotEmpty &&
                        location.locationName.trim().isNotEmpty
                    ? '${location.accountName.trim()} (${location.locationName.trim()})'
                    : location.accountName.trim().isNotEmpty
                        ? location.accountName.trim()
                        : location.locationName.trim(),
            interlocutorId: peerId,
            ownIdToUse: '',
            isPublic: false,
            numberOfParticipants: 1,
          ),
        );
        showChatNotify(msg, context);
        roomChatLobby.addChatMessage(msg, peerId);
        if (roomChatLobby.currentChat?.chatId != peerId) {
          roomChatLobby.incrementPeerUnreadCount(peerId);
          debugPrint(
            '[ChatUnread] peer incremented id=$peerId '
            'count=${roomChatLobby.peerChats[peerId]?.unreadCount}',
          );
          BadgeHelper.updateAppBadge(context);
        } else {
          debugPrint('[ChatUnread] peer not incremented: chat is currently open');
        }
      }
      // Check if is distant chat message
      else if (msg.chatId?.distantChatId?.isNotEmpty == true &&
          !RegExp(r'^0+$').hasMatch(msg.chatId!.distantChatId!)) {
        final distantId = msg.chatId!.distantChatId!;
        debugPrint('[ChatUnread] classified=distant id=$distantId');

        // First check if the recieved message
        //is from an already registered chat
        roomChatLobby.chatIdentityCheck(msg);
        showChatNotify(msg, context);
        
        // Handle distant chat metadata and message addition
        roomChatLobby.getDistanceChatStatus(msg).then((_) {
          // Increment unread count if not current chat
          if (roomChatLobby.currentChat?.chatId != distantId) {
            roomChatLobby.incrementUnreadCount(distantId);
            debugPrint(
              '[ChatUnread] distant incremented id=$distantId '
              'total=${roomChatLobby.distantUnreadCount}',
            );
            BadgeHelper.updateAppBadge(context);
          } else {
            debugPrint(
              '[ChatUnread] distant not incremented: chat is currently open',
            );
          }
        }).catchError((e) {
          debugPrint('Error processing distant chat message: $e');
        });
      } else {
        debugPrint('[ChatUnread] classified=unknown; event was not counted');
      }
    },
    authToken: authToken,
  );
}

// Show the incoming chat  message  notification when app is in background/ resume state
Future<void> showChatNotify(ChatMessage message, BuildContext context) async {
  if (message.msg?.isNotEmpty == true && (message.incoming ?? false)) {
    final roomChatLobby = Provider.of<RoomChatLobby>(context, listen: false);
    final subscribedChats =
        Provider.of<ChatLobby>(context, listen: false).subscribedlist;

    // Parse the notification message from the HTML tag.
    String parsedMsg;
    final parsed = parse(message.msg).getElementsByTagName('span');
    parsedMsg = (parsed.isNotEmpty) ? parsed.first.text : message.msg ?? '';

    var isCurrentChat = false;
    final currentChatId =
        roomChatLobby.currentChat?.chatId; // Declare as String?
    if (currentChatId != null) {
      // Only compare if we have a current chat ID
      if (message.isLobbyMessage()) {
        isCurrentChat = currentChatId == message.chatId?.lobbyId?.xstr64;
      } else if (message.chatId?.distantChatId?.isNotEmpty == true &&
          !RegExp(r'^0+$').hasMatch(message.chatId!.distantChatId!)) {
        isCurrentChat = currentChatId == message.chatId?.distantChatId;
      } else {
        final rawPeerId = message.chatId?.peerId;
        final peerId = rawPeerId != null &&
                rawPeerId.isNotEmpty &&
                !RegExp(r'^0+$').hasMatch(rawPeerId)
            ? rawPeerId
            : message.chatId?.broadcastStatusPeerId;
        isCurrentChat = currentChatId == peerId;
      }
    }

    // Check if current chat is NOT focused, to notify unread count
    if (!isCurrentChat) {
      if (message.isLobbyMessage()) {
        // Find chat in subscribed list safely using firstWhereOrNull
        final lobbyId = message.chatId?.lobbyId?.xstr64;
        if (lobbyId != null) {}
      } else {
        // Find chat in distanceChat map safely
        final distantId = message.chatId?.distantChatId;
        if (distantId != null) {}
      }
      // chat?.unreadCount++; // Commented out due to missing setter error
    }

    // Show notification
    if (actualApplState != AppLifecycleState.resumed) {
      await showChatNotification(
        // Id of notification - convert to string
        message.chatId?.peerId?.toString() ?? '0',

        // Title of notification
        message.isLobbyMessage()
            // Use firstWhereOrNull here too
            ? subscribedChats
                    .firstWhereOrNull(
                      (c) => c.chatId == message.chatId?.lobbyId?.xstr64,
                    )
                    ?.chatName ??
                'Unknown Chat' // Null check after firstWhereOrNull
            : roomChatLobby.getChatSenderName(message),
        // Message notification
        message.isLobbyMessage()
            ? '${roomChatLobby.getChatSenderName(message)}: $parsedMsg'
            : parsedMsg,
      );
    }
  }
}
