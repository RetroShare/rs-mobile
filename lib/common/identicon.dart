import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class Identicon extends StatelessWidget {
  final String id;
  final double size;
  final double borderRadius;

  const Identicon({
    super.key,
    required this.id,
    this.size = 100,
    this.borderRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Generate a simple byte array from the ID string if it's not hex, 
    // or parse hex if it is. RetroShare IDs are hex.
    Uint8List hash;
    try {
      // Try to treat as hex (RetroShare GXS ID)
      if (id.length >= 10 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(id)) {
        final List<int> bytes = [];
        for (var i = 0; i < id.length; i += 2) {
          bytes.add(int.parse(id.substring(i, i + 2), radix: 16));
        }
        hash = Uint8List.fromList(bytes);
      } else {
        // Fallback for non-hex IDs
        hash = Uint8List.fromList(utf8.encode(id));
      }
    } catch (e) {
      hash = Uint8List.fromList(utf8.encode(id));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CustomPaint(
        size: Size(size, size),
        painter: IdenticonPainter(hash: hash),
      ),
    );
  }
}

class IdenticonPainter extends CustomPainter {
  final Uint8List hash;

  IdenticonPainter({required this.hash});

  @override
  void paint(Canvas canvas, Size size) {
    if (hash.isEmpty) return;

    final width = 5;
    final height = 5;
    final cellSize = size.width / width;

    // Use different parts of the hash for color and pattern
    // Foreground color from first 3 bytes (or repeated if short)
    final r = hash[0 % hash.length];
    final g = hash[1 % hash.length];
    final b = hash[2 % hash.length];
    
    final color = Color.fromARGB(255, r, g, b);

    final bgPaint = Paint()..color = const Color(0xFFF0F0F0);
    final fgPaint = Paint()..color = color;

    // Draw background
    canvas.drawRect(Offset.zero & size, bgPaint);

    for (var x = 0; x < width; x++) {
      // Enforce horizontal symmetry (Columns 0=4, 1=3, 2=Unique)
      final i = x < 3 ? x : 4 - x;
      
      // Use bits from the hash byte corresponding to this column to determine row pixels
      // We skip the first 3 bytes used for color if possible
      final patternByte = hash[(i + 3) % hash.length];

      for (var y = 0; y < height; y++) {
        if ((patternByte >> y & 1) == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * cellSize,
              y * cellSize,
              cellSize + 0.1, // Minor overlap to prevent subpixel gaps
              cellSize + 0.1,
            ),
            fgPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant IdenticonPainter oldDelegate) {
    return oldDelegate.hash != hash;
  }
}
