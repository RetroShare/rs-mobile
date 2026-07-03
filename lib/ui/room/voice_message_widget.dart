import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:retroshare/provider/room.dart';
import 'package:retroshare_api_wrapper/retroshare.dart';

class VoiceMessageWidget extends StatefulWidget {
  const VoiceMessageWidget({
    super.key,
    required this.name,
    required this.size,
    required this.hash,
    required this.isIncoming,
    this.waveform,
  });

  final String name;
  final int size;
  final String hash;
  final bool isIncoming;
  final List<int>? waveform;

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  Timer? _statusTimer;
  bool _isChecking = true;
  bool _isDownloading = false;
  bool _isCompleted = false;
  double _progress = 0;
  String _statusText = '';
  String? _localPath;

  // Audio Playback
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  late final List<int> _displayWaveform;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Parse waveform or generate a stable deterministic fallback based on the file hash
    if (widget.waveform != null && widget.waveform!.isNotEmpty) {
      _displayWaveform = widget.waveform!;
    } else {
      final random = Random(widget.hash.hashCode);
      _displayWaveform = List<int>.generate(60, (_) {
        final isQuiet = random.nextDouble() > 0.85;
        if (isQuiet) {
          return random.nextInt(40) + 10;
        }
        return random.nextInt(150) + 40;
      });
    }

    _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });

    unawaited(_checkStatus());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _audioPlayer.dispose();
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

          try {
            await _audioPlayer.setSource(DeviceFileSource(fullPath));
          } catch (e) {
            debugPrint('Error pre-loading audio source: $e');
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
          // If paused or failed, auto-trigger download request
          if (mounted) {
            setState(() {
              _isChecking = false;
              _isDownloading = false;
              _isCompleted = false;
              _statusText = 'Starting...';
            });
          }
          unawaited(_startDownload());
        }
      } else {
        // Not in transfer list yet, start download request!
        if (mounted) {
          setState(() {
            _isChecking = false;
            _isDownloading = false;
            _isCompleted = false;
            _statusText = 'Starting...';
          });
        }
        unawaited(_startDownload());
      }
    } catch (e) {
      debugPrint('Error checking voice status: $e');
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
        });
        unawaited(_checkStatus());
      }
    } catch (e) {
      debugPrint('Error requesting voice download: $e');
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
      debugPrint('Error cancelling voice download: $e');
    }
  }

  Future<void> _togglePlayback() async {
    final path = _localPath;
    if (path == null || path.isEmpty) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(DeviceFileSource(path));
      }
    } catch (e) {
      debugPrint('Error toggling voice playback: $e');
    }
  }

  Future<void> _seek(Duration pos) async {
    try {
      await _audioPlayer.seek(pos);
    } catch (e) {
      debugPrint('Error seeking voice message: $e');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _getDurationText() {
    if (!_isCompleted) {
      return _statusText;
    }
    if (_isPlaying || (_position > Duration.zero && _position < _duration)) {
      return _formatDuration(_position);
    }
    return _formatDuration(_duration);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = widget.isIncoming
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onPrimary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isIncoming
            ? theme.colorScheme.secondaryContainer.withAlpha(128)
            : theme.colorScheme.primary.withAlpha(200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (_isChecking)
            SizedBox(
              width: 40,
              height: 40,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              ),
            )
          else if (_isCompleted)
            IconButton(
              iconSize: 28,
              style: IconButton.styleFrom(
                backgroundColor: foregroundColor.withAlpha(30),
                foregroundColor: foregroundColor,
              ),
              icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              onPressed: _togglePlayback,
            )
          else if (_isDownloading)
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  color: foregroundColor,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _cancelDownload,
                ),
              ],
            )
          else
            IconButton(
              iconSize: 28,
              style: IconButton.styleFrom(
                backgroundColor: foregroundColor.withAlpha(30),
                foregroundColor: foregroundColor,
              ),
              icon: const Icon(Icons.download_rounded),
              onPressed: _startDownload,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isCompleted)
                  WaveformSlider(
                    waveform: _displayWaveform,
                    progress: _duration.inMilliseconds > 0
                        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                        : 0.0,
                    activeColor: foregroundColor,
                    inactiveColor: foregroundColor.withAlpha(60),
                    onSeek: (pct) {
                      final ms = (_duration.inMilliseconds * pct).round();
                      _seek(Duration(milliseconds: ms));
                    },
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(
                      value: _isDownloading ? _progress : null,
                      backgroundColor: foregroundColor.withAlpha(40),
                      valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isCompleted
                            ? _getDurationText()
                            : _statusText,
                        style: TextStyle(
                          fontSize: 11,
                          color: foregroundColor.withAlpha(200),
                        ),
                      ),
                      Text(
                        _isCompleted ? 'Voice Message' : '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: foregroundColor.withAlpha(160),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WaveformSlider extends StatelessWidget {
  const WaveformSlider({
    super.key,
    required this.waveform,
    required this.progress,
    required this.onSeek,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<int> waveform;
  final double progress; // 0.0 to 1.0
  final ValueChanged<double> onSeek;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final seekProgress = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            onSeek(seekProgress);
          },
          onHorizontalDragUpdate: (details) {
            final seekProgress = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            onSeek(seekProgress);
          },
          child: SizedBox(
            height: 36,
            width: double.infinity,
            child: CustomPaint(
              painter: WaveformPainter(
                waveform: waveform,
                progress: progress,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ),
          ),
        );
      },
    );
  }
}

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.waveform,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<int> waveform;
  final double progress; // 0.0 to 1.0
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final paintActive = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final paintInactive = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    final barCount = waveform.length;
    const gap = 2.0;
    final totalGaps = gap * (barCount - 1);
    final barWidth = (size.width - totalGaps) / barCount;

    const maxVal = 255.0;

    for (var i = 0; i < barCount; i++) {
      final val = waveform[i].clamp(0, 255).toDouble();
      final barHeight = (val / maxVal * size.height).clamp(3.0, size.height);

      final x = i * (barWidth + gap);
      final y = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );

      final barProgress = i / barCount;
      if (barProgress <= progress) {
        canvas.drawRRect(rect, paintActive);
      } else {
        canvas.drawRRect(rect, paintInactive);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.waveform != waveform ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
