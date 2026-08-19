import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/identicon.dart';
import 'package:retroshare/common/person_delegate.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/friend_location.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';
import 'package:retroshare/ui/room/message_delegate.dart';
import 'package:retroshare/ui/room/messages_tab.dart';
import 'package:retroshare/ui/room/room_friends_tab.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _ChatMenuAction { search, clearChat, bubble, compact }

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
  late Animation<Color?> _iconAnimation;
  BubbleStyle _bubbleStyle = BubbleStyle.bubble;
  Timer? _statusRefreshTimer;
  RoomChatLobby? _roomProvider;
  final GlobalKey<MessagesTabState> _messagesTabKey =
      GlobalKey<MessagesTabState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _roomProvider ??=
        Provider.of<RoomChatLobby>(context, listen: false);
    _iconAnimation =
        ColorTween(begin: Theme.of(context).colorScheme.onSurface, end: Theme.of(context).colorScheme.primary)
            .animate(_tabController.animation!);
  }

  Future<void> _loadBubbleStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final styleIndex = prefs.getInt('chat_bubble_style');
      if (styleIndex != null && mounted) {
        setState(() {
          _bubbleStyle = BubbleStyle.values[styleIndex];
        });
      }
    } catch (e) {
      debugPrint('Error loading bubble style: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: widget.isRoom ? 2 : 1);
    _loadBubbleStyle();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.chat.chatId == null) {
        debugPrint(
          'Chat ID is null, cannot update participants or current chat.',
        );
        return;
      }
      try {
        final roomProvider = Provider.of<RoomChatLobby>(context, listen: false);
        final chatLobby = Provider.of<ChatLobby>(context, listen: false);

        if (widget.isRoom) {
          await roomProvider.updateParticipants(widget.chat.chatId!);
          if (widget.chat.chatId != null) {
            chatLobby.resetUnreadCount(widget.chat.chatId!);
          }
        } else if (widget.chat.chatId != null) {
          // Trigger immediate status check for 1:1 chat
          await roomProvider.refreshDistantChatStatus(
            widget.chat.chatId!,
            ChatId(distantChatId: widget.chat.chatId, type: ChatIdType.type2),
          );

          // Start periodic refresh while chat is open
          _statusRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
            if (mounted) {
              roomProvider.refreshDistantChatStatus(
                widget.chat.chatId!,
                ChatId(distantChatId: widget.chat.chatId, type: ChatIdType.type2),
              );
            }
          });
        }
        if (roomProvider.currentChat?.chatId != widget.chat.chatId) {
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
    _statusRefreshTimer?.cancel();
    _tabController.dispose();
    // Clear current chat so new messages are counted as unread
    _roomProvider?.clearCurrentChat(widget.chat.chatId);
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

  Color _getStatusColor(int status) {
    switch (status) {
      case 3: // RS_STATUS_ONLINE
        return Colors.lightGreenAccent;
      case 1: // RS_STATUS_AWAY
        return Colors.orange;
      case 2: // RS_STATUS_BUSY
        return Colors.red;
      case 4: // RS_STATUS_INACTIVE
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  ChatId? _apiChatId() {
    final chatId = widget.chat.chatId;
    if (chatId == null) return null;
    return ChatId(
      distantChatId: widget.isRoom ? null : chatId,
      lobbyId: widget.isRoom
          ? ChatLobbyId(xstr64: chatId)
          : null,
      type: widget.isRoom ? ChatIdType.type3 : ChatIdType.type2,
    );
  }

  Future<void> _clearChat() async {
    final chatId = widget.chat.chatId;
    final apiChatId = _apiChatId();
    if (chatId == null || apiChatId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
          'This permanently removes the message history for this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await Provider.of<RoomChatLobby>(context, listen: false)
          .clearChatHistory(chatId, apiChatId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat cleared')),
      );
    } catch (e) {
      debugPrint('Error clearing chat history: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not clear chat')),
      );
    }
  }

  Future<void> _handleMenuAction(_ChatMenuAction action) async {
    switch (action) {
      case _ChatMenuAction.search:
        _tabController.animateTo(0);
        _messagesTabKey.currentState?.showMessageSearch();
        return;
      case _ChatMenuAction.clearChat:
        await _clearChat();
        return;
      case _ChatMenuAction.bubble:
      case _ChatMenuAction.compact:
        final style = action == _ChatMenuAction.bubble
            ? BubbleStyle.bubble
            : BubbleStyle.compact;
        setState(() => _bubbleStyle = style);
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('chat_bubble_style', style.index);
        } catch (e) {
          debugPrint('Error saving bubble style: $e');
        }
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomChatLobby>(context, listen: false);
    final interlocutorIdentity =
        roomProvider.allIdentity[widget.chat.interlocutorId];
    final avatarImage = _safeDecodeBase64(interlocutorIdentity?.avatar);
    final hasAvatar = avatarImage != null;

    final friendLocations = Provider.of<FriendLocations>(context);
    final friendLocs = friendLocations.friendlist;
    final matchingLocs = interlocutorIdentity != null
        ? PersonDelegateData.getMatchingLocations(interlocutorIdentity, friendLocs)
        : const Iterable<Location>.empty();

    final isAnyLocationOnline = matchingLocs.any((loc) => loc.isOnline);

    var effectiveStatus = interlocutorIdentity?.status ?? 0;
    if (effectiveStatus == 0 && isAnyLocationOnline) {
      effectiveStatus = 3; // Default to Online
      for (final loc in matchingLocs) {
        if (loc.isOnline && loc.status != 0 && loc.status != 3) {
          effectiveStatus = loc.status;
          break;
        }
      }
    }

    final showStatus = !widget.isRoom &&
        interlocutorIdentity != null &&
        (isAnyLocationOnline || effectiveStatus != 0);

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
                    GestureDetector(
                      onTap: interlocutorIdentity == null
                          ? null
                          : () {
                              Navigator.pushNamed(
                                context,
                                '/profile',
                                arguments: {'id': interlocutorIdentity},
                              );
                            },
                      child: Stack(
                        children: [
                          SizedBox(
                            width: appBarHeight,
                            height: appBarHeight,
                            child: CircleAvatar(
                              radius: appBarHeight * 0.35,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              backgroundImage: avatarImage,
                              child: !hasAvatar
                                  ? Identicon(
                                      id: widget.chat.interlocutorId,
                                      size: appBarHeight * 0.7,
                                      borderRadius: appBarHeight * 0.35,
                                    )
                                  : null,
                            ),
                          ),
                          if (showStatus)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                height: 14,
                                width: 14,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.surface,
                                    width: 2,
                                  ),
                                  color: effectiveStatus != 0
                                      ? _getStatusColor(effectiveStatus)
                                      : Colors.lightGreenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: widget.isRoom || interlocutorIdentity == null
                          ? null
                          : () {
                              Navigator.pushNamed(
                                context,
                                '/profile',
                                arguments: {'id': interlocutorIdentity},
                              );
                            },
                      child: Text(
                        displayName ?? 'Chat',
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                  PopupMenuButton<_ChatMenuAction>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: _handleMenuAction,
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<_ChatMenuAction>>[
                        const PopupMenuItem<_ChatMenuAction>(
                          value: _ChatMenuAction.search,
                          child: ListTile(
                            leading: Icon(Icons.search),
                            title: Text('Search'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuItem<_ChatMenuAction>(
                          value: _ChatMenuAction.clearChat,
                          child: ListTile(
                            leading: Icon(Icons.delete_outline),
                            title: Text('Clear chat'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (!widget.isRoom) const PopupMenuDivider(),
                        if (!widget.isRoom)
                          const PopupMenuItem<_ChatMenuAction>(
                            value: _ChatMenuAction.bubble,
                            child: Text('Bubble'),
                          ),
                        if (!widget.isRoom)
                          const PopupMenuItem<_ChatMenuAction>(
                            value: _ChatMenuAction.compact,
                            child: Text('Bubble Compact'),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  MessagesTab(
                    key: _messagesTabKey,
                    chat: widget.chat,
                    isRoom: widget.isRoom,
                    bubbleStyle: _bubbleStyle,
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
