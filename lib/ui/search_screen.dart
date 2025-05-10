import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/person_delegate.dart';
import 'package:retroshare/common/sliver_persistent_header.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.initialTab});
  final int initialTab;

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchBoxFilter = TextEditingController();
  late Animation<Color?> _leftTabIconColor;
  late Animation<Color?> _rightTabIconColor;
  bool _init = true;
  String _searchContent = '';
  List<Identity> allIds = [];
  List<Identity> filteredAllIds = [];
  List<Identity> contactsIds = [];
  List<Identity> filteredContactsIds = [];
  List<Chat> subscribedChats = [];
  List<Chat> filteredSubscribedChats = [];
  List<VisibleChatLobbyRecord> publicChats = [];
  List<VisibleChatLobbyRecord> filteredPublicChats = [];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(vsync: this, length: 2, initialIndex: widget.initialTab);
    _init = true;
    _searchBoxFilter.addListener(() {
      if (_searchBoxFilter.text.isEmpty) {
        if (mounted) {
          setState(() {
            _searchContent = '';
            filteredAllIds = allIds;
            filteredContactsIds = contactsIds;
            filteredSubscribedChats = subscribedChats;
            filteredPublicChats = publicChats;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _searchContent = _searchBoxFilter.text;
          });
        }
      }
    });

    _leftTabIconColor =
        ColorTween(begin: const Color(0xFFF5F5F5), end: Colors.white)
            .animate(_tabController.animation!);
    _rightTabIconColor =
        ColorTween(begin: Colors.white, end: const Color(0xFFF5F5F5))
            .animate(_tabController.animation!);
  }

  @override
  void didChangeDependencies() {
    if (_init) {
      final friendIdentity = Provider.of<RoomChatLobby>(context, listen: false);
      final chatLobby = Provider.of<ChatLobby>(context, listen: false);
      friendIdentity.fetchAndUpdate();
      chatLobby
        ..fetchAndUpdate()
        ..fetchAndUpdateUnsubscribed();
      allIds = friendIdentity.notContactIds;
      contactsIds = friendIdentity.friendsIdsList;
      subscribedChats = chatLobby.subscribedlist;
      publicChats = chatLobby.unSubscribedlist;
    }
    _init = false;
    super.didChangeDependencies();
  }

  Future<void> _goToChat(Chat lobby) async {
    final curr =
        Provider.of<Identities>(context, listen: false).currentIdentity;
    if (curr == null) {
      return;
    }
    await Navigator.pushNamed(
      context,
      '/room',
      arguments: {
        'isRoom': true,
        'chatData': Provider.of<RoomChatLobby>(context, listen: false)
            .getChat(curr, lobby),
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                        Future.delayed(const Duration(milliseconds: 100), () {
                          Navigator.pop(context);
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: const Color(0xFFF5F5F5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        height: 40,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.search,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                              const SizedBox(
                                width: 8,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchBoxFilter,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Type text...',
                                  ),
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                bottom: (appBarHeight - 40) / 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _tabController.animation!,
                    builder: (BuildContext context, Widget? child) {
                      return GestureDetector(
                        onTap: () {
                          _tabController.animateTo(0);
                        },
                        child: Container(
                          width: 2 * appBarHeight,
                          decoration: BoxDecoration(
                            color: _leftTabIconColor.value,
                            borderRadius:
                                BorderRadius.circular(appBarHeight / 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Center(
                              child: Text(
                                'Chats',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  AnimatedBuilder(
                    animation: _tabController.animation!,
                    builder: (BuildContext context, Widget? child) {
                      return GestureDetector(
                        onTap: () {
                          _tabController.animateTo(1);
                        },
                        child: Container(
                          width: 2 * appBarHeight,
                          decoration: BoxDecoration(
                            color: _rightTabIconColor.value,
                            borderRadius:
                                BorderRadius.circular(appBarHeight / 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Center(
                              child: Text(
                                'People',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                        ),
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
                  Stack(
                    key: UniqueKey(),
                    children: <Widget>[
                      _buildChatsList(),
                      Visibility(
                        visible: filteredSubscribedChats.isEmpty,
                        child: Center(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: 200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Image.asset(
                                    'assets/icons8/sport-yoga-reading-1.png',
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 25,
                                    ),
                                    child: Text(
                                      'Nothing was found',
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Stack(
                    key: UniqueKey(),
                    children: <Widget>[
                      _buildPeopleList(),
                      Visibility(
                        visible: (filteredAllIds.isEmpty) &&
                            (filteredContactsIds.isEmpty),
                        child: Center(
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: 200,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Image.asset(
                                    'assets/icons8/virtual-reality.png',
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 25,
                                    ),
                                    child: Text(
                                      'Nothing was found',
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatsList() {
    if (_searchContent.isNotEmpty) {
      final tempChatsList = <Chat>[];
      for (final chat in subscribedChats) {
        if (chat.chatName
                ?.toLowerCase()
                .contains(_searchContent.toLowerCase()) ??
            false) {
          tempChatsList.add(chat);
        }
      }
      filteredSubscribedChats = tempChatsList;

      final tempList = <VisibleChatLobbyRecord>[];
      for (final lobby in publicChats) {
        if (lobby.lobbyName
                ?.toLowerCase()
                .contains(_searchContent.toLowerCase()) ??
            false) {
          tempList.add(lobby);
        }
      }
      filteredPublicChats = tempList;
    } else {
      filteredSubscribedChats = subscribedChats;
      filteredPublicChats = publicChats;
    }

    final combinedList = [...filteredSubscribedChats, ...filteredPublicChats];

    return Visibility(
      visible: combinedList.isNotEmpty,
      child: CustomScrollView(
        key: UniqueKey(),
        slivers: <Widget>[
          if (filteredSubscribedChats.isNotEmpty)
            sliverPersistentHeader('Subscribed Chats', context),
          if (filteredSubscribedChats.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(
                left: 8,
                top: 8,
                right: 16,
                bottom: 8,
              ),
              sliver: SliverFixedExtentList(
                itemExtent: personDelegateHeight,
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final chat = filteredSubscribedChats[index];
                    final delegateData = PersonDelegateData(
                      name: chat.chatName ?? 'Unknown Chat',
                      message: chat.lobbyTopic ?? '',
                      mId: chat.chatId?.toString(),
                      isRoom: true,
                      isMessage: true,
                      icon: (chat.isPublic) ? Icons.public : Icons.lock,
                      isUnread: (chat.unreadCount) > 0,
                    );
                    return GestureDetector(
                      child: PersonDelegate(
                        data: delegateData,
                        onPressed: () => _goToChat(chat),
                      ),
                    );
                  },
                  childCount: filteredSubscribedChats.length,
                ),
              ),
            ),
          if (filteredPublicChats.isNotEmpty)
            sliverPersistentHeader('Public Chats', context),
          if (filteredPublicChats.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(
                left: 8,
                top: 8,
                right: 16,
                bottom: 8,
              ),
              sliver: SliverFixedExtentList(
                itemExtent: personDelegateHeight,
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final lobby = filteredPublicChats[index];
                    final delegateData = PersonDelegateData(
                      name: lobby.lobbyName ?? 'Unknown Lobby',
                      message: (lobby.lobbyTopic ?? '') +
                          (lobby.totalNumberOfPeers != null &&
                                  (lobby.totalNumberOfPeers ?? 0) != 0
                              ? ' Total: ${lobby.totalNumberOfPeers ?? 0}'
                              : ' ') +
                          (lobby.participatingFriends.isNotEmpty
                              ? ' Friends: ${lobby.participatingFriends.length}'
                              : ''),
                      mId: lobby.lobbyId?.xstr64,
                      isRoom: true,
                      isMessage: true,
                      icon: (Chat.isPublicChat(lobby.lobbyFlags ?? 0))
                          ? Icons.public
                          : Icons.lock,
                    );
                    return GestureDetector(
                      child: PersonDelegate(
                        data: delegateData,
                        onPressed: () {
                          print('Tapped public chat: ${lobby.lobbyName}');
                        },
                      ),
                    );
                  },
                  childCount: filteredPublicChats.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeopleList() {
    if (_searchContent.isNotEmpty) {
      final tempAllIdsList = <Identity>[];
      for (final id in allIds) {
        if (id.name?.toLowerCase().contains(_searchContent.toLowerCase()) ??
            false) {
          tempAllIdsList.add(id);
        }
      }
      filteredAllIds = tempAllIdsList;

      final tempContactsList = <Identity>[];
      for (final id in contactsIds) {
        if (id.name?.toLowerCase().contains(_searchContent.toLowerCase()) ??
            false) {
          tempContactsList.add(id);
        }
      }
      filteredContactsIds = tempContactsList;
    } else {
      filteredAllIds = allIds;
      filteredContactsIds = contactsIds;
    }

    return Visibility(
      visible: filteredContactsIds.isNotEmpty || filteredAllIds.isNotEmpty,
      child: CustomScrollView(
        key: UniqueKey(),
        slivers: <Widget>[
          if (filteredContactsIds.isNotEmpty)
            sliverPersistentHeader('Contacts', context),
          if (filteredContactsIds.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(
                left: 8,
                top: 8,
                right: 16,
                bottom: 8,
              ),
              sliver: SliverFixedExtentList(
                itemExtent: personDelegateHeight,
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final id = filteredContactsIds[index];
                    final currentIdenInfo =
                        Provider.of<Identities>(context, listen: false)
                            .currentIdentity;
                    final delegateData = PersonDelegateData(
                      name: id.name ?? 'Unknown Identity',
                      mId: id.mId,
                      image: id.avatar != null && id.avatar!.isNotEmpty
                          ? MemoryImage(base64Decode(id.avatar!))
                          : null,
                      isMessage: true,
                      isUnread: currentIdenInfo != null &&
                          Provider.of<RoomChatLobby>(context, listen: false)
                                  .getUnreadCount(id, currentIdenInfo) >
                              0,
                    );
                    return GestureDetector(
                      child: PersonDelegate(
                        data: delegateData,
                        onPressed: () {
                          final curr =
                              Provider.of<Identities>(context, listen: false)
                                  .currentIdentity;
                          if (curr == null) {
                            return;
                          }
                          final chat =
                              Provider.of<RoomChatLobby>(context, listen: false)
                                  .getChat(curr, id);
                          _goToChat(chat!);
                        },
                      ),
                    );
                  },
                  childCount: filteredContactsIds.length,
                ),
              ),
            ),
          if (filteredAllIds.isNotEmpty)
            sliverPersistentHeader('Other People', context),
          if (filteredAllIds.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.only(
                left: 8,
                top: 8,
                right: 16,
                bottom: 8,
              ),
              sliver: SliverFixedExtentList(
                itemExtent: personDelegateHeight,
                delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                    final id = filteredAllIds[index];
                    final currentIdenInfo =
                        Provider.of<Identities>(context, listen: false)
                            .currentIdentity;
                    final delegateData = PersonDelegateData(
                      name: id.name ?? 'Unknown Identity',
                      mId: id.mId,
                      image: id.avatar != null && id.avatar!.isNotEmpty
                          ? MemoryImage(base64Decode(id.avatar!))
                          : null,
                      isMessage: true,
                      isUnread: currentIdenInfo != null &&
                          Provider.of<RoomChatLobby>(context, listen: false)
                                  .getUnreadCount(id, currentIdenInfo) >
                              0,
                    );
                    return GestureDetector(
                      child: PersonDelegate(
                        data: delegateData,
                        onPressed: () {
                          final curr =
                              Provider.of<Identities>(context, listen: false)
                                  .currentIdentity;
                          if (curr == null) {
                            return;
                          }
                          final chat =
                              Provider.of<RoomChatLobby>(context, listen: false)
                                  .getChat(curr, id);
                          _goToChat(chat!);
                        },
                      ),
                    );
                  },
                  childCount: filteredAllIds.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
