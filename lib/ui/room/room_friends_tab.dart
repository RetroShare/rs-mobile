import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/person_delegate.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class RoomFriendsTab extends StatefulWidget {
  const RoomFriendsTab({super.key, required this.chat});
  final Chat chat;
  @override
  RoomFriendsTabState createState() => RoomFriendsTabState();
}

class RoomFriendsTabState extends State<RoomFriendsTab> {
  // Use late final if only assigned in initState
  late final Image myImage;

  @override
  void initState() {
    super.initState();
    myImage = Image.asset('assets/icons8/friends_together.png');

    // Precache image after the first frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // Check mounted state before accessing context
      if (mounted) {
        precacheImage(myImage.image, context);
      }
    });
  }

  // Keep this method if needed by showCustomMenu or other interactions
  void _addToContacts(String gxsId) {
    // Consider adding error handling for the provider call
    try {
      Provider.of<RoomChatLobby>(context, listen: false)
          .toggleContacts(gxsId, true);
      // Optionally show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to contacts')),
      );
    } catch (e) {
      debugPrint('Error adding contact: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add contact: $e')),
      );
    }
  }

  // Keep _storePosition if needed by showCustomMenu
  void _storePosition(TapDownDetails details) {}

  @override
  Widget build(BuildContext context) {
    // Check chat ID validity early
    final chatId = widget.chat.chatId;
    if (chatId == null) {
      return const Center(child: Text('Error: Invalid chat room.'));
    }

    // 4. Use FutureBuilder to ensure participants are loaded
    return FutureBuilder(
      future: Provider.of<RoomChatLobby>(context, listen: false)
          .updateParticipants(chatId),
      builder: (context, snapshot) {
        // 4. Handle error state
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading participants: ${snapshot.error}'),
          );
        }
        // Show loading indicator while waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Use Consumer to get the latest participant list after future completes
        return Consumer<RoomChatLobby>(
          builder: (context, lobbyData, _) {
            // 5. Simplify participant list retrieval
            final participantsMap = lobbyData.lobbyParticipants;
            final participantList = participantsMap[chatId] ?? [];

            // Show empty state or list
            return participantList.isEmpty
                ? Center(
                    child: SizedBox(
                      width: 200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          // 9. Ensure myImage is displayed correctly
                          myImage,
                          const SizedBox(height: 20),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Text(
                              'Looks like an empty space',
                              // Use theme
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Text(
                              'You can invite your friends',
                              // Use theme
                              style: Theme.of(context).textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    // 6. Simplify itemCount
                    itemCount: participantList.length,
                    itemBuilder: (BuildContext context, int index) {
                      // 6. Access is safe now assuming participantList is non-null List
                      final participant = participantList[index];
                      return GestureDetector(
                        onTapDown: _storePosition,
                        child: PersonDelegate(
                          // Pass non-nullable participant
                          data: PersonDelegateData.identityData(
                            participant,
                            context,
                          ),
                          // 7. Ensure showCustomMenu is defined and safe
                          onLongPress: (Offset tapPosition) {
                            showCustomMenu(
                              'Add to contacts',
                              const Icon(Icons.add, color: Colors.black),
                              () => _addToContacts(participant.mId),
                              tapPosition,
                              context,
                            );
                          },
                          // 8. Add basic error handling/check for navigation
                          onPressed: () async {
                            try {
                              final curr = Provider.of<Identities>(
                                context,
                                listen: false,
                              ).currentIdentity;
                              if (curr == null) {
                                return;
                              }
                              // Ensure current identity and participant are valid
                              final chatData = Provider.of<RoomChatLobby>(
                                context,
                                listen: false,
                              ).getChat(curr, participant);

                              await Navigator.pushNamed(
                                context,
                                '/room',
                                arguments: {
                                  'isRoom': false,
                                  'chatData': chatData,
                                },
                              );
                            } catch (e) {
                              debugPrint(
                                'Error navigating to participant chat: $e',
                              );
                              // Optionally show error to user
                            }
                          },
                        ),
                      );
                    },
                  );
          },
        );
      },
    );
  }
}
