import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/person_delegate.dart';
import 'package:retroshare/common/sliver_persistent_header.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  FriendsTabState createState() => FriendsTabState();
}

class FriendsTabState extends State<FriendsTab> {
  void _removeFromContacts(String gxsId) {
    Provider.of<RoomChatLobby>(context, listen: false)
        .toggleContacts(gxsId, false);
  }

  void _addToContacts(String gxsId) {
    Provider.of<RoomChatLobby>(context, listen: false)
        .toggleContacts(gxsId, true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Consumer<RoomChatLobby>(
        builder: (context, roomChat, _) {
          final (
            List<Identity> friendsList,
            List<Chat> distantChats,
            Map<String, Identity> allIdentities
          ) = (
            roomChat.friendsIdsList,
            roomChat.distanceChat.values
                .toList()
                .where(
                  (chat) =>
                      roomChat.allIdentity[chat.interlocutorId] == null ||
                      roomChat.allIdentity[chat.interlocutorId]!.isContact ==
                          false,
                )
                .toSet()
                .toList(),
            roomChat.allIdentity,
          );

          if (friendsList.isNotEmpty) {
            return CustomScrollView(
              slivers: <Widget>[
                sliverPersistentHeader('Contacts', context),
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: 8,
                    top: 8,
                    right: 16,
                    bottom: (distantChats.isEmpty)
                        ? homeScreenBottomBarHeight * 2
                        : 8.0,
                  ),
                  sliver: SliverFixedExtentList(
                    itemExtent: personDelegateHeight,
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        return GestureDetector(
                          // Todo: DRY
                          child: PersonDelegate(
                            data: PersonDelegateData.identityData(
                              friendsList[index],
                              context,
                            ),
                            onLongPress: (Offset tapPosition) {
                              showCustomMenu(
                                'Remove from contacts',
                                const Icon(
                                  Icons.delete,
                                  color: Colors.black,
                                ),
                                () => _removeFromContacts(
                                  friendsList[index].mId,
                                ),
                                tapPosition,
                                context,
                              );
                            },
                            onPressed: () async {
                              final curr = Provider.of<Identities>(
                                context,
                                listen: false,
                              ).currentIdentity;
                              if (curr == null) return;
                              await Navigator.pushNamed(
                                context,
                                '/room',
                                arguments: {
                                  'isRoom': false,
                                  'chatData': Provider.of<RoomChatLobby>(
                                    context,
                                    listen: false,
                                  ).getChat(
                                    curr,
                                    friendsList[index],
                                  ),
                                },
                              );
                            },
                          ),
                        );
                      },
                      childCount: friendsList.length,
                    ),
                  ),
                ),
                SliverOpacity(
                  opacity:
                      (distantChats.isNotEmpty) && (distantChats.isNotEmpty)
                          ? 1.0
                          : 0.0,
                  sliver: sliverPersistentHeader('People', context),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    top: 8,
                    right: 16,
                    bottom: homeScreenBottomBarHeight * 2,
                  ),
                  sliver: SliverFixedExtentList(
                    itemExtent: personDelegateHeight,
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final actualId =
                            allIdentities[distantChats[index].interlocutorId] ??
                                Identity(
                                  mId: distantChats[index].interlocutorId,
                                  signed: false,
                                  isContact: false,
                                );
                        return GestureDetector(
                          // Todo: DRY
                          child: PersonDelegate(
                            data: PersonDelegateData.identityData(
                              actualId,
                              context,
                            ),
                            onLongPress: (Offset tapPosition) {
                              showCustomMenu(
                                'Add to contacts',
                                const Icon(
                                  Icons.add,
                                  color: Colors.black,
                                ),
                                () => _addToContacts(actualId.mId),
                                tapPosition,
                                context,
                              );
                            },
                            onPressed: () async {
                              final curr = Provider.of<Identities>(
                                context,
                                listen: false,
                              ).currentIdentity;
                              if (curr == null) return;
                              await Navigator.pushNamed(
                                context,
                                '/room',
                                arguments: {
                                  'isRoom': false,
                                  'chatData': Provider.of<RoomChatLobby>(
                                    context,
                                    listen: false,
                                  ).getChat(curr, actualId),
                                },
                              );
                            },
                          ),
                        );
                      },
                      childCount: distantChats.toSet().length,
                    ),
                  ),
                ),
              ],
            );
          }

          return Center(
            child: SizedBox(
              width: 200,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset('assets/icons8/list-is-empty-3.png'),
                  const SizedBox(
                    height: 20,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(
                      'Looks like an empty space',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Text(
                      'You can add friends in the menu',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(
                    height: 50,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
