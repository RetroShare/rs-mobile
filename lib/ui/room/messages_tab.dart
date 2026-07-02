import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as emoji_picker;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/common/bottom_bar.dart';
import 'package:retroshare/common/show_dialog.dart';
import 'package:retroshare/common/styles.dart';
import 'package:retroshare/provider/identity.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare/ui/room/message_delegate.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({
    super.key,
    required this.chat,
    this.isRoom = false,
    this.bubbleStyle = BubbleStyle.bubble,
  });
  final Chat chat;
  final bool? isRoom;
  final BubbleStyle bubbleStyle;

  @override
  MessagesTabState createState() => MessagesTabState();
}

class MessagesTabState extends State<MessagesTab> {
  final TextEditingController msgController = TextEditingController();
  final double _bottomBarHeight = appBarHeight;
  late final FocusNode _focusNode;

  bool _showEmojiPicker = false;
  final ImagePicker _picker = ImagePicker();
  File? _attachedImageFile;
  String? _attachedImageBase64;
  String? _attachedImageMimeType;

  File? _attachedFile;
  String? _attachedFileName;
  int? _attachedFileSize;
  String? _attachedFileHash;
  bool _isHashingFile = false;
  Timer? _hashingTimer;

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
    _hashingTimer?.cancel();
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
    final chatId = widget.chat.chatId;

