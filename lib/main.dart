import 'dart:io';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/apiUtils/desktop_tray.dart';
import 'package:retroshare/common/notifications.dart';
import 'package:retroshare/common/theme_data.dart';
import 'package:retroshare/model/app_life_cycle_state.dart';
import 'package:retroshare/provider/auth.dart';
import 'package:retroshare/provider/friend_location.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';
import 'package:retroshare/routes.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  await initializeNotifications();
  runApp(App(savedThemeMode: savedThemeMode));
}

class App extends StatefulWidget {
  const App({super.key, this.savedThemeMode});

  final AdaptiveThemeMode? savedThemeMode;

  @override
  // ignore: unnecessary_new
  _AppState createState() => new _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    // Used for notifications to open specific Navigator path
    configureSelectNotificationSubject(context);
    // Used to check when the app is on background
    WidgetsBinding.instance.addObserver(LifecycleEventHandler());
    
    if (Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        initDesktopTray();
      });
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AccountCredentials()),
        ChangeNotifierProxyProvider<AccountCredentials, Identities>(
          create: (_) => Identities(),
          update: (_, auth, identities) =>
              identities!
                ..authToken = auth.authtoken
                ..pgpPassword = auth.getPgpPassword,
        ),
        ChangeNotifierProxyProvider<AccountCredentials, FriendLocations>(
          create: (_) => FriendLocations(),
          update: (_, auth, friendLocations) {
            if (auth.authtoken != null) {
              friendLocations!..authToken = auth.authtoken!;
            }
            return friendLocations!;
          },
        ),
        ChangeNotifierProxyProvider<AccountCredentials, ChatLobby>(
          create: (_) => ChatLobby(),
          update: (_, auth, chatLobby) {
            if (auth.authtoken != null) {
              chatLobby!..authToken = auth.authtoken!;
            }
            return chatLobby!;
          },
        ),
        ChangeNotifierProxyProvider<AccountCredentials, RoomChatLobby>(
          create: (_) => RoomChatLobby(),
          update: (_, auth, roomChatLobby) {
            if (auth.authtoken != null) {
              roomChatLobby!..authToken = auth.authtoken!;
            }
            return roomChatLobby!;
          },
        ),
      ],
      child: AdaptiveTheme(
        light: lightTheme,
        dark: darkTheme,
        initial: widget.savedThemeMode ?? AdaptiveThemeMode.light,
        builder: (theme, darkTheme) => OKToast(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Retroshare',
            theme: theme,
            darkTheme: darkTheme,
            initialRoute: '/',
            onGenerateRoute: RouteGenerator.generateRoute,
          ),
        ),
      ),
    );
  }
}
