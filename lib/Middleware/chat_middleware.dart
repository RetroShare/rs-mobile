import 'package:flutter/cupertino.dart';
import 'package:html/parser.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/notifications.dart';
import 'package:retroshare/model/app_life_cycle_state.dart';
import 'package:retroshare/model/chat.dart';
import 'package:retroshare/model/identity.dart';
import 'package:retroshare/provider/FriendsIdentity.dart';
import 'package:retroshare/provider/Idenity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';

void chatMiddleware(ChatMessage message, BuildContext context) {
  if (message != null && message.msg.isNotEmpty && message.incoming) {
    // Check if the sender exists, if not request the identity
    // Also a dummy identity could be added when distant chat connection is started (id where name and mId are the same)
    // To dispatch the action, check if is dummy identity.

    final distantChats =
        Provider.of<RoomChatLobby>(context, listen: false).distanceChat;
    final allIds = Provider.of<FriendsIdentity>(context, listen: false).allIds;
    final currentChat =
        Provider.of<RoomChatLobby>(context, listen: false).currentChat;
    final subscribedChats =
        Provider.of<ChatLobby>(context, listen: false).subscribedlist;
    if (message.isLobbyMessage() &&
        (allIds[message.lobby_peer_gxs_id] == null ||
            allIds[message.lobby_peer_gxs_id].mId ==
                allIds[message.lobby_peer_gxs_id].name)) {
      Provider.of<Identities>(context, listen: false)
          .callrequestIdentity(new Identity(message.lobby_peer_gxs_id));
    } else if (!message.isLobbyMessage() &&
        (allIds[distantChats[message.chat_id.distantChatId].interlocutorId] ==
                null ||
            allIds[distantChats[message.chat_id.distantChatId].interlocutorId]
                    .mId ==
                allIds[distantChats[message.chat_id.distantChatId]
                        .interlocutorId]
                    .name)) {
      Provider.of<Identities>(context, listen: false).callrequestIdentity(
          new Identity(
              distantChats[message.chat_id.distantChatId].interlocutorId));
    }

    String parsedMsg;
    var parsed = parse(message.msg).getElementsByTagName("span");
    parsed.length > 0 ? parsedMsg = parsed[0].text : parsedMsg = message.msg;

    // Check if current chat is focused, to notify unread count
    if (currentChat == null ||
        (currentChat != null &&
            ((message.isLobbyMessage() &&
                    currentChat.chatId != message.chat_id.lobbyId.xstr64) ||
                (message.isLobbyMessage() &&
                    currentChat.chatId != message.chat_id.distantChatId)))) {
      Chat chat = message.isLobbyMessage()
          ? subscribedChats.firstWhere(
              (chat) => chat.chatId == message.chat_id.lobbyId.xstr64,
            )
          : distantChats[message.chat_id.distantChatId];
      chat.unreadCount++;
    }

    // Show notification
    if (actuaApplState != AppLifecycleState.resumed)
      showChatNotification(
          // Id of notification
          message.chat_id.peerId,
          // Title of notification
          message.isLobbyMessage()
              ? subscribedChats
                  .firstWhere(
                    (chat) => chat.chatId == message.chat_id.lobbyId.xstr64,
                  )
                  .chatName
              : message.getChatSenderName(
                  context,
                ),
          // Message notification
          message.isLobbyMessage()
              ? message.getChatSenderName(
                    context,
                  ) +
                  ": " +
                  parsedMsg
              : parsedMsg);
  }
}

void chatActionMiddleware(Chat distantChat, BuildContext context) {
  final allIds = Provider.of<FriendsIdentity>(context, listen: false).allIds;
  if (allIds[distantChat.interlocutorId] == null) {
    Provider.of<Identities>(context, listen: false)
        .callrequestIdentity(new Identity(distantChat.interlocutorId));
  }
}