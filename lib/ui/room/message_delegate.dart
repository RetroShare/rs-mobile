import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:retroshare/ui/room/voice_message_widget.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

enum BubbleStyle { bubble, compact }

class MessageDelegate extends StatelessWidget {
  const MessageDelegate({
    super.key,
    required this.data,
    required this.bubbleTitle,
    this.style = BubbleStyle.bubble,
  });

  final String bubbleTitle;
  final ChatMessage data;
  final BubbleStyle style;

  @override
  Widget build(BuildContext context) {
    final timeStampMillis = (data.recvTime ?? data.sendTime ?? 0) * 1000;
    final messageTime = DateTime.fromMillisecondsSinceEpoch(timeStampMillis);
    final formattedTime =
        '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';

    final messageContent = data.msg ?? '';

    final isIncoming = data.incoming ?? true;
    final isLobby = data.isLobbyMessage();

    // RetroShare Chat Flags
    const int rsChatFlagsHistory = 0x0004;
    const int rsChatFlagsSystem = 0x0008;

    final bool isHistory = ((data.chatflags ?? 0) & rsChatFlagsHistory) != 0;
    final bool isSystem = ((data.chatflags ?? 0) & rsChatFlagsSystem) != 0;
    final bool isOffline = data.online == false;

    // Determine colors based on flags and state
    Color bubbleColor;
    Color borderColor;

    if (isHistory) {
      bubbleColor = const Color(0xFFE5E5E5);
      borderColor = const Color(0xFFB0B0B0);
    } else if (isSystem) {
      bubbleColor = const Color(0xFFFFD43D);
      borderColor = const Color(0xFFC9A200);
    } else if (isIncoming) {
      bubbleColor = const Color(0xFF8EDFFF);
      borderColor = const Color(0xFF29ABE2);
    } else if (isOffline) {
      bubbleColor = const Color(0xFFFF8E8E);
      borderColor = const Color(0xFFD43D3D);
    } else {
      // Regular outgoing
      bubbleColor = const Color(0xFF8EFF3D);
      borderColor = const Color(0xFF00B000);
    }

    if (isLobby) {
      // Keep standard Material design for group rooms
      return FractionallySizedBox(
        alignment: isSystem ? Alignment.centerRight : (isIncoming ? Alignment.centerLeft : Alignment.centerRight),
        widthFactor: 0.7,
        child: Card(
          color: isSystem 
              ? bubbleColor 
              : (!isIncoming
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.secondaryContainer),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (bubbleTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8, right: 8),
                  child: Text(
                    bubbleTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSystem
                          ? Colors.black87
                          : (!isIncoming
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSecondaryContainer),
                      fontSize: 12,
                    ),
                  ),
                ),
              Stack(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: isSystem ? 12 : 45,
                      bottom: 8,
                      top: bubbleTitle.isNotEmpty ? 4 : 10,
                    ),
                    child:
                        _buildHtmlContent(context, messageContent, isIncoming, textColor: isSystem ? Colors.black : null),
                  ),
                  if (!isSystem)
                    Positioned(
                      right: 8,
                      bottom: 4,
                      child: Text(
                        formattedTime,
                        style: TextStyle(
                          color: !isIncoming
                              ? Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(0.6)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer
                                  .withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Custom RetroShare Bubble Look
    if (style == BubbleStyle.bubble) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          mainAxisAlignment: (isIncoming || isSystem) ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isIncoming && !isSystem) ...[
              _buildLabel(context, bubbleTitle, formattedTime, isIncoming,
                  isCompact: false),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: CustomPaint(
                painter: BubblePainter(
                    color: bubbleColor,
                    borderColor: borderColor,
                    isIncoming: isIncoming,
                    isSystem: isSystem),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: _buildHtmlContent(context, messageContent, true,
                      textColor: Colors.black),
                ),
              ),
            ),
            if ((isIncoming || isSystem) && !(!isIncoming && !isSystem)) ...[
              const SizedBox(width: 4),
              if (isSystem)
                _buildSystemLabel(context, bubbleTitle, formattedTime)
              else
                _buildLabel(context, bubbleTitle, formattedTime, isIncoming,
                    isCompact: false),
            ],
          ],
        ),
      );
    } else {
      // Compact Style (Labels above/below)
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Column(
          crossAxisAlignment: (isIncoming || isSystem)
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (isIncoming || isSystem)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, right: 8),
                child: Text(
                  isSystem ? '$bubbleTitle - $formattedTime' : '$formattedTime - $bubbleTitle',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: isSystem
                  ? MainAxisAlignment.center
                  : (isIncoming ? MainAxisAlignment.end : MainAxisAlignment.start),
              children: [
                Flexible(
                  child: CustomPaint(
                    painter: BubblePainter(
                        color: bubbleColor,
                        borderColor: borderColor,
                        isIncoming: isIncoming,
                        isSystem: isSystem),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: _buildHtmlContent(context, messageContent, true,
                          textColor: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            if (!isIncoming && !isSystem)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Text(
                  '$bubbleTitle - $formattedTime',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ),
              ),
          ],
        ),
      );
    }
  }

  Widget _buildSystemLabel(BuildContext context, String title, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(
      BuildContext context, String title, String time, bool isIncoming,
      {bool isCompact = false}) {
    return Column(
      crossAxisAlignment:
          isIncoming ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildHtmlContent(BuildContext context, String content, bool isIncoming, {Color? textColor}) {
    var processedContent = content;
    final fileFontRegex = RegExp(
      r'(<a[^>]*href=[^>]*retroshare://file[^>]*>.*?</a>)[^<]*(<(font|span)[^>]*>)?\(\s*\d+([.,]\d+)?\s*(B|KB|MB|GB|TB)\s*\)(</(font|span)>)?',
      caseSensitive: false,
    );
    processedContent = processedContent.replaceAllMapped(fileFontRegex, (match) {
      return match.group(1) ?? '';
    });

    // Ensure all retroshare file links have the class for block layout styling
    final fileLinkRegex = RegExp(r'<a([^>]*href=[^>]*retroshare://file[^>]*)>', caseSensitive: false);
    processedContent = processedContent.replaceAllMapped(fileLinkRegex, (match) {
      final attrs = match.group(1) ?? '';
      final isVoice = attrs.contains('voice_msg_') || attrs.contains('.m4a');
      final className = isVoice ? 'rs-voice-link rs-file-link' : 'rs-file-link';
      if (!attrs.contains('class=')) {
        return '<a class="$className"$attrs>';
      }
      return match.group(0) ?? '';
    });

    return Html(
      data: processedContent,
      shrinkWrap: true,
      extensions: [
        TagExtension(
          tagsToExtend: {'img'},
          builder: (extensionContext) {
            final src = extensionContext.attributes['src'];
            if (src != null && src.contains('base64,')) {
              try {
                final base64Data = src.split('base64,').last;
                final decodedBytes = base64Decode(base64Data.trim());
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullScreenPictureViewer(
                          imageBytes: decodedBytes,
                        ),
                      ),
                    );
                  },
                  child: Image.memory(
                    decodedBytes,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error building image: $error');
                      return const Icon(Icons.broken_image);
                    },
                  ),
                );
              } catch (e) {
                debugPrint('Error decoding base64 image: $e');
              }
            }
            return const SizedBox.shrink();
          },
        ),
        TagExtension(
          tagsToExtend: {'a'},
          builder: (extensionContext) {
            final href = extensionContext.attributes['href'];
            if (href != null && href.contains('retroshare://file')) {
              var name = 'Unknown file';
              var size = 0;
              var hash = '';
              List<int>? waveform;

              if (href.startsWith('retroshare://file?')) {
                try {
                  final uri = Uri.parse(href);
                  name = Uri.decodeComponent(uri.queryParameters['name'] ?? 'Unknown file');
                  size = int.tryParse(uri.queryParameters['size'] ?? '0') ?? 0;
                  hash = uri.queryParameters['hash'] ?? '';
                  final waveformStr = uri.queryParameters['waveform'];
                  if (waveformStr != null && waveformStr.isNotEmpty) {
                    waveform = waveformStr.split(',').map((s) => int.tryParse(s) ?? 0).toList();
                  }
                } catch (e) {
                  debugPrint('Error parsing retroshare link Uri: $e');
                }
              } else if (href.contains('|')) {
                final parts = href.split('|');
                if (parts.length >= 4) {
                  name = parts[1];
                  size = int.tryParse(parts[2]) ?? 0;
                  hash = parts[3];
                }
              }

              if (hash.isNotEmpty) {
                final isVoice = name.startsWith('voice_msg_') || name.endsWith('.m4a');
                if (isVoice) {
                  return VoiceMessageWidget(
                    name: name,
                    size: size,
                    hash: hash,
                    isIncoming: isIncoming,
                    waveform: waveform,
                  );
                }
                return FileAttachmentWidget(
                  name: name,
                  size: size,
                  hash: hash,
                  isIncoming: isIncoming,
                );
              }
            }
            final text = extensionContext.element?.text ?? href ?? '';
            return Text(
              text,
              style: TextStyle(
                color: textColor ?? (!isIncoming
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSecondaryContainer),
                decoration: TextDecoration.underline,
              ),
            );
          },
        ),
      ],
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          fontSize: FontSize(
            Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14,
          ),
          color: textColor ?? (!isIncoming
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSecondaryContainer),
        ),
        '.rs-file-link': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          display: Display.block,
        ),
        '.rs-voice-link': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          display: Display.block,
        ),
        'img': Style(
          width: Width(100, Unit.percent),
          height: Height.auto(),
        ),
      },
    );
  }
}

class BubblePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final bool isIncoming;
  final bool isSystem;

  BubblePainter(
      {required this.color,
      required this.borderColor,
      required this.isIncoming,
      this.isSystem = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    const radius = 12.0;
    const beakWidth = 8.0;

    if (isSystem) {
      // Centered rounded rectangle without beak for system messages
      path.addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          const Radius.circular(radius)));
    } else if (isIncoming) {
      // Beak on the right
      path.moveTo(radius, 0);
      path.lineTo(size.width - radius - beakWidth, 0);
      path.quadraticBezierTo(size.width - beakWidth, 0, size.width - beakWidth, radius);
      
      // Right side with beak
      path.lineTo(size.width - beakWidth, 10);
      path.lineTo(size.width, 15);
      path.lineTo(size.width - beakWidth, 20);
      
      path.lineTo(size.width - beakWidth, size.height - radius);
      path.quadraticBezierTo(size.width - beakWidth, size.height, size.width - radius - beakWidth, size.height);
      path.lineTo(radius, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - radius);
      path.lineTo(0, radius);
      path.quadraticBezierTo(0, 0, radius, 0);
    } else {
      // Beak on the left
      path.moveTo(radius + beakWidth, 0);
      path.lineTo(size.width - radius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, radius);
      path.lineTo(size.width, size.height - radius);
      path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);
      path.lineTo(radius + beakWidth, size.height);
      path.quadraticBezierTo(beakWidth, size.height, beakWidth, size.height - radius);
      
      // Left side with beak
      path.lineTo(beakWidth, 20);
      path.lineTo(0, 15);
      path.lineTo(beakWidth, 10);
      
      path.lineTo(beakWidth, radius);
      path.quadraticBezierTo(beakWidth, 0, radius + beakWidth, 0);
    }

    path.close();

    // Draw shadow-like gradient or fill
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FullScreenPictureViewer extends StatelessWidget {
  const FullScreenPictureViewer({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FileAttachmentWidget extends StatefulWidget {
  const FileAttachmentWidget({
    super.key,
    required this.name,
    required this.size,
    required this.hash,
    required this.isIncoming,
  });

  final String name;
  final int size;
  final String hash;
  final bool isIncoming;

  @override
  State<FileAttachmentWidget> createState() => _FileAttachmentWidgetState();
}

class _FileAttachmentWidgetState extends State<FileAttachmentWidget> {
  Timer? _statusTimer;
  bool _isChecking = true;
  bool _isDownloading = false;
  bool _isCompleted = false;
  double _progress = 0;
  String _statusText = '';
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    try {
      final lobbyProvider = Provider.of<RoomChatLobby>(context, listen: false);
      final authToken = lobbyProvider.authToken;

      final detailsResp = await rsApiCall(
        '/rsFiles/FileDetails',
        authToken: authToken,
        params: {
          'hash': widget.hash,
          'hintflags': 62,
        },
      );

      final retval = detailsResp['retval'];
      final hasDetails = (retval is bool && retval) || (retval is int && retval == 1);

      if (hasDetails && detailsResp['info'] != null) {
        final info = detailsResp['info'] as Map;
        final downloadStatus = info['downloadStatus'] as int? ?? 0;
        final dirPath = info['path'] as String? ?? '';
        final fname = info['fname'] as String? ?? widget.name;

        // Construct correct full path if it doesn't already end with the filename
        var fullPath = dirPath;
        if (dirPath.isNotEmpty && !dirPath.endsWith(fname) && !dirPath.endsWith(widget.name)) {
          if (dirPath.endsWith('/') || dirPath.endsWith(r'\')) {
            fullPath = '$dirPath$fname';
          } else {
            final separator = dirPath.contains(r'\') ? r'\' : '/';
            fullPath = '$dirPath$separator$fname';
          }
        }

        final fileExists = fullPath.isNotEmpty && File(fullPath).existsSync();

        if (downloadStatus == 1 || downloadStatus == 4 || (downloadStatus == 0 && fileExists)) {
          final wasCompleted = _isCompleted;
          final wasChecking = _isChecking;

          if (mounted) {
            setState(() {
              _isChecking = false;
              _isDownloading = false;
              _isCompleted = true;
              _localPath = fullPath;
              _statusText = 'Completed';
            });
          }
          _statusTimer?.cancel();
          _statusTimer = null;

          // Auto-save to gallery if this is the first time we detect completion,
          // it's a media file, and we didn't just load it as already completed on start.
          if (!wasCompleted && !wasChecking && _isMediaFile(fname)) {
            unawaited(_saveToGallery());
          }
        } else if (downloadStatus == 3 ||
                   downloadStatus == 5 ||
                   downloadStatus == 2 ||
                   downloadStatus == 7) {
          final transferedVal = info['transfered'];
          var transfered = 0;
          if (transferedVal is int) {
            transfered = transferedVal;
          } else if (transferedVal is Map) {
            final xstr = transferedVal['xstr64'] as String?;
            if (xstr != null) {
              transfered = int.tryParse(xstr) ?? 0;
            }
          }

          final sizeVal = info['size'];
          var totalSize = widget.size;
          if (sizeVal is int) {
            totalSize = sizeVal;
          } else if (sizeVal is Map) {
            final xstr = sizeVal['xstr64'] as String?;
            if (xstr != null) {
              totalSize = int.tryParse(xstr) ?? widget.size;
            }
          }

          var pct = 0.0;
          if (totalSize > 0) {
            pct = transfered / totalSize;
          }

          final speed = info['tfRate'] as double? ?? 0.0;

          if (mounted) {
            setState(() {
              _isChecking = false;
              _isDownloading = true;
              _isCompleted = false;
              _progress = pct;
              _statusText = 'Downloading ${(pct * 100).toStringAsFixed(1)}% (${speed.toStringAsFixed(1)} KB/s)';
            });
          }

          _startTimer();
        } else {
          if (mounted) {
            setState(() {
              _isChecking = false;
              _isDownloading = false;
              _isCompleted = false;
              _statusText = 'Paused/Failed';
            });
          }
          _statusTimer?.cancel();
          _statusTimer = null;
        }
      } else {
        if (mounted) {
          setState(() {
            _isChecking = false;
            _isDownloading = false;
            _isCompleted = false;
            _statusText = '';
          });
        }
        _statusTimer?.cancel();
        _statusTimer = null;
      }
    } catch (e) {
      debugPrint('Error checking file status: $e');
    }
  }

  void _startTimer() {
    if (_statusTimer != null) return;
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkStatus();
    });
  }

  Future<void> _startDownload() async {
    try {
      final lobbyProvider = Provider.of<RoomChatLobby>(context, listen: false);
      final authToken = lobbyProvider.authToken;

      final response = await rsApiCall(
        '/rsFiles/FileRequest',
        authToken: authToken,
        params: {
          'fileName': widget.name,
          'hash': widget.hash,
          'size': {
            'xstr64': widget.size.toString(),
            'xint64': widget.size,
          },
          'destPath': '',
          'flags': 0x00000040,
          'srcIds': [],
        },
      );

      final retval = response['retval'];
      final success = (retval is bool && retval) || (retval is int && retval == 1);

      if (success) {
        setState(() {
          _isDownloading = true;
          _statusText = 'Starting download...';
        });
        unawaited(_checkStatus());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to request file download.')),
        );
      }
    } catch (e) {
      debugPrint('Error starting download: $e');
    }
  }

  Future<void> _cancelDownload() async {
    try {
      final lobbyProvider = Provider.of<RoomChatLobby>(context, listen: false);
      final authToken = lobbyProvider.authToken;

      final response = await rsApiCall(
        '/rsFiles/FileCancel',
        authToken: authToken,
        params: {'hash': widget.hash},
      );

      final retval = response['retval'];
      final success = (retval is bool && retval) || (retval is int && retval == 1);

      if (success) {
        _statusTimer?.cancel();
        _statusTimer = null;
        setState(() {
          _isDownloading = false;
          _statusText = 'Download cancelled';
        });
        unawaited(_checkStatus());
      }
    } catch (e) {
      debugPrint('Error cancelling download: $e');
    }
  }

  Future<void> _openFile() async {
    final path = _localPath;
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local file path is missing.')),
      );
      return;
    }

    try {
      final file = File(path);
      if (!file.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File not found on disk at: $path')),
        );
        return;
      }

      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: ${result.message}')),
        );
      }
    } catch (e) {
      debugPrint('Error opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  bool _isMediaFile(String filename) {
    final nameLower = filename.toLowerCase();
    return nameLower.endsWith('.jpg') ||
        nameLower.endsWith('.jpeg') ||
        nameLower.endsWith('.png') ||
        nameLower.endsWith('.gif') ||
        nameLower.endsWith('.webp') ||
        nameLower.endsWith('.bmp') ||
        nameLower.endsWith('.mp4') ||
        nameLower.endsWith('.mov') ||
        nameLower.endsWith('.mkv') ||
        nameLower.endsWith('.avi');
  }

  Future<void> _saveToGallery() async {
    final path = _localPath;
    if (path == null || path.isEmpty) {
      await Fluttertoast.showToast(msg: 'Local file path is missing.');
      return;
    }

    try {
      final file = File(path);
      if (!file.existsSync()) {
        await Fluttertoast.showToast(msg: 'File not found on disk.');
        return;
      }

      final result = await ImageGallerySaverPlus.saveFile(path);
      if (result != null && (result['isSuccess'] == true || result['isSuccess'] == 'true')) {
        await Fluttertoast.showToast(msg: 'Saved to Gallery successfully!');
      } else {
        await Fluttertoast.showToast(msg: 'Failed to save to Gallery.');
      }
    } catch (e) {
      debugPrint('Error saving to gallery: $e');
      await Fluttertoast.showToast(msg: 'Error saving to gallery: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBgColor = widget.isIncoming
        ? Colors.black.withValues(alpha: 0.05)
        : Colors.white.withValues(alpha: 0.15);

    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(theme),
          const SizedBox(width: 12),
          Flexible(
            child: GestureDetector(
              onTap: _isCompleted ? _openFile : null,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getStatusSubtext(),
                    style: TextStyle(
                      fontSize: 11,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isCompleted) ...[
            if (_isMediaFile(widget.name)) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                color: textColor,
                tooltip: 'Save to Gallery',
                onPressed: _saveToGallery,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    if (_isChecking) {
      return const SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_isCompleted) {
      return GestureDetector(
        onTap: _openFile,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.white,
          child: Icon(
            Icons.insert_drive_file_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
      );
    }

    if (_isDownloading) {
      return GestureDetector(
        onTap: _cancelDownload,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                value: _progress > 0 ? _progress : null,
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            const Icon(
              Icons.close_rounded,
              color: Colors.red,
              size: 18,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _startDownload,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        child: Icon(
          Icons.file_download_rounded,
          color: theme.colorScheme.primary,
          size: 20,
        ),
      ),
    );
  }

  String _getStatusSubtext() {
    final sizeFriendly = _friendlyUnit(widget.size);
    if (_statusText.isNotEmpty) {
      return '$sizeFriendly • $_statusText';
    }
    return sizeFriendly;
  }

  String _friendlyUnit(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
