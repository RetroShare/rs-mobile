import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/person_delegate.dart';
import 'package:retroshare/common/sliver_persistent_header.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/friend_location.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

enum ContactSortOption { name, state }

class FriendsTab extends StatefulWidget {
  const FriendsTab({super.key});

  @override
  FriendsTabState createState() => FriendsTabState();
}

class FriendsTabState extends State<FriendsTab> {
  ContactSortOption _sortOption = ContactSortOption.name;

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
      child: Consumer3<RoomChatLobby, FriendLocations, Identities>(
        builder: (context, roomChat, friendLocations, identities, _) {
          final List<Identity> rawFriendsList = roomChat.friendsIdsList;
          final List<Chat> distantChats = roomChat.distanceChat.values
              .toList()
              .where(
                (chat) =>
                    roomChat.allIdentity[chat.interlocutorId] == null ||
                    roomChat.allIdentity[chat.interlocutorId]!.isContact ==
                        false,
              )
              .toSet()
              .toList();
          final Map<String, Identity> allIdentities = roomChat.allIdentity;

          // Apply sorting to friendsList
          List<Identity> friendsList = List.from(rawFriendsList);
          if (_sortOption == ContactSortOption.name) {
            friendsList.sort((a, b) => (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase()));
          } else if (_sortOption == ContactSortOption.state) {
            friendsList.sort((a, b) {
              // Online: 1, Away: 2, Busy: 3, Offline: 0
              // Mapping to weights for sorting: Online (0), Away (1), Busy (2), Offline (3)
              int getWeight(Identity id) {
                // Check if any location is online (matches PersonDelegate logic)
                final matchingLocs = friendLocations.friendlist.where((loc) =>
                    id.pgpId != null &&
                    loc.rsGpgId.toLowerCase() == id.pgpId!.toLowerCase() &&
                    loc.rsGpgId != '0000000000000000');
                
                final isAnyLocationOnline = matchingLocs.any((loc) => loc.isOnline);

                int effectiveStatus = id.status;
                for (final loc in matchingLocs) {
                  if (loc.isOnline) {
                    // Map INACTIVE (4) to something lower than ONLINE (3) for priority
                    int locStat = loc.status == 4 ? 0 : loc.status;
                    int curStat = effectiveStatus == 4 ? 0 : effectiveStatus;
                    if (locStat > curStat) {
                      effectiveStatus = loc.status;
                    } else if (effectiveStatus == 0) {
                      effectiveStatus = 3; // Default to Online if we know it's connected
                    }
                  }
                }
                
                if (effectiveStatus == 3) return 0; // Online
                if (effectiveStatus == 1) return 1; // Away
                if (effectiveStatus == 2) return 2; // Busy
                return 3; // Offline / Inactive
              }
              int weightA = getWeight(a);
              int weightB = getWeight(b);
              if (weightA != weightB) return weightA.compareTo(weightB);
              return (a.name ?? '').toLowerCase().compareTo((b.name ?? '').toLowerCase());
            });
          }

          if (friendsList.isNotEmpty) {
            return CustomScrollView(
              slivers: <Widget>[
                sliverPersistentHeader(
                  'Contacts',
                  context,
                  trailing: PopupMenuButton<ContactSortOption>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (ContactSortOption result) {
                      setState(() {
                        _sortOption = result;
                      });
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<ContactSortOption>>[
                      const PopupMenuItem<ContactSortOption>(
                        value: ContactSortOption.name,
                        child: Text('Sort by name'),
                      ),
                      const PopupMenuItem<ContactSortOption>(
                        value: ContactSortOption.state,
                        child: Text('Sort by state'),
                      ),
                    ],
                  ),
                ),
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
                        return PersonDelegate(
                          data: PersonDelegateData.identityData(
                            friendsList[index],
                            context,
                          ),
                          onAvatarPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/profile',
                              arguments: {'id': friendsList[index]},
                            );
                          },
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
                                additionalActions: [
                                  (
                                    title: 'View Details',
                                    icon: const Icon(Icons.info_outline,
                                        color: Colors.black),
                                    action: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/profile',
                                        arguments: {'id': friendsList[index]},
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                            onPressed: () async {
                              final curr = Provider.of<Identities>(
                                context,
                                listen: false,
                              ).currentIdentity;
                              if (curr == null) return;
                              final chatData = await Provider.of<RoomChatLobby>(
                                context,
                                listen: false,
                              ).getChat(
                                curr,
                                friendsList[index],
                              );
                              if (!context.mounted) return;
                              await Navigator.pushNamed(
                                context,
                                '/room',
                                arguments: {
                                  'isRoom': false,
                                  'chatData': chatData,
                                },
                              );
                            },
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
                        return PersonDelegate(
                          data: PersonDelegateData.identityData(
                            actualId,
                            context,
                          ),
                          onAvatarPressed: () {
                            Navigator.pushNamed(
                              context,
                              '/profile',
                              arguments: {'id': actualId},
                            );
                          },
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
                                additionalActions: [
                                  (
                                    title: 'View Details',
                                    icon: const Icon(Icons.info_outline,
                                        color: Colors.black),
                                    action: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/profile',
                                        arguments: {'id': actualId},
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                            onPressed: () async {
                              final curr = Provider.of<Identities>(
                                context,
                                listen: false,
                              ).currentIdentity;
                              if (curr == null) return;
                              final chatData = await Provider.of<RoomChatLobby>(
                                context,
                                listen: false,
                              ).getChat(curr, actualId);
                              if (!context.mounted) return;
                              await Navigator.pushNamed(
                                context,
                                '/room',
                                arguments: {
                                  'isRoom': false,
                                  'chatData': chatData,
                                },
                              );
                            },
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
