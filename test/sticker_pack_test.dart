import 'package:flutter_test/flutter_test.dart';
import 'package:retroshare/model/sticker_pack.dart';

void main() {
  test('sticker pack metadata round-trips through JSON', () {
    const original = StickerPack(
      id: 'pack_1',
      name: 'Test pack',
      stickers: [
        StickerItem(
          id: 'pack_1:0',
          fileName: 'hello.gif',
          path: '/stickers/hello.gif',
          mimeType: 'image/gif',
          emoji: '👋',
        ),
      ],
    );

    final restored = StickerPack.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.stickers.single.fileName, 'hello.gif');
    expect(restored.stickers.single.emoji, '👋');
    expect(restored.stickers.single.isAnimated, isTrue);
  });
}
