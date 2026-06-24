// ignore_for_file: prefer_constructors_over_static_methods

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/identicon.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/friend_location.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class PersonDelegateData {
  const PersonDelegateData({
    required this.name,
    this.mId,
    this.message = '',
    this.time = '',
    this.profileImage = '',
    this.isOnline = false,
    this.isMessage = false,
    this.isUnread = false,
    this.unreadCount = 0,
    this.isTime = false,
    this.isRoom = false,
    this.status = 0,
    this.isContact = false,
    this.icon = Icons.person,
    this.image,
  });

  final String name;
  final String? mId;
  final String message;
  final String time;
  final String profileImage;
  final bool isOnline;
  final bool isMessage;
  final bool isUnread;
  final int unreadCount;
  final bool isTime;
  final bool isRoom;
  final int status;
  final bool isContact;
  final IconData icon;
  final MemoryImage? image;

  /// Generate generic chat person delegate data for DRY
  static PersonDelegateData chatData(Chat chatData) {
    return PersonDelegateData(
      name: chatData.chatName ?? 'Unknown Chat',
      message: chatData.lobbyTopic ?? '',
      mId: chatData.chatId?.toString(),
      isRoom: chatData.isPublic,
      isMessage: true,
      icon: (chatData.isPublic) ? Icons.public : Icons.lock,
      isUnread: (chatData.unreadCount) > 0,
      unreadCount: chatData.unreadCount,
    );
  }

  static PersonDelegateData distantChatData(
    Chat chat,
    Identity identity,
    BuildContext context,
  ) {
    final friendLocs =
        Provider.of<FriendLocations>(context, listen: false).friendlist;
    final matchingLocs = friendLocs.where((loc) =>
        loc.rsGpgId.isNotEmpty &&
        identity.pgpId != null &&
        loc.rsGpgId.toLowerCase() == identity.pgpId!.toLowerCase() &&
        loc.rsGpgId != '0000000000000000');

    final isAnyLocationOnline = matchingLocs.any((loc) => loc.isOnline);

    int effectiveStatus = identity.status;
    for (final loc in matchingLocs) {
      if (loc.isOnline) {
        int locStat = loc.status == 4 ? 0 : loc.status;
        int curStat = effectiveStatus == 4 ? 0 : effectiveStatus;
        if (locStat > curStat) {
          effectiveStatus = loc.status;
        } else if (effectiveStatus == 0) {
          effectiveStatus = 3; // Online
        }
      }
    }

    return PersonDelegateData(
      name: identity.name ?? chat.chatName ?? 'Unknown Identity',
      mId: identity.mId,
      image: identity.avatar != null && identity.avatar!.isNotEmpty
          ? MemoryImage(base64Decode(identity.avatar!))
          : null,
      status: effectiveStatus,
      isOnline: isAnyLocationOnline,
      isContact: identity.isContact,
      isMessage: true,
      isUnread: chat.unreadCount > 0,
      unreadCount: chat.unreadCount,
    );
  }

  static PersonDelegateData publicChatData(VisibleChatLobbyRecord chatData) {
    final message = (chatData.lobbyTopic ?? '') +
        (chatData.totalNumberOfPeers != null &&
                (chatData.totalNumberOfPeers ?? 0) != 0
            ? ' Total: ${chatData.totalNumberOfPeers ?? 0}'
            : ' ') +
        (chatData.participatingFriends.isNotEmpty
            ? ' Friends: ${chatData.participatingFriends.length}'
            : '');

    return PersonDelegateData(
      name: chatData.lobbyName ?? 'Unknown Lobby',
      message: message,
      mId: chatData.lobbyId?.xstr64,
      isRoom: true,
      isMessage: true,
      icon: (Chat.isPublicChat(chatData.lobbyFlags ?? 0))
          ? Icons.public
          : Icons.lock,
    );
  }

  static PersonDelegateData identityData(
    Identity identity,
    BuildContext context,
  ) {
    final currentIdenInfo =
        Provider.of<Identities>(context, listen: false).currentIdentity;

    final friendLocs =
        Provider.of<FriendLocations>(context, listen: false).friendlist;

    final matchingLocs = friendLocs.where((loc) =>
        loc.rsGpgId.isNotEmpty &&
        identity.pgpId != null &&
        loc.rsGpgId.toLowerCase() == identity.pgpId!.toLowerCase() &&
        loc.rsGpgId != '0000000000000000');

    final isAnyLocationOnline = matchingLocs.any((loc) => loc.isOnline);

    int effectiveStatus = identity.status;
    
    // Check if any matching online location has a more specific status
    for (final loc in matchingLocs) {
      if (loc.isOnline) {
        // Map INACTIVE (4) to something lower than ONLINE (3) for priority
        int locStat = loc.status == 4 ? 0 : loc.status;
        int curStat = effectiveStatus == 4 ? 0 : effectiveStatus;
        if (locStat > curStat) {
          effectiveStatus = loc.status;
        } else if (effectiveStatus == 0) {
          effectiveStatus = 3; // Default to Online (3) if we know it's connected
        }
      }
    }

    final unreadCount = currentIdenInfo != null
        ? Provider.of<RoomChatLobby>(context, listen: false)
            .getUnreadCount(identity, currentIdenInfo)
        : 0;

    return PersonDelegateData(
      name: identity.name ?? 'Unknown Identity',
      mId: identity.mId,
      image: identity.avatar != null && identity.avatar!.isNotEmpty
          ? MemoryImage(base64Decode(identity.avatar!))
          : null,
      status: effectiveStatus,
      isOnline: isAnyLocationOnline,
      isContact: identity.isContact,
      isMessage: true,
      // ignore: avoid_bool_literals_in_conditional_expressions
      isUnread: unreadCount > 0,
      unreadCount: unreadCount,
    );
  }

  // ignore: non_constant_identifier_names
  static PersonDelegateData locationData(Location location) {
    return PersonDelegateData(
      name: '${location.accountName}:${location.locationName}',
      mId: null,
      message: '${location.rsGpgId}:${location.rsPeerId}',
      isOnline: location.isOnline,
      status: location.status,
      isContact: true,
      isMessage: true,
      icon: Icons.devices,
    );
  }
}

