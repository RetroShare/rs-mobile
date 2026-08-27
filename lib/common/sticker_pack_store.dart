import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:retroshare/model/sticker_pack.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StickerImportException implements Exception {
  const StickerImportException(this.message);
  final String message;

  @override
  String toString() => message;
}

class StickerPackStore {
  static const _packsKey = 'sticker_packs_v1';
  static const _favoritesKey = 'sticker_favorites_v1';
  static const _recentsKey = 'sticker_recents_v1';
  static const _supportedExtensions = {'png', 'webp', 'gif'};
  static const _maxStickers = 200;
  static const _maxStickerBytes = 1024 * 1024;
  static const _maxPackBytes = 50 * 1024 * 1024;

  Future<List<StickerPack>> loadPacks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_packsKey);
    if (raw == null) return [];
    try {
      final packs = (jsonDecode(raw) as List<dynamic>)
          .map((item) => StickerPack.fromJson(item as Map<String, dynamic>))
          .toList();
      final existing = <StickerPack>[];
      for (final pack in packs) {
        final stickers = <StickerItem>[];
        for (final sticker in pack.stickers) {
          if (await File(sticker.path).exists()) stickers.add(sticker);
        }
        if (stickers.isNotEmpty) {
          existing.add(StickerPack(id: pack.id, name: pack.name, stickers: stickers));
        }
      }
      return existing;
    } catch (_) {
      return [];
    }
  }

  Future<StickerPack> importZip(String zipPath) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw const StickerImportException('The selected ZIP file no longer exists.');
    }
    final zipBytes = await zipFile.readAsBytes();
    if (zipBytes.length > _maxPackBytes) {
      throw const StickerImportException('Sticker packs must be 50 MB or smaller.');
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes, verify: true);
    } catch (_) {
      throw const StickerImportException('This is not a valid ZIP sticker pack.');
    }

    Map<String, dynamic>? manifest;
    for (final entry in archive.files) {
      if (entry.isFile && _safeBaseName(entry.name).toLowerCase() == 'pack.json') {
        if (entry.size > 64 * 1024) {
          throw const StickerImportException('pack.json must be 64 KB or smaller.');
        }
        try {
          final bytes = entry.readBytes();
          if (bytes == null) {
            throw const StickerImportException('pack.json could not be read.');
          }
          manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        } on StickerImportException {
          rethrow;
        } catch (_) {
          throw const StickerImportException('pack.json is not valid JSON.');
        }
        break;
      }
    }

    final candidates = archive.files.where((entry) {
      if (!entry.isFile) return false;
      final extension = _extension(entry.name);
      return _supportedExtensions.contains(extension);
    }).toList();
    if (candidates.isEmpty) {
      throw const StickerImportException('The ZIP contains no PNG, WebP, or GIF stickers.');
    }
    if (candidates.length > _maxStickers) {
      throw const StickerImportException('A sticker pack can contain at most 200 stickers.');
    }
    if (candidates.any((entry) => entry.size > _maxStickerBytes)) {
      throw const StickerImportException('Every sticker must be 1 MB or smaller.');
    }
    final expandedSize = candidates.fold<int>(0, (total, entry) => total + entry.size);
    if (expandedSize > _maxPackBytes) {
      throw const StickerImportException('The extracted sticker pack must be 50 MB or smaller.');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final packId = 'pack_$timestamp';
    final root = await getApplicationSupportDirectory();
    final packDirectory = Directory('${root.path}${Platform.pathSeparator}stickers${Platform.pathSeparator}$packId');
    await packDirectory.create(recursive: true);

    final emojiMap = manifest?['emoji'] is Map
        ? Map<String, dynamic>.from(manifest!['emoji'] as Map)
        : const <String, dynamic>{};
    final stickers = <StickerItem>[];
    try {
      for (var index = 0; index < candidates.length; index++) {
        final entry = candidates[index];
        final bytes = entry.readBytes();
        if (bytes == null) {
          throw StickerImportException('${_safeBaseName(entry.name)} could not be read.');
        }
        if (bytes.length > _maxStickerBytes) {
          throw StickerImportException('${_safeBaseName(entry.name)} is larger than 1 MB.');
        }
        final extension = _extension(entry.name);
        final originalName = _safeBaseName(entry.name);
        final storedName = '${index.toString().padLeft(3, '0')}.$extension';
        final path = '${packDirectory.path}${Platform.pathSeparator}$storedName';
        await File(path).writeAsBytes(bytes, flush: true);
        stickers.add(StickerItem(
          id: '$packId:$index',
          fileName: originalName,
          path: path,
          mimeType: _mimeType(extension),
          emoji: emojiMap[originalName]?.toString() ?? '',
        ));
      }
    } catch (_) {
      if (await packDirectory.exists()) await packDirectory.delete(recursive: true);
      rethrow;
    }

    final fallbackName = _safeBaseName(zipPath).replaceFirst(RegExp(r'\.zip$', caseSensitive: false), '');
    final requestedName = manifest?['name']?.toString().trim();
    final safeRequestedName = requestedName == null
        ? null
        : requestedName.substring(
            0,
            requestedName.length > 60 ? 60 : requestedName.length,
          );
    final pack = StickerPack(
      id: packId,
      name: safeRequestedName?.isNotEmpty == true ? safeRequestedName! : fallbackName,
      stickers: stickers,
    );
    final packs = await loadPacks()..add(pack);
    await _savePacks(packs);
    return pack;
  }

  Future<void> removePack(StickerPack pack) async {
    final packs = await loadPacks()..removeWhere((item) => item.id == pack.id);
    await _savePacks(packs);
    if (pack.stickers.isNotEmpty) {
      final directory = File(pack.stickers.first.path).parent;
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    final removedIds = pack.stickers.map((item) => item.id).toSet();
    await _removeIds(_favoritesKey, removedIds);
    await _removeIds(_recentsKey, removedIds);
  }

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoritesKey) ?? const <String>[]).toSet();
  }

  Future<List<String>> loadRecents() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentsKey) ?? const <String>[];
  }

  Future<void> toggleFavorite(String stickerId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = (prefs.getStringList(_favoritesKey) ?? <String>[]).toSet();
    favorites.contains(stickerId) ? favorites.remove(stickerId) : favorites.add(stickerId);
    await prefs.setStringList(_favoritesKey, favorites.toList());
  }

  Future<void> markRecent(String stickerId) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = prefs.getStringList(_recentsKey) ?? <String>[];
    recents.remove(stickerId);
    recents.insert(0, stickerId);
    if (recents.length > 30) recents.removeRange(30, recents.length);
    await prefs.setStringList(_recentsKey, recents);
  }

  Future<void> _savePacks(List<StickerPack> packs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_packsKey, jsonEncode(packs.map((pack) => pack.toJson()).toList()));
  }

  Future<void> _removeIds(String key, Set<String> removedIds) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(key) ?? <String>[];
    ids.removeWhere(removedIds.contains);
    await prefs.setStringList(key, ids);
  }

  static String _safeBaseName(String path) =>
      path.replaceAll('\\', '/').split('/').where((part) => part.isNotEmpty).lastOrNull ?? 'stickers';

  static String _extension(String path) {
    final name = _safeBaseName(path);
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static String _mimeType(String extension) => switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'application/octet-stream',
      };
}

extension<T> on Iterable<T> {
  T? get lastOrNull => isEmpty ? null : last;
}
