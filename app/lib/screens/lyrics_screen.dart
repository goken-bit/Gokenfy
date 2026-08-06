import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/lyric_line.dart';
import '../providers.dart';

/// Full-screen synced lyrics (Spotify-style). Falls back to a static list
/// when the track has no timing data.
class LyricsScreen extends ConsumerWidget {
  const LyricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(playerProvider).current;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lyrics',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (song != null)
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      body: song == null
          ? const Center(
              child: Text(
                'Nothing playing.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : LyricsView(songId: song.id),
    );
  }
}

/// Synced lyrics with auto-highlight of the currently sung line. Falls back to
/// a static list when the track has no timing data. When [height] is given the
/// list is bounded (used embedded below the player); otherwise it fills the
/// parent.
class LyricsView extends ConsumerStatefulWidget {
  const LyricsView({super.key, required this.songId, this.height});

  final String songId;
  final double? height;

  @override
  ConsumerState<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends ConsumerState<LyricsView> {
  final ScrollController _scroll = ScrollController();
  final List<GlobalKey> _keys = [];
  int _active = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider(widget.songId));
    final player = ref.watch(playerProvider);

    if (lyricsAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (lyricsAsync.hasError || (lyricsAsync.valueOrNull?.isEmpty ?? true)) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Lyrics are not available for this track.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final lyrics = lyricsAsync.requireValue;
    final timed = lyrics.any((l) => l.offsetMs != null);

    if (!timed) {
      return _PlainLyrics(lyrics: lyrics);
    }

    final posMs = player.position.inMilliseconds;
    var active = -1;
    for (var i = 0; i < lyrics.length; i++) {
      final t = lyrics[i].offsetMs;
      if (t != null && t <= posMs) {
        active = i;
      } else if (t != null) {
        break;
      }
    }

    if (active != _active) {
      _active = active;
      if (active >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = _keys[active].currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.5,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }

    while (_keys.length < lyrics.length) {
      _keys.add(GlobalKey());
    }

    final list = ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      itemCount: lyrics.length,
      itemBuilder: (context, i) {
        final isActive = i == _active;
        return Container(
          key: _keys[i],
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: isActive ? 21 : 16,
              height: 1.35,
              color: isActive
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: 0.55),
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            ),
            child: Text(
              lyrics[i].text,
              textAlign: TextAlign.left,
            ),
          ),
        );
      },
    );

    if (widget.height == null) {
      return list;
    }
    return SizedBox(height: widget.height, child: list);
  }
}

class _PlainLyrics extends StatelessWidget {
  const _PlainLyrics({required this.lyrics});

  final List<LyricLine> lyrics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        for (final line in lyrics)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              line.text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}