class PersonDelegate extends StatefulWidget {
  const PersonDelegate({
    required this.data,
    this.onPressed,
    this.onLongPress,
    this.onAvatarPressed,
    this.isSelectable = false,
    super.key,
  });
  final PersonDelegateData data;
  final Function? onPressed;
  final Function? onLongPress;
  final Function? onAvatarPressed;
  final bool isSelectable;

  @override
  PersonDelegateState createState() => PersonDelegateState();
}

// Todo: implement ListTile or ExpansionPanel or similar class here
class PersonDelegateState extends State<PersonDelegate>
    with SingleTickerProviderStateMixin {
  final double delegateHeight = personDelegateHeight;

  late Animation<Decoration> boxShadow;
  late AnimationController _animationController;
  late CurvedAnimation _curvedAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _curvedAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    boxShadow = DecorationTween(
      begin: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.transparent,
            spreadRadius: appBarHeight / 3,
          ),
        ],
        borderRadius: const BorderRadius.all(Radius.circular(appBarHeight / 3)),
        color: Colors.transparent,
      ),
      end: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black12
                : Colors.white10,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        borderRadius: const BorderRadius.all(Radius.circular(appBarHeight / 3)),
        color: Theme.of(context).colorScheme.surface,
      ),
    ).animate(_curvedAnimation);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Offset? _tapPosition;
  void _storePosition(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 3: // RS_STATUS_ONLINE
        return Colors.lightGreenAccent;
      case 1: // RS_STATUS_AWAY
        return Colors.orange;
      case 2: // RS_STATUS_BUSY
        return Colors.red;
      case 4: // RS_STATUS_INACTIVE
        return Colors.grey.withOpacity(0.8);
      default:
        return Colors.grey.withOpacity(0.5);
    }
  }

  Widget _build(BuildContext context, [Identity? id]) {
    return GestureDetector(
      onTap: () {
        if (widget.onPressed != null) {
          widget.onPressed!();
        }
      },
      onLongPress: () {
        if (widget.onLongPress != null && _tapPosition != null) {
          widget.onLongPress!(_tapPosition!);
        }
      },
      onTapDown: _storePosition,
      child: AnimatedContainer(
        duration: const Duration(seconds: 1),
        curve: Curves.fastOutSlowIn,
        height: delegateHeight,
        decoration: boxShadow.value,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: delegateHeight,
              height: delegateHeight,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  Center(
                    child: Visibility(
                      visible: widget.data.isUnread,
                      child: Container(
                        height: delegateHeight * 0.92,
                        width: delegateHeight * 0.92,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF00FFFF),
                              Color(0xFF29ABE2),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            delegateHeight * 0.92 * 0.33,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: GestureDetector(
                      onTap: widget.onAvatarPressed != null
                          ? () => widget.onAvatarPressed!()
                          : null,
                      child: Container(
                        height: widget.data.isUnread
                            ? delegateHeight * 0.88
                            : delegateHeight * 0.8,
                        width: widget.data.isUnread
                            ? delegateHeight * 0.88
                            : delegateHeight * 0.8,
                        decoration: (widget.data.image == null)
                            ? null
                            : BoxDecoration(
                                border: widget.data.isUnread
                                    ? Border.all(
                                        color: Colors.white,
                                        width: delegateHeight * 0.03,
                                      )
                                    : null,
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  delegateHeight * 0.92 * 0.33,
                                ),
                                image: widget.data.image != null
                                    ? DecorationImage(
                                        fit: BoxFit.fill,
                                        image: widget.data.image!,
                                        onError: (exception, stackTrace) {
                                          print(
                                            'Error loading image in PersonDelegate: $exception',
                                          );
                                        },
                                      )
                                    : null,
                              ),
                        child: Visibility(
                          visible: widget.data.image == null,
                          child: Center(
                            child: (widget.data.mId != null)
                                ? Identicon(
                                    id: widget.data.mId!,
                                    size: delegateHeight * 0.8,
                                    borderRadius: delegateHeight * 0.92 * 0.33,
                                  )
                                : Icon(
                                    widget.data.icon,
                                    size: personDelegateIconHeight,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!widget.data.isRoom &&
                      widget.data.isContact &&
                      (widget.data.isOnline || widget.data.status != 0))
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        height: 14,
                        width: 14,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                          color: widget.data.status != 0
                              ? _getStatusColor(widget.data.status)
                              : Colors.lightGreenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: [
                        SizedBox(
                          width: 200,
                          child: Text(
                            widget.data.name,
                            style: widget.data.isMessage
                                ? Theme.of(context).textTheme.bodyLarge
                                : Theme.of(context).textTheme.bodyLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Spacer(),
                        Visibility(
                          visible: widget.isSelectable &&
                              _curvedAnimation.value == 1,
                          child: IconButton(
                            icon: const Icon(Icons.navigate_next),
                            onPressed: () {
                              if (id != null) {
                                Navigator.of(context).pushReplacementNamed(
                                  '/profile',
                                  arguments: {'id': id},
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    Visibility(
                      visible: widget.data.isMessage &&
                          widget.data.message.isNotEmpty,
                      child: Text(
                        widget.data.message,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Visibility(
              visible: widget.data.isTime || widget.data.isUnread,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.data.isTime)
                    Text(
                      widget.data.time,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  if (widget.data.isUnread && widget.data.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      child: Center(
                        child: Text(
                          widget.data.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSelectable) {
      return Consumer<Identities>(
        key: UniqueKey(),
        builder: (context, id, _) {
          if (id.selectedIdentity != null &&
              id.selectedIdentity!.mId == widget.data.mId) {
            _animationController.value = 1;
          } else {
            _animationController.value = 0;
          }

          return _build(context, id.selectedIdentity);
        },
      );
    }

    return _build(context);
  }
}

/// Todo: do this better when new PersonDelegate
/// class will be implemented. For ListTile, integrate new popup menu.
Future<void> showCustomMenu(
  String title,
  Icon icon,
  Function action,
  Offset tapPosition,
  BuildContext context, {
  List<({String title, Icon icon, Function action})>? additionalActions,
}) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;

  final List<PopupMenuEntry<int>> items = [
    PopupMenuItem(
      value: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: icon,
        title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      ),
    ),
  ];

  if (additionalActions != null) {
    for (int i = 0; i < additionalActions.length; i++) {
      items.add(
        PopupMenuItem(
          value: i + 1,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: additionalActions[i].icon,
            title: Text(additionalActions[i].title,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ),
      );
    }
  }

  final delta = await showMenu(
    context: context,
    items: items,
    position: RelativeRect.fromRect(
      tapPosition & const Size(40, 40),
      Offset.zero & overlay.semanticBounds.size,
    ),
  );

  if (delta != null) {
    if (delta == 0) {
      action();
    } else if (additionalActions != null && delta <= additionalActions.length) {
      additionalActions[delta - 1].action();
    }
  }
}
