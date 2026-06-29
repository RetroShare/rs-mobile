import 'package:flutter/foundation.dart';
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
      final int roomUnread = chatLobby.subscribedlist.fold(0, (sum, chat) => sum + chat.unreadCount);
      
      // Aggregate distant chat unreads, ensuring we only count each unique chat once
      final Set<String> processedDistantIds = {};
      int distantUnread = 0;
      for (final chat in roomChatLobby.distanceChat.values) {
        if (!chat.isPublic && chat.chatId != null && !processedDistantIds.contains(chat.chatId)) {
          distantUnread += chat.unreadCount;
          processedDistantIds.add(chat.chatId!);
        }
      }
      
      final int totalUnread = roomUnread + distantUnread;

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
