import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class MessageDelegate extends StatelessWidget {
  const MessageDelegate({
    super.key,
    required this.data,
    required this.bubbleTitle,
  });

  final String bubbleTitle;
  final ChatMessage data;

  @override
  Widget build(BuildContext context) {
    final timeStampMillis = (data.recvTime ?? data.sendTime ?? 0) * 1000;
    final messageTime = DateTime.fromMillisecondsSinceEpoch(timeStampMillis);
    final formattedTime =
        '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';

    final messageContent = data.msg ?? '';

    final isIncoming = data.incoming ?? true;

    return FractionallySizedBox(
      alignment: isIncoming ? Alignment.centerLeft : Alignment.centerRight,
      widthFactor: 0.7,
      child: Card(
        color: !isIncoming
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.secondaryContainer,
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
                    color: !isIncoming
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                    fontSize: 12,
                  ),
                ),
              ),
            Stack(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 45,
                    bottom: 8,
                    top: bubbleTitle.isNotEmpty ? 4 : 10,
                  ),
                  child: Html(
                    data: messageContent,
                    style: {
                      'body': Style(
                        margin: Margins.zero,
                        padding: HtmlPaddings.zero,
                        fontSize: FontSize(
                          Theme.of(context).textTheme.bodyMedium?.fontSize ??
                              14,
                        ),
                        color: !isIncoming
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                      ),
                      'img': Style(
                        width: Width.auto(),
                        height: Height(150),
                      ),
                    },
                  ),
                ),
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
}