    if (chatId == null) {
      debugPrint('Error: Chat ID is null.');
      return;
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final bytes = imageBytes.lengthInBytes;
      final kb = bytes / 1024;
      final mb = kb / 1024;

      if (mb < 3) {
        final String base64Image = base64.encode(imageBytes);
        final String extension = imageXFile.path.split('.').last.toLowerCase();
        final String mimeType =
            (extension == 'png') ? 'image/png' : 'image/jpeg';
        final String htmlText =
            "<img alt='Image' src='data:$mimeType;base64,$base64Image'/>";

        if (!mounted) return;
        await Provider.of<RoomChatLobby>(context, listen: false).sendMessage(
          chatId,
          htmlText,
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


  Future<void> _attachImage() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAttachmentPickerSheet(),
    );
  }

  Future<void> _pickFromCamera() async {
    final imageXFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (imageXFile != null) {
      await _processPickedImage(imageXFile);
    }
  }

  Future<void> _pickFromGallery() async {
    final imageXFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (imageXFile != null) {
      await _processPickedImage(imageXFile);
    }
  }

  Future<void> _processPickedImage(XFile imageXFile) async {
    final imageFile = File(imageXFile.path);
    final chatId = widget.chat.chatId;

    if (chatId == null) {
      debugPrint('Error: Chat ID is null.');
      return;
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final bytes = imageBytes.lengthInBytes;
      final kb = bytes / 1024;
      final mb = kb / 1024;

      if (mb < 3) {
        final base64Image = base64.encode(imageBytes);
        final extension = imageXFile.path.split('.').last.toLowerCase();
        final mimeType =
            (extension == 'png') ? 'image/png' : 'image/jpeg';

        setState(() {
          _attachedImageFile = imageFile;
          _attachedImageBase64 = base64Image;
          _attachedImageMimeType = mimeType;
        });
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
      debugPrint('Error attaching image: $e');
      if (!mounted) return;
      await errorShowDialog(
        'Error Attaching Image',
        'Could not attach the image: $e',
        context,
      );
    }
  }

  Widget _buildAttachmentPickerSheet() {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Select Attachment',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPickerOption(
                    icon: Icons.camera_alt_rounded,
                    color: Colors.teal,
                    label: 'Camera',
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickFromCamera();
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.photo_library_rounded,
                    color: Colors.blue,
                    label: 'Gallery',
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickFromGallery();
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.insert_drive_file_rounded,
                    color: Colors.orange,
                    label: 'File',
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickFile();
                    },
                  ),
                  _buildPickerOption(
                    icon: Icons.videocam_rounded,
                    color: Colors.red,
                    label: 'Video',
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Video sharing is coming soon!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.single.path == null) {
        debugPrint('File selection cancelled.');
        return;
      }

      final rawPath = result.files.single.path!;
      final normalizedPath = rawPath.replaceAll(r'\', '/');
      final name = result.files.single.name;
      final size = result.files.single.size;

      setState(() {
        _attachedFile = File(rawPath);
        _attachedFileName = name;
        _attachedFileSize = size;
        _attachedFileHash = null;
        _isHashingFile = true;
      });

      final lobbyProvider = Provider.of<RoomChatLobby>(context, listen: false);
      final authToken = lobbyProvider.authToken;

      // Auto-resume hashing process if paused
      try {
        final pausedResp = await rsApiCall(
          '/rsFiles/hashingProcessPaused',
          authToken: authToken,
        );
        if (pausedResp['retval'] == true) {
          debugPrint('DEBUG: RetroShare hashing process is paused. Resuming it...');
          await rsApiCall(
            '/rsFiles/togglePauseHashingProcess',
            authToken: authToken,
          );
        }
      } catch (e) {
        debugPrint('Error checking/resuming hashing process: $e');
      }

      final response = await rsApiCall(
        '/rsFiles/ExtraFileHash',
        authToken: authToken,
        params: {
          'localpath': normalizedPath,
          'period': {'xstr64': (31536000 * 10).toString()},
          'flags': 0x40,
        },
      );
      final retval = response['retval'];
      final success = (retval is bool && retval) || (retval is int && retval == 1);
      
      if (!success) {
        throw Exception('Core failed to start hashing.');
      }

      _hashingTimer?.cancel();
      _hashingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        try {
          final statusResp = await rsApiCall(
            '/rsFiles/ExtraFileStatus',
            authToken: authToken,
            params: {'localpath': normalizedPath},
          );
          
          debugPrint('DEBUG: /rsFiles/ExtraFileStatus response: $statusResp');
          
          final info = statusResp['info'] as Map?;
          final hash = info?['hash'] as String?;
          if (hash != null &&
              hash.isNotEmpty &&
              hash != '0000000000000000000000000000000000000000') {
            var sizeInBytes = size;
            final sizeVal = info?['size'];
            if (sizeVal is int) {
              sizeInBytes = sizeVal;
            } else if (sizeVal is Map) {
              final xstr = sizeVal['xstr64'] as String?;
              if (xstr != null) {
                sizeInBytes = int.tryParse(xstr) ?? size;
              }
            }

            timer.cancel();
            if (mounted) {
              setState(() {
                _attachedFileHash = hash;
                _attachedFileSize = sizeInBytes;
                _isHashingFile = false;
              });
            }
          }
        } catch (e) {
          debugPrint('Error checking file hashing status: $e');
        }
      });
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        setState(() {
          _attachedFile = null;
          _attachedFileName = null;
          _attachedFileSize = null;
          _attachedFileHash = null;
          _isHashingFile = false;
        });
      }
      if (!mounted) return;
      await errorShowDialog(
        'Error Attaching File',
        'Could not attach the file: $e',
        context,
      );
    }
  }

  void _cancelFileAttachment() {
    _hashingTimer?.cancel();
    final hash = _attachedFileHash;
    if (hash != null) {
      final lobbyProvider = Provider.of<RoomChatLobby>(context, listen: false);
      final authToken = lobbyProvider.authToken;
      
      rsApiCall(
        '/rsFiles/extraFileRemove',
        authToken: authToken,
        params: {'hash': hash},
      );
    }
    setState(() {
      _attachedFile = null;
      _attachedFileName = null;
      _attachedFileSize = null;
      _attachedFileHash = null;
      _isHashingFile = false;
    });
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

                final identitiesProvider =
                    Provider.of<Identities>(context, listen: false);
                final ownIdentity = identitiesProvider.currentIdentity;
                final interlocutorIdentity =
                    messagesList.allIdentity[widget.chat.interlocutorId];

                return Stack(
                  children: <Widget>[
                    ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: msgList.length,
                      itemBuilder: (BuildContext context, int index) {
                        final message = msgList[index];
                        final key = UniqueKey();
                        
                        String bubbleTitle = '';
                        final bool isSystem = ((message.chatflags ?? 0) & 0x0008) != 0;

                        if (isSystem) {
                          bubbleTitle = 'Status';
                        } else if (widget.isRoom ?? false) {
                          if (message.incoming ?? false) {
                            bubbleTitle = messagesList.getChatSenderName(message);
                          }
                        } else {
                          // 1:1 Chat nicknames
                          if (message.incoming ?? false) {
                            bubbleTitle = interlocutorIdentity?.name ?? 
                                widget.chat.chatName ?? 
                                'Interlocutor';
                          } else {
                            bubbleTitle = ownIdentity?.name ?? 'Me';
                          }
                        }

                        return MessageDelegate(
                          key: key,
                          data: message,
                          bubbleTitle: bubbleTitle,
                          style: widget.bubbleStyle,
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
          if (_attachedImageFile != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _attachedImageFile!,
                          height: 55,
                          width: 55,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _attachedImageFile = null;
                              _attachedImageBase64 = null;
                              _attachedImageMimeType = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Image attached (will be sent with your message)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_attachedFile != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.insert_drive_file_rounded,
                      color: Colors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _attachedFileName ?? 'Unknown File',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isHashingFile
                              ? 'Hashing file... please wait'
                              : 'Ready to send (${(_attachedFileSize! / 1024).toStringAsFixed(1)} KB)',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isHashingFile
                                ? Colors.orange
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _cancelFileAttachment,
                  ),
                ],
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
                    icon: Icon(
                      (widget.isRoom ?? false)
                          ? Icons.image
                          : Icons.attach_file_rounded,
                    ),
                    tooltip: (widget.isRoom ?? false) ? 'Send image' : 'Attach file',
                    onPressed: (widget.isRoom ?? false) ? _sendImage : _attachImage,
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
    final hasText = msgController.text.isNotEmpty;
    final hasImage = _attachedImageBase64 != null;
    final hasFile = _attachedFileHash != null;

    if ((hasText || hasImage || hasFile) && widget.chat.chatId != null) {
      if (_isHashingFile) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait until the file is hashed!'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        var finalMessage = msgController.text;

        if (hasFile) {
          final fileHash = _attachedFileHash;
          final fileSize = _attachedFileSize;
          final fileName = _attachedFileName;

          if (fileHash != null && fileSize != null && fileName != null) {
            final encodedName = Uri.encodeComponent(fileName);
            final fileLink = 'retroshare://file?name=$encodedName&size=$fileSize&hash=$fileHash';
            final friendlySize = _friendlyUnit(fileSize);
            final fileHtml = '<a href="$fileLink">$fileName</a> <font color="blue">($friendlySize)</font>';
            finalMessage = fileHtml + (finalMessage.isNotEmpty ? '<br/>$finalMessage' : '');
          }
        }

        if (hasImage) {
          final htmlImage = "<img alt='Image' src='data:$_attachedImageMimeType;base64,$_attachedImageBase64'/>";
          finalMessage = htmlImage + (finalMessage.isNotEmpty ? '<br/>$finalMessage' : '');
        }

        await Provider.of<RoomChatLobby>(context, listen: false).sendMessage(
          widget.chat.chatId!,
          finalMessage,
          isRoomChat ? ChatIdType.type3 : ChatIdType.type2,
        );
        msgController.clear();
        setState(() {
          _attachedImageFile = null;
          _attachedImageBase64 = null;
          _attachedImageMimeType = null;

          _attachedFile = null;
          _attachedFileName = null;
          _attachedFileSize = null;
          _attachedFileHash = null;
          _isHashingFile = false;
        });
      } catch (e) {
        debugPrint('Error sending message: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  String _friendlyUnit(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
