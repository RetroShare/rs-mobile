import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/identicon.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

enum _PublicChatSort { name, participants }

class DiscoverChatsScreen extends StatefulWidget {
  const DiscoverChatsScreen({super.key});

  @override
  DiscoverChatsScreenState createState() => DiscoverChatsScreenState();
}

class DiscoverChatsScreenState extends State<DiscoverChatsScreen> {
  String _searchQuery = '';
  _PublicChatSort _sort = _PublicChatSort.name;
  late final Future<void> _loadChats;

  List<VisibleChatLobbyRecord> _visibleChats(ChatLobby chats) {
    final query = _searchQuery.trim().toLowerCase();
    final result = chats.unSubscribedlist
        .where(
          (chat) => (chat.lobbyName ?? '').toLowerCase().contains(query),
        )
        .toList();

    result.sort((a, b) {
      if (_sort == _PublicChatSort.participants) {
        final participantOrder = (b.totalNumberOfPeers ?? 0).compareTo(
          a.totalNumberOfPeers ?? 0,
        );
        if (participantOrder != 0) return participantOrder;
      }
      return (a.lobbyName ?? '').toLowerCase().compareTo(
            (b.lobbyName ?? '').toLowerCase(),
          );
    });
    return result;
  }

  @override
  void initState() {
    super.initState();
    _loadChats = Future.microtask(
      () => Provider.of<ChatLobby>(context, listen: false)
          .fetchAndUpdateUnsubscribed(),
    );
  }

  Future<void> _goToChat(lobby) async {
    final curr =
        Provider.of<Identities>(context, listen: false).currentIdentity;
    if (curr == null) return;
    final chatData = await Provider.of<RoomChatLobby>(context, listen: false)
        .getChat(curr, lobby);
    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      '/room',
      arguments: {
        'isRoom': true,
        'chatData': chatData,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            SizedBox(
              height: appBarHeight,
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
                        Navigator.pop(context, true);
                      },
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Discover public chats',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                      decoration: const InputDecoration(
                        hintText: 'Search public chats',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_PublicChatSort>(
                    tooltip: 'Sort public chats',
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    icon: const Icon(Icons.sort),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _PublicChatSort.name,
                        child: Text('Sort by name'),
                      ),
                      PopupMenuItem(
                        value: _PublicChatSort.participants,
                        child: Text('Sort by participants'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder(
                future: _loadChats,
                builder: (context, snapshot) {
                  return snapshot.connectionState == ConnectionState.done &&
                          !snapshot.hasError
                      ? Consumer<ChatLobby>(
                          builder: (context, _chatsList, _) {
                            final chats = _visibleChats(_chatsList);
                            return chats.isNotEmpty
                                ? ListView.builder(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: chats.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final chat = chats[index];
                                      return Card(
                                        key: ValueKey(chat.lobbyId?.xstr64),
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          onTap: () => _goToChat(chat),
                                          child: Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Identicon(
                                                  id: chat.lobbyId?.xstr64 ??
                                                      chat.lobbyName ??
                                                      '',
                                                  size: 46,
                                                  borderRadius: 12,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: <Widget>[
                                                      Text(
                                                        chat.lobbyName ?? '',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge,
                                                      ),
                                                      Visibility(
                                                        visible:
                                                            chat.lobbyTopic !=
                                                                    null &&
                                                                chat.lobbyTopic!
                                                                    .isNotEmpty,
                                                        child: Text(
                                                          'Topic: ${chat.lobbyTopic}',
                                                          maxLines: 3,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(
                                                            context,
                                                          )
                                                              .textTheme
                                                              .bodyMedium,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${chat.totalNumberOfPeers ?? 0} participants',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.input),
                                                  tooltip: 'Join chat',
                                                  onPressed: () {
                                                    _goToChat(chat);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : Center(
                                    child: SizedBox(
                                      width: 250,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          Image.asset(
                                            'assets/icons8/pluto-fatal-error.png',
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 25,
                                            ),
                                            child: Text(
                                              _searchQuery.trim().isEmpty
                                                  ? 'No public chats are available'
                                                  : 'No public chats match your search',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                          },
                        )
                      : const Center(
                          child: CircularProgressIndicator(),
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
