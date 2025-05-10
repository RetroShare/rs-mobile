import 'package:flutter/material.dart';
import 'package:retroshare/ui/about_screen.dart';
import 'package:retroshare/ui/add_friend/add_friend_screen.dart';
import 'package:retroshare/ui/change_identity_screen.dart';
import 'package:retroshare/ui/create_identity/create_identity_screen.dart';
import 'package:retroshare/ui/create_room_screen.dart';
import 'package:retroshare/ui/discover_chats_screen.dart';
import 'package:retroshare/ui/friends_locations_screen.dart';
import 'package:retroshare/ui/home/home_screen.dart';
import 'package:retroshare/ui/launch_transition_screen.dart';
import 'package:retroshare/ui/notification_screen.dart';
import 'package:retroshare/ui/profile_screen.dart';
import 'package:retroshare/ui/room/room_screen.dart';
import 'package:retroshare/ui/search_screen.dart';
import 'package:retroshare/ui/signin_screen.dart';
import 'package:retroshare/ui/signup_screen.dart';
import 'package:retroshare/ui/splash_screen.dart';
import 'package:retroshare/ui/update_identity_screen.dart';
import 'package:retroshare_api_wrapper/retroshare.dart' show Identity, Chat;

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case '/':
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => SplashScreen(
              isLoading: args['isLoading'] as bool? ?? false,
              spinner: args['spinner'] as bool? ?? false,
              statusText: args['statusText'] as String? ?? '',
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/home':
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case '/signin':
        return MaterialPageRoute(builder: (_) => const SignInScreen());
      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignUpScreen());
      case '/launch_transition':
        return MaterialPageRoute(
          builder: (_) => const LaunchTransitionScreen(),
        );
      case '/updateIdentity':
        if (args is Map<String, dynamic> && args['id'] is Identity) {
          return MaterialPageRoute(
            builder: (_) => UpdateIdentityScreen(
              curr: args['id'] as Identity,
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const UpdateIdentityScreen());
      case '/room':
        if (args is Map<String, dynamic> &&
            args['isRoom'] is bool &&
            args['chatData'] is Chat) {
          return MaterialPageRoute(
            builder: (_) => RoomScreen(
              isRoom: args['isRoom'] as bool,
              chat: args['chatData'] as Chat,
            ),
          );
        }
        debugPrint('Error: Invalid arguments for /room route: $args');
        return _errorRoute();
      case '/create_room':
        return MaterialPageRoute(builder: (_) => const CreateRoomScreen());
      case '/create_identity':
        if (args is bool) {
          return MaterialPageRoute(
            builder: (_) => CreateIdentityScreen(isFirstId: args),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const CreateIdentityScreen(),
        );
      case '/profile':
        if (args is Map<String, dynamic> && args['id'] is Identity) {
          return MaterialPageRoute(
            builder: (_) => ProfileScreen(
              curr: args['id'] as Identity,
            ),
          );
        }
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case '/change_identity':
        return MaterialPageRoute(builder: (_) => const ChangeIdentityScreen());
      case '/add_friend':
        return MaterialPageRoute(builder: (_) => const AddFriendScreen());
      case '/discover_chats':
        return MaterialPageRoute(builder: (_) => const DiscoverChatsScreen());
      case '/search':
        if (args is int) {
          return MaterialPageRoute(
            builder: (_) => SearchScreen(initialTab: args),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const SearchScreen(initialTab: 0),
        );
      case '/friends_locations':
        return MaterialPageRoute(
          builder: (_) => const FriendsLocationsScreen(),
        );
      case '/about':
        return MaterialPageRoute(builder: (_) => const AboutScreen());
      case '/notification':
        return MaterialPageRoute(builder: (_) => const NotificationScreen());
      default:
        debugPrint('Error: Route not found: ${settings.name}');
        return _errorRoute();
    }
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Error'),
          ),
          body: const Center(
            child: Text('Page not found or invalid arguments.'),
          ),
        );
      },
    );
  }
}
