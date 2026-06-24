import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
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
        alignment: isSystem ? Alignment.center : (isIncoming ? Alignment.centerLeft : Alignment.centerRight),
        widthFactor: isSystem ? 0.9 : 0.7,
        child: Card(
          color: isSystem 
              ? bubbleColor 
              : (!isIncoming
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.secondaryContainer),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment: isSystem ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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
          mainAxisAlignment: isSystem
              ? MainAxisAlignment.center
              : (isIncoming ? MainAxisAlignment.end : MainAxisAlignment.start),
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
          crossAxisAlignment: isSystem
              ? CrossAxisAlignment.center
              : (isIncoming ? CrossAxisAlignment.end : CrossAxisAlignment.start),
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
    return Html(
      data: content,
      shrinkWrap: true,
      extensions: [
        TagExtension(
          tagsToExtend: {"img"},
          builder: (extensionContext) {
            final src = extensionContext.attributes['src'];
            if (src != null && src.contains('base64,')) {
              try {
                final base64Data = src.split('base64,').last;
                return Image.memory(
                  base64Decode(base64Data.trim()),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Error building image: $error');
                    return const Icon(Icons.broken_image);
                  },
                );
              } catch (e) {
                debugPrint('Error decoding base64 image: $e');
              }
            }
            return const SizedBox.shrink();
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

