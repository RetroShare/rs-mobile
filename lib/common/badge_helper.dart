import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';

class BadgeHelper {
  static Future<void> updateAppBadge(BuildContext context) async {
    try {
      final chatLobby = Provider.of<ChatLobby>(context, listen: false);
      final roomChatLobby = Provider.of<RoomChatLobby>(context, listen: false);

      // Aggregate room unreads
      final roomUnread = chatLobby.subscribedlist.fold(0, (sum, chat) => sum + chat.unreadCount);
      
      final totalUnread = roomUnread +
          roomChatLobby.distantUnreadCount +
          roomChatLobby.peerUnreadCount +
          chatLobby.pendingInviteCount;
      debugPrint(
        '[ChatUnread] badge rooms=$roomUnread '
        'distant=${roomChatLobby.distantUnreadCount} '
        'peer=${roomChatLobby.peerUnreadCount} '
        'invites=${chatLobby.pendingInviteCount} total=$totalUnread',
      );

      if (await FlutterAppBadger.isAppBadgeSupported()) {
        if (totalUnread > 0) {
          FlutterAppBadger.updateBadgeCount(totalUnread);
        } else {
          FlutterAppBadger.removeBadge();
        }
      }
    } catch (e) {
      debugPrint('Error updating app badge: $e');
    }
  }
}
