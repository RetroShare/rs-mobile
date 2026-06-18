import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/person_delegate.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/provider/subscribed.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  Future<void> _unsubscribeChatLobby(lobbyId, context) async {
    await Provider.of<ChatLobby>(context, listen: false).unsubscribed(lobbyId);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Consumer2<ChatLobby, RoomChatLobby>(
        builder: (context, chatLobby, roomChat, _) {
          final List<Chat> allChats = [
            ...chatLobby.subscribedlist,
            ...roomChat.distanceChat.values.toSet().where((c) => !c.isPublic),
          ];

          if (allChats.isNotEmpty) {
            return CustomScrollView(
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsets.only(
                    left: 8,
                    top: 8,
                    right: 16,
                    bottom: 8,
                  ),
                  sliver: SliverFixedExtentList(
                    itemExtent: personDelegateHeight,
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        final chat = allChats[index];
                        final isRoom = chat.isPublic;
                        return PersonDelegate(
                          data: isRoom
                              ? PersonDelegateData.chatData(chat)
                              : PersonDelegateData.identityData(
                                  roomChat.allIdentity[chat.interlocutorId] ??
                                      Identity(
                                        mId: chat.interlocutorId,
                                        signed: false,
                                        isContact: false,
                                        name: chat.chatName,
                                      ),
                                  context,
                                ),
                          onPressed: () async {
                            final curr =
                                Provider.of<Identities>(context, listen: false)
                                    .currentIdentity;
                            if (curr == null) return;
                            final chatData = await Provider.of<RoomChatLobby>(
                              context,
                              listen: false,
                            ).getChat(
                              curr,
                              chat,
                            );
                            if (!context.mounted) return;
                            await Navigator.pushNamed(
                              context,
                              '/room',
                              arguments: {
                                'isRoom': isRoom,
                                'chatData': chatData,
                              },
                            );
                          },
                          onLongPress: (Offset tapPosition) {
                            if (isRoom) {
                              showCustomMenu(
                                'Unsubscribe chat lobby',
                                const Icon(
                                  Icons.delete,
                                  color: Colors.black,
                                ),
                                () => _unsubscribeChatLobby(
                                  chat.chatId,
                                  context,
                                ),
                                tapPosition,
                                context,
                              );
                            }
                          },
                        );
                      },
                      childCount: allChats.length,
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
                  Image.asset('assets/icons8/pluto-sign-in.png'),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 25),
                    child: Text(
                      "Looks like there aren't any subscribed chats",
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
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
