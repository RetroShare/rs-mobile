import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/ui/room/messages_tab.dart';
import 'package:retroshare/ui/room/room_friends_tab.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, this.isRoom = false, required this.chat});
  final bool isRoom;
  final Chat chat;

  @override
  RoomScreenState createState() => RoomScreenState();
}

class RoomScreenState extends State<RoomScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Animation<Color?> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: widget.isRoom ? 2 : 1);

    _iconAnimation =
        ColorTween(begin: Colors.black, end: Colors.lightBlueAccent)
            .animate(_tabController.animation!);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.chat.chatId == null) {
        debugPrint(
          'Chat ID is null, cannot update participants or current chat.',
        );
        return;
      }
      try {
        final roomProvider = Provider.of<RoomChatLobby>(context, listen: false);
        if (widget.isRoom) {
          await roomProvider.updateParticipants(widget.chat.chatId!);
        }
        if (roomProvider.currentChat!.chatId != widget.chat.chatId) {
          roomProvider.updateCurrentChat(widget.chat);
        }
      } catch (e) {
        debugPrint('Error during initState updates: $e');
      }
    });
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  MemoryImage? _safeDecodeBase64(String? base64String) {
    if (base64String == null || base64String.isEmpty) {
      return null;
    }
    try {
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomChatLobby>(context, listen: false);
    final interlocutorIdentity =
        roomProvider.allIdentity[widget.chat.interlocutorId];
    final avatarImage = _safeDecodeBase64(interlocutorIdentity?.avatar);
    final hasAvatar = avatarImage != null;

    final displayName = widget.isRoom
        ? widget.chat.chatName
        : interlocutorIdentity?.name ??
            widget.chat.chatName ??
            widget.chat.interlocutorId;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Container(
              height: appBarHeight,
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: personDelegateHeight,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 25,
                      ),
                      onPressed: () {
                        if (widget.isRoom && _tabController.index == 1) {
                          _tabController.animateTo(0);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                  if (!widget.isRoom)
                    SizedBox(
                      width: appBarHeight,
                      height: appBarHeight,
                      child: CircleAvatar(
                        radius: appBarHeight * 0.35,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: avatarImage,
                        child: !hasAvatar
                            ? Icon(
                                Icons.person,
                                size: appBarHeight * 0.4,
                                color: Colors.grey[600],
                              )
                            : null,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName ?? 'Chat',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isRoom)
                    AnimatedBuilder(
                      animation: _tabController.animation!,
                      builder: (BuildContext context, Widget? child) {
                        return IconButton(
                          icon: const Icon(
                            Icons.people,
                            size: 25,
                          ),
                          color: _iconAnimation.value ?? Colors.grey,
                          tooltip: 'View Participants',
                          onPressed: () {
                            _tabController.animateTo(1 - _tabController.index);
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  MessagesTab(
                    chat: widget.chat,
                    isRoom: widget.isRoom,
                  ),
                  if (widget.isRoom) RoomFriendsTab(chat: widget.chat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
