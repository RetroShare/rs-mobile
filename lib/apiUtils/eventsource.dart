import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/notifications.dart';
import 'package:retroshare/model/app_life_cycle_state.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

// register chat event
Future<void> registerChatEvent(
  BuildContext context,
  AuthToken authToken,
) async {
  await await eventsRegisterChatMessage(
    listenCb: (var json, ChatMessage msg) {
      // Check if is a lobby chat
      if (msg.isLobbyMessage()) {
        Provider.of<RoomChatLobby>(context, listen: false)
            .chatIdentityCheck(msg);
        showChatNotify(msg, context);
        Provider.of<RoomChatLobby>(context, listen: false)
            .addChatMessage(msg, msg.chatId?.lobbyId?.xstr64 ?? '');
      }
      // Check if is distant chat message
      else if (msg.chatId?.distantChatId != null) {
        // First check if the recieved message
        //is from an already registered chat
        Provider.of<RoomChatLobby>(context, listen: false)
            .chatIdentityCheck(msg);
        Provider.of<RoomChatLobby>(context, listen: false)
            .getDistanceChatStatus(msg);
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
      } else if (message.chatId?.distantChatId != null) {
        isCurrentChat = currentChatId == message.chatId?.distantChatId;
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
