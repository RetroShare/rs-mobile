import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/apiUtils/eventsource.dart';
import 'package:retroshare/common/badge_helper.dart';
import 'package:retroshare/common/drawer.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare/provider/friend_location.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';
import 'package:retroshare/ui/home/chats_tab.dart';
import 'package:retroshare/ui/home/friends_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  bool _isInit = true;
  bool _isLoading = false;
  bool _isEventRegistered = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _isInit = true;
    _tabController = TabController(vsync: this, length: 2);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => BadgeHelper.updateAppBadge(context));
  }

  void _updateAppBadge() {
    if (mounted) {
      BadgeHelper.updateAppBadge(context);
    }
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _fetchInitialData();
      
      // Listen to both providers for unread changes
      Provider.of<ChatLobby>(context).addListener(_updateAppBadge);
      Provider.of<RoomChatLobby>(context).addListener(_updateAppBadge);
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<ChatLobby>(context, listen: false).fetchAndUpdate();
      await Provider.of<RoomChatLobby>(context, listen: false).fetchAndUpdate();
      await Provider.of<FriendLocations>(context, listen: false).fetchfriendLocation();
      await BadgeHelper.updateAppBadge(context);

      final authToken =
          Provider.of<AccountCredentials>(context, listen: false).authtoken;
      if (authToken != null && !_isEventRegistered) {
        await registerChatEvent(context, authToken);
        _isEventRegistered = true;
      }
    } catch (e) {
      debugPrint('Error during initial data fetch: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load initial data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> fetchdata(BuildContext context) async {
    try {
      await Provider.of<ChatLobby>(context, listen: false).fetchAndUpdate();
      await Provider.of<RoomChatLobby>(context, listen: false).fetchAndUpdate();
      await Provider.of<FriendLocations>(context, listen: false).fetchfriendLocation();
    } catch (e) {
      debugPrint('Error during fetchdata: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh data: $e')),
      );
    }
  }

  @override
  void dispose() {
    // Remove listeners to avoid memory leaks
    try {
      Provider.of<ChatLobby>(context, listen: false).removeListener(_updateAppBadge);
      Provider.of<RoomChatLobby>(context, listen: false).removeListener(_updateAppBadge);
    } catch (_) {
      // Providers might be already disposed
    }
    _tabController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _appBar(double height) => PreferredSize(
        preferredSize: Size.fromHeight(150 + height),
        child: Stack(
          children: <Widget>[
            Container(
              height: 140 + height / 2,
              width: MediaQuery.of(context).size.width,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color(0xFF00FFFF),
                    Color(0xFF29ABE2),
                  ],
                  begin: Alignment(-1, -4),
                  end: Alignment(1, 4),
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Text(
                    'Retroshare',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontFamily: 'Vollkorn',
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 90,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    leading: InkWell(
                      onTap: () {
                        _scaffoldKey.currentState?.openDrawer();
                      },
                      child: Icon(
                        Icons.menu,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    primary: false,
                    title: Text(
                      'Search',
                      style: TextStyle(
                        color: Theme.of(context).hintColor,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    actions: <Widget>[
                      IconButton(
                        icon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/search',
                            arguments: _tabController.index,
                          ).then((value) async {
                            await fetchdata(context);
                          });
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 14,
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context)
                                .pushNamed('/notification')
                                .then((value) {
                              fetchdata(context);
                            });
                          },
                          child: const NotificationIcon(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Consumer2<ChatLobby, RoomChatLobby>(
                    builder: (context, chatLobby, roomChatLobby, _) {
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

                      return TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.white,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white70,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Chats'),
                                if (totalUnread > 0) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      totalUnread.toString(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Tab(text: 'Friends'),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        onDrawerChanged: (val) async {
          if (!val) {
            await fetchdata(context);
          }
        },
        key: _scaffoldKey,
        resizeToAvoidBottomInset: false,
        drawer: drawerWidget(context),
        appBar: _appBar(AppBar().preferredSize.height),
        body: Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: const [
                ChatsTab(),
                FriendsTab(),
              ],
            ),
            if (_isLoading)
              const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 7,
          child: SizedBox(
            height: homeScreenBottomBarHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: () => _tabController.animateTo(0),
                    child: Consumer2<ChatLobby, RoomChatLobby>(
                      builder: (context, chatLobby, roomChatLobby, _) {
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
                        
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  color: _tabController.index == 0
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).disabledColor,
                                ),
                                if (totalUnread > 0)
                                  Positioned(
                                    right: -8,
                                    top: -8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Center(
                                        child: Text(
                                          totalUnread > 99 ? '99+' : totalUnread.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              'Chats',
                              style: TextStyle(
                                fontSize: 10,
                                color: _tabController.index == 0
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).disabledColor,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 74),
                Expanded(
                  child: InkWell(
                    onTap: () => _tabController.animateTo(1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: _tabController.index == 1
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).disabledColor,
                        ),
                        Text(
                          'Friends',
                          style: TextStyle(
                            fontSize: 10,
                            color: _tabController.index == 1
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: SizedBox(
          height: 60,
          width: 60,
          child: FittedBox(
            child: FloatingActionButton(
              backgroundColor: Colors.lightBlueAccent,
              onPressed: () async {
                await Navigator.pushNamed(context, '/create_room');
              },
              child: const Icon(
                Icons.add,
                size: 35,
                color: Colors.white,
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }
}
