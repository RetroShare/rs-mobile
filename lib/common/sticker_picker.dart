import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:retroshare/common/sticker_pack_store.dart';
import 'package:retroshare/model/sticker_pack.dart';

class StickerPicker extends StatefulWidget {
  const StickerPicker({super.key, required this.onStickerSelected});

  final Future<void> Function(StickerItem sticker) onStickerSelected;

  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker> {
  final StickerPackStore _store = StickerPackStore();
  List<StickerPack> _packs = [];
  Set<String> _favorites = {};
  List<String> _recents = [];
  String? _selectedPackId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final results = await Future.wait<dynamic>([
      _store.loadPacks(),
      _store.loadFavorites(),
      _store.loadRecents(),
    ]);
    if (!mounted) return;
    setState(() {
      _packs = results[0] as List<StickerPack>;
      _favorites = results[1] as Set<String>;
      _recents = results[2] as List<String>;
      if (_selectedPackId != 'favorites' && _selectedPackId != 'recents' &&
          !_packs.any((pack) => pack.id == _selectedPackId)) {
        _selectedPackId = _packs.isEmpty ? null : _packs.first.id;
      }
      _loading = false;
    });
  }

  Future<void> _importPack() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    if (mounted) setState(() => _loading = true);
    try {
      final pack = await _store.importZip(path);
      _selectedPackId = pack.id;
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${pack.name} (${pack.stickers.length} stickers)')),
      );
    } catch (error) {
      if (mounted) setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not import sticker pack: $error')),
      );
    }
  }

  List<StickerItem> get _allStickers => _packs.expand((pack) => pack.stickers).toList();

  List<StickerItem> get _visibleStickers {
    final all = _allStickers;
    if (_selectedPackId == 'favorites') {
      return all.where((sticker) => _favorites.contains(sticker.id)).toList();
    }
    if (_selectedPackId == 'recents') {
      final byId = {for (final sticker in all) sticker.id: sticker};
      return _recents.map((id) => byId[id]).whereType<StickerItem>().toList();
    }
    return _packs
        .where((pack) => pack.id == _selectedPackId)
        .expand((pack) => pack.stickers)
        .toList();
  }

  Future<void> _select(StickerItem sticker) async {
    await _store.markRecent(sticker.id);
    await widget.onStickerSelected(sticker);
    if (mounted) await _reload();
  }

  Future<void> _toggleFavorite(StickerItem sticker) async {
    await _store.toggleFavorite(sticker.id);
    await _reload();
  }

  Future<void> _removeSelectedPack() async {
    final pack = _packs.where((item) => item.id == _selectedPackId).firstOrNull;
    if (pack == null) return;
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove sticker pack?'),
        content: Text('Remove “${pack.name}” from this device?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (remove == true) {
      await _store.removePack(pack);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final stickers = _visibleStickers;
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              IconButton(onPressed: _importPack, tooltip: 'Import ZIP sticker pack', icon: const Icon(Icons.add_box_outlined)),
              IconButton(
                onPressed: () => setState(() => _selectedPackId = 'recents'),
                tooltip: 'Recently used',
                icon: Icon(Icons.schedule, color: _selectedPackId == 'recents' ? Theme.of(context).colorScheme.primary : null),
              ),
              IconButton(
                onPressed: () => setState(() => _selectedPackId = 'favorites'),
                tooltip: 'Favorites',
                icon: Icon(Icons.favorite_outline, color: _selectedPackId == 'favorites' ? Theme.of(context).colorScheme.primary : null),
              ),
              for (final pack in _packs)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: ChoiceChip(
                    selected: _selectedPackId == pack.id,
                    onSelected: (_) => setState(() => _selectedPackId = pack.id),
                    label: Text(pack.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              if (_packs.any((pack) => pack.id == _selectedPackId))
                IconButton(onPressed: _removeSelectedPack, tooltip: 'Remove pack', icon: const Icon(Icons.delete_outline)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: stickers.isEmpty
              ? Center(
                  child: Text(
                    _packs.isEmpty
                        ? 'Import a ZIP containing PNG, WebP, or GIF stickers.'
                        : 'No stickers here yet.',
                    textAlign: TextAlign.center,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: stickers.length,
                  itemBuilder: (context, index) {
                    final sticker = stickers[index];
                    return Semantics(
                      label: sticker.emoji.isEmpty ? sticker.fileName : '${sticker.emoji} ${sticker.fileName}',
                      button: true,
                      child: InkWell(
                        onTap: () => _select(sticker),
                        onLongPress: () => _toggleFavorite(sticker),
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(3),
                              child: Image.file(
                                File(sticker.path),
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                              ),
                            ),
                            if (_favorites.contains(sticker.id))
                              const Positioned(right: 0, top: 0, child: Icon(Icons.favorite, size: 14, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
