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
            Text(
              'Lyrics',
              style: const TextStyle(
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
          : _LyricsBody(songId: song.id),
    );
  }
}

class _LyricsBody extends ConsumerStatefulWidget {
  const _LyricsBody({required this.songId});

  final String songId;

  @override
  ConsumerState<_LyricsBody> createState() => _LyricsBodyState();
}

class _LyricsBodyState extends ConsumerState<_LyricsBody> {
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Lyrics are not available for this track.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
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
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOut,
              alignment: 0.4,
            );
          }
        });
      }
    }

    while (_keys.length < lyrics.length) {
      _keys.add(GlobalKey());
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      itemCount: lyrics.length,
      itemBuilder: (context, i) {
        final isActive = i == _active;
        return Container(
          key: _keys[i],
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            lyrics[i].text,
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: isActive ? 22 : 17,
              height: 1.35,
              color: isActive
                  ? AppColors.textPrimary
                  : AppColors.textSecondary.withValues(alpha: 0.55),
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        );
      },
    );
  }
}

class _PlainLyrics extends StatelessWidget {
  const _PlainLyrics({required this.lyrics});

  final List<LyricLine> lyrics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        for (final line in lyrics)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              line.text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }
}
