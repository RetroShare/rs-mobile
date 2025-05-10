import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/rxdart.dart';

NotificationAppLaunchDetails? notificationAppLaunchDetails;
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final BehaviorSubject<String?> selectNotificationSubject =
    BehaviorSubject<String?>();

Future<void> initializeNotifications() async {
  notificationAppLaunchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

  const initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_notification');
  const initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) async {
      final payload = notificationResponse.payload;
      if (payload != null) {}
      selectNotificationSubject.add(payload);
    },
  );
}

void configureSelectNotificationSubject(BuildContext context) {
  selectNotificationSubject.stream.listen((String? payload) async {
    // Handle notification selection here if needed
    // Example: Navigate to a specific screen based on payload
    // if (payload != null) {
    //   await Navigator.push(
    //     context,
    //     MaterialPageRoute(builder: (context) => SecondScreen(payload)),
    //   );
    // }
  });
}

Future<void> showChatNotification(
  String chatId,
  String title,
  String body,
) async {
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

Future<void> showInviteCopyNotification() async {
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
