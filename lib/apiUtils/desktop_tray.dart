import 'dart:async';
import 'dart:io';
import 'package:flutter_window_close/flutter_window_close.dart';
import 'package:nativeapi/nativeapi.dart';
import 'package:retroshare/apiUtils/retroshare_service.dart';

late final TrayIcon _trayIcon;

void initDesktopTray() {
  if (!Platform.isWindows) return;

  final windowManager = WindowManager.instance;
  final window = windowManager.getCurrent();

  print('Initializing desktop system tray...');
  // Create Tray Icon
  _trayIcon = TrayIcon();
  final iconImage = Image.fromAsset('assets/mobile-logo.png');
  if (iconImage == null) {
    print('Warning: Failed to load tray icon image from assets/mobile-logo.png');
  } else {
    print('Successfully loaded tray icon image: size=${iconImage.size}');
    _trayIcon.icon = iconImage;
  }
  _trayIcon.title = 'RetroShare';
  _trayIcon.tooltip = 'RetroShare Mobile';
  _trayIcon.isVisible = true;

  // Set up the context menu
  final menu = Menu();
  final showItem = MenuItem('Show App');
  showItem.startEventListening();
  showItem.on<MenuItemClickedEvent>((_) {
    window?.show();
    window?.focus();
  });

  final exitItem = MenuItem('Exit');
  exitItem.startEventListening();
  exitItem.on<MenuItemClickedEvent>((_) async {
    try {
      await RsServiceControl.stopRetroshare(wait: false);
    } catch (e) {
      print('Error stopping service on exit: $e');
    }
    _trayIcon.dispose();
    exit(0);
  });

  menu.addItem(showItem);
  menu.addSeparator();
  menu.addItem(exitItem);

  _trayIcon.contextMenu = menu;
  _trayIcon.contextMenuTrigger = ContextMenuTrigger.rightClicked;
  _trayIcon.startEventListening();

  // Left click / double click restores the window
  _trayIcon.on<TrayIconClickedEvent>((_) {
    window?.show();
    window?.focus();
  });

  _trayIcon.on<TrayIconDoubleClickedEvent>((_) {
    window?.show();
    window?.focus();
  });

  // Intercept the close request and hide window
  FlutterWindowClose.setWindowShouldCloseHandler(() async {
    window?.hide();
    return false; // Return false to prevent window close
  });
}
