class StickerItem {
  const StickerItem({
    required this.id,
    required this.fileName,
    required this.path,
    required this.mimeType,
    this.emoji = '',
  });

  factory StickerItem.fromJson(Map<String, dynamic> json) => StickerItem(
        id: json['id'] as String,
        fileName: json['fileName'] as String,
        path: json['path'] as String,
        mimeType: json['mimeType'] as String,
        emoji: json['emoji'] as String? ?? '',
      );

  final String id;
  final String fileName;
  final String path;
  final String mimeType;
  final String emoji;

  bool get isAnimated => mimeType == 'image/gif';

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'path': path,
        'mimeType': mimeType,
        'emoji': emoji,
      };

}

class StickerPack {
  const StickerPack({
    required this.id,
    required this.name,
    required this.stickers,
  });

  factory StickerPack.fromJson(Map<String, dynamic> json) => StickerPack(
        id: json['id'] as String,
        name: json['name'] as String,
        stickers: (json['stickers'] as List<dynamic>)
            .map((item) => StickerItem.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String name;
  final List<StickerItem> stickers;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'stickers': stickers.map((sticker) => sticker.toJson()).toList(),
      };

}
