import 'dart:async';
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
  Timer? _inviteCheckTimer;
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

    // Start periodic invite check
    _inviteCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        Provider.of<ChatLobby>(context, listen: false).checkForNewInvites();
      }
    });
  }

  @override
  void didChangeDependencies() {
    if (_isInit) {
      _fetchInitialData();
      
      // Listen to both providers for unread changes to update the app icon badge
      Provider.of<ChatLobby>(context).addListener(_updateAppBadge);
      Provider.of<RoomChatLobby>(context).addListener(_updateAppBadge);
    }
    _isInit = false;
    super.didChangeDependencies();
  }

  void _updateAppBadge() {
    if (mounted) {
      BadgeHelper.updateAppBadge(context);
    }
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final chatLobby = Provider.of<ChatLobby>(context, listen: false);
      await chatLobby.fetchAndUpdate();
      await Provider.of<RoomChatLobby>(context, listen: false).fetchAndUpdate();
      await Provider.of<FriendLocations>(context, listen: false).fetchfriendLocation();
      await chatLobby.checkForNewInvites();
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
      final chatLobby = Provider.of<ChatLobby>(context, listen: false);
      await chatLobby.fetchAndUpdate();
      await Provider.of<RoomChatLobby>(context, listen: false).fetchAndUpdate();
      await Provider.of<FriendLocations>(context, listen: false).fetchfriendLocation();
      await chatLobby.checkForNewInvites();
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
    _inviteCheckTimer?.cancel();
    // Remove listeners to avoid memory leaks
    try {
      Provider.of<ChatLobby>(context, listen: false).removeListener(_updateAppBadge);
      Provider.of<RoomChatLobby>(context, listen: false).removeListener(_updateAppBadge);
    } catch (_) {
      // Providers might be already disposed during logout/shutdown
    }
    _tabController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _appBar() {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    const appBarHeight = 56;
    const verticalPadding = 8;
    final totalHeight = statusBarHeight + appBarHeight + verticalPadding * 2;
    final activeBlue = ColorScheme.fromSeed(
      seedColor: const Color(0xFF29ABE2),
      brightness: Brightness.dark,
    ).primary;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final appBarIconColor = isLight ? const Color(0xFF29ABE2) : activeBlue;
    final appBarTextColor = isLight ? const Color(0xFF29ABE2) : Theme.of(context).colorScheme.onSurface;

    return PreferredSize(
      preferredSize: Size.fromHeight(totalHeight),
      child: Stack(
        children: <Widget>[
          Container(
            height: totalHeight,
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
          ),
          Positioned(
            top: statusBarHeight + verticalPadding,
            left: 12,
            right: 12,
            height: appBarHeight.toDouble(),
            child: AppBar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              titleSpacing: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.menu,
                  color: appBarIconColor,
                ),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              primary: false,
              title: Text(
                'RetroShare',
                style: TextStyle(
                  color: appBarTextColor,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.start,
              ),
              actions: <Widget>[
                IconButton(
                  icon: Icon(
                    Icons.search,
                    color: appBarIconColor,
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
                IconButton(
                  icon: const NotificationIcon(),
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed('/notification')
                        .then((value) {
                      fetchdata(context);
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeBlue = ColorScheme.fromSeed(
      seedColor: const Color(0xFF29ABE2),
      brightness: Brightness.dark,
    ).primary;

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
        appBar: _appBar(),
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
          padding: EdgeInsets.zero,
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
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 26,
                                  color: _tabController.index == 0
                                      ? activeBlue
                                      : Theme.of(context).colorScheme.onSurface.withAlpha(128),
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
                            const SizedBox(height: 2),
                            Text(
                              'Chats',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _tabController.index == 0
                                    ? activeBlue
                                    : Theme.of(context).colorScheme.onSurface.withAlpha(128),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 26,
                          color: _tabController.index == 1
                              ? activeBlue
                              : Theme.of(context).colorScheme.onSurface.withAlpha(128),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Contacts',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _tabController.index == 1
                                ? activeBlue
                                : Theme.of(context).colorScheme.onSurface.withAlpha(128),
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
          height: 54,
          width: 54,
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
