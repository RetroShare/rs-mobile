import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/identicon.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/ui/room/message_delegate.dart';
import 'package:retroshare/ui/room/messages_tab.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

/// A direct chat with one RetroShare friend location (SSL peer).
class DirectPeerChatScreen extends StatefulWidget {
  const DirectPeerChatScreen({super.key, required this.location});

  final Location location;

  @override
  State<DirectPeerChatScreen> createState() => _DirectPeerChatScreenState();
}

class _DirectPeerChatScreenState extends State<DirectPeerChatScreen> {
  late final Chat _chat;
  RoomChatLobby? _roomProvider;
  final GlobalKey<MessagesTabState> _messagesTabKey =
      GlobalKey<MessagesTabState>();

  Future<void> _clearChat() async {
    final chatId = _chat.chatId;
    if (chatId == null) return;

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
      await Provider.of<RoomChatLobby>(context, listen: false).clearChatHistory(
        chatId,
        ChatId(peerId: chatId, type: ChatIdType.type1),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat cleared')),
      );
    } catch (e) {
      debugPrint('Error clearing peer chat history: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not clear chat')),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _roomProvider ??=
        Provider.of<RoomChatLobby>(context, listen: false);
  }

  @override
  void initState() {
    super.initState();
    final peerName = widget.location.accountName.trim();
    final nickname = widget.location.locationName.trim();
    final name = peerName.isNotEmpty && nickname.isNotEmpty
        ? '$peerName ($nickname)'
        : peerName.isNotEmpty
            ? peerName
            : nickname;
    _chat = Chat(
      chatId: widget.location.rsPeerId,
      chatName: name,
      interlocutorId: widget.location.rsPeerId,
      ownIdToUse: '',
      isPublic: false,
      numberOfParticipants: 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roomChat = Provider.of<RoomChatLobby>(context, listen: false);
      roomChat
        ..addPeerChat(_chat)
        ..resetPeerUnreadCount(widget.location.rsPeerId)
        ..updateCurrentChat(_chat);
    });
  }

  @override
  void dispose() {
    _roomProvider?.clearCurrentChat(_chat.chatId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _chat.chatName ?? 'Direct chat';
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: appBarHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: personDelegateHeight,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, size: 25),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  SizedBox(
                    width: appBarHeight,
                    height: appBarHeight,
                    child: CircleAvatar(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Identicon(
                        id: widget.location.rsPeerId,
                        size: appBarHeight * 0.7,
                        borderRadius: appBarHeight * 0.35,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, overflow: TextOverflow.ellipsis),
                        Text(
                          'Direct peer chat',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      if (action == 'search') {
                        _messagesTabKey.currentState?.showMessageSearch();
                      } else if (action == 'clear') {
                        _clearChat();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'search',
                        child: ListTile(
                          leading: Icon(Icons.search),
                          title: Text('Search'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'clear',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Clear chat'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: MessagesTab(
                key: _messagesTabKey,
                chat: _chat,
                isPeerChat: true,
                bubbleStyle: BubbleStyle.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
