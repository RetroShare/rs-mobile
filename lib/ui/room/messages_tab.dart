import 'dart:convert';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/bottom_bar.dart';
import 'package:retroshare/common/show_dialog.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/ui/room/message_delegate.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key, required this.chat, this.isRoom = false});
  final Chat chat;
  final bool? isRoom;

  @override
  MessagesTabState createState() => MessagesTabState();
}

class MessagesTabState extends State<MessagesTab> {
  final TextEditingController msgController = TextEditingController();
  final double _bottomBarHeight = appBarHeight;
  late final FocusNode _focusNode;

  bool _showEmojiPicker = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _showEmojiPicker = false;
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        if (mounted) {
          setState(() {
            _showEmojiPicker = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    msgController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onEmojiSelected(emoji_picker.Emoji emoji) {
    msgController
      ..text += emoji.emoji
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: msgController.text.length),
      );
  }

  void _onBackspacePressed() {
    msgController
      ..text = msgController.text.characters.skipLast(1).toString()
      ..selection = TextSelection.fromPosition(
        TextPosition(offset: msgController.text.length),
      );
  }

  Future<void> _sendImage() async {
    final imageXFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
      maxWidth: 250,
      maxHeight: 250,
    );

    if (imageXFile == null) {
      debugPrint('Image selection cancelled.');
      return;
    }

    final imageFile = File(imageXFile.path);

    try {
      final imageBytes = await imageFile.readAsBytes();
      final bytes = imageBytes.lengthInBytes;
      final kb = bytes / 1024;
      final mb = kb / 1024;

      if (mb < 3) {
        var text = base64.encode(imageBytes);
        text = "<img alt='Image' src='data:image/png;base64,$text'/>";

        if (!mounted) return;
        await Provider.of<RoomChatLobby>(context, listen: false).sendMessage(
          widget.chat.chatId!,
          text,
          (widget.isRoom ?? false) ? ChatIdType.type3 : ChatIdType.type2,
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image Size is too large!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending image: $e');
      if (!mounted) return;
      await errorShowDialog(
        'Error Sending Image',
        'Could not send the image: $e',
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        if (_showEmojiPicker) {
          setState(() {
            _showEmojiPicker = false;
          });
          return Future.value(false);
        }
        return Future.value(true);
      },
      child: Column(
        children: <Widget>[
          Expanded(
            child: Consumer<RoomChatLobby>(
              builder: (context, messagesList, _) {
                final msgList = (widget.chat.chatId == null ||
                        messagesList.messagesList[widget.chat.chatId] == null)
                    ? <ChatMessage>[]
                    : messagesList.messagesList[widget.chat.chatId]!.reversed
                        .toList();

                return Stack(
                  children: <Widget>[
                    ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: msgList.length,
                      itemBuilder: (BuildContext context, int index) {
                        final message = msgList[index];
                        final key = UniqueKey();
                        return MessageDelegate(
                          key: key,
                          data: message,
                          bubbleTitle: (widget.isRoom ?? false) &&
                                  (message.incoming ?? false)
                              ? (messagesList.getChatSenderName(message))
                              : '',
                        );
                      },
                    ),
                    Visibility(
                      visible: msgList.isEmpty,
                      child: Center(
                        child: SingleChildScrollView(
                          child: SizedBox(
                            width: 250,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Image.asset(
                                  'assets/icons8/pluto-no-messages-1.png',
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 25),
                                  child: Text(
                                    'It seems like there are no messages',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          BottomBar(
            minHeight: _bottomBarHeight,
            maxHeight: _bottomBarHeight * 2.5,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(
                      _showEmojiPicker ? Icons.keyboard : Icons.insert_emoticon,
                    ),
                    tooltip: _showEmojiPicker
                        ? 'Show keyboard'
                        : 'Show emoji picker',
                    onPressed: () {
                      if (!_showEmojiPicker) {
                        _focusNode.unfocus();
                      }
                      if (mounted) {
                        setState(() {
                          _showEmojiPicker = !_showEmojiPicker;
                        });
                      }
                      if (!_showEmojiPicker) {}
                    },
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: TextField(
                        onTap: () {
                          if (_showEmojiPicker) {
                            if (mounted) {
                              setState(() {
                                _showEmojiPicker = false;
                              });
                            }
                          }
                          _focusNode.requestFocus();
                        },
                        controller: msgController,
                        keyboardType: TextInputType.multiline,
                        maxLines: null,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Type text...',
                          hintStyle:
                              TextStyle(color: Theme.of(context).hintColor),
                        ),
                        style: Theme.of(context).textTheme.bodyLarge,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.image),
                    tooltip: 'Send image',
                    onPressed: _sendImage,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    tooltip: 'Send message',
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
          Offstage(
            offstage: !_showEmojiPicker,
            child: SizedBox(
              height: 250,
              child: emoji_picker.EmojiPicker(
                onEmojiSelected: (category, emoji) => _onEmojiSelected(emoji),
                onBackspacePressed: _onBackspacePressed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final isRoomChat = widget.isRoom ?? false;
    if (msgController.text.isNotEmpty && widget.chat.chatId != null) {
      try {
        await Provider.of<RoomChatLobby>(context, listen: false).sendMessage(
          widget.chat.chatId!,
          msgController.text,
          isRoomChat ? ChatIdType.type3 : ChatIdType.type2,
        );
        msgController.clear();
      } catch (e) {
        debugPrint('Error sending message: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }
}
