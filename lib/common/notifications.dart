import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:retroshare/main.dart';
import 'package:rxdart/rxdart.dart';

NotificationAppLaunchDetails? notificationAppLaunchDetails;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final BehaviorSubject<String?> selectNotificationSubject =
    BehaviorSubject<String?>();

Future<void> initializeNotifications() async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

  notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  const initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) async {
      final payload = notificationResponse.payload;
      selectNotificationSubject.add(payload);
    },
  );
}

void configureSelectNotificationSubject(BuildContext context) {
  selectNotificationSubject.stream.listen((String? payload) async {
    if (payload != null && payload == '/notification') {
      navigatorKey.currentState?.pushNamed('/notification');
    }
  });
}

Future<void> showChatNotification(
  String chatId,
  String title,
  String body,
) async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

  // For multiple messages check: inbox notification
  //  var largeIconPath = await _downloadAndSaveFile(
  //      'http://via.placeholder.com/128x128/00FF00/000000', 'largeIcon');

  const androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'RetroshareFlutter',
    'RetroshareFlutter',
    channelDescription: 'Retroshare flutter app',
    importance: Importance.max,
    priority: Priority.high,
    ticker: 'ticker',
    color: Color.fromARGB(255, 35, 144, 191),
    ledColor: Color.fromARGB(255, 35, 144, 191),
    ledOnMs: 1000,
    ledOffMs: 500,
    // largeIcon: FilePathAndroidBitmap(largeIconPath),
  );
  const platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    int.tryParse(chatId) ?? 0,
    title,
    body,
    platformChannelSpecifics,
    payload: chatId,
  );
}

Future<void> showLobbyInviteNotification(
  String lobbyId,
  String lobbyName,
  String senderName,
) async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

  const androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'RetroshareInvites',
    'Retroshare Invites',
    channelDescription: 'Retroshare chat lobby invitations',
    importance: Importance.max,
    priority: Priority.high,
    color: Colors.purple,
  );
  const platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  
  await flutterLocalNotificationsPlugin.show(
    lobbyId.hashCode,
    'New Chat Room Invite',
    '$senderName invited you to join "$lobbyName"',
    platformChannelSpecifics,
    payload: '/notification', // Navigate to notifications screen on tap
  );
}

Future<void> showInviteCopyNotification() async {
  if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

  const androidPlatformChannelSpecifics = AndroidNotificationDetails(
    'RetroshareFlutter',
    'RetroshareFlutter',
    channelDescription: 'Retroshare flutter app',
    ticker: 'ticker',
  );
  const platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    1111,
    'Invite copied!',
    'Your RetroShare invite was copied to your clipboard',
    platformChannelSpecifics,
  );
}
