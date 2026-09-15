# RS Mobile sticker packs

RS Mobile imports local sticker packs from ZIP files. A pack may contain up to
200 `.png`, `.webp`, or `.gif` files. Each sticker must be no larger than 1 MB,
and the complete pack must be no larger than 50 MB when compressed or extracted.

An optional `pack.json` file can provide a display name and emoji metadata:

```json
{
  "name": "My stickers",
  "emoji": {
    "hello.webp": "👋",
    "laugh.gif": "😂"
  }
}
```

Folders inside the ZIP are allowed. Sticker filenames in the `emoji` map must
match their filenames, without the folder path. Animated GIF files play in the
picker and in chat. TGS and WebM stickers are intentionally not supported.

In a chat, open the sticker picker, select the add button, and choose the ZIP.
Tap a sticker to send it. Long-press a sticker to add or remove it from
Favorites.
