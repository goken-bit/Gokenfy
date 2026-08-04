import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/haptics.dart';
import '../core/theme.dart';
import '../models/player_state.dart';
import '../models/song.dart';
import '../providers.dart';
import '../widgets/art.dart';
import '../widgets/equalizer.dart';
import '../widgets/like_button.dart';
import '../widgets/song_tile.dart';
import 'lyrics_screen.dart';
import 'music_video_screen.dart';

/// Full-screen now-playing page with seek bar and transport controls.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final song = player.current;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text(
            'Nothing playing',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final durationMs = player.duration?.inMilliseconds ?? 0;
    final positionMs = (_dragValue ?? player.position.inMilliseconds.toDouble())
        .clamp(0.0, durationMs.toDouble());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(song: song),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Hero(
                        tag: 'mini-art-${song.id}',
                        child: ArtImage(
                          url: song.thumbnailUrl,
                          size: MediaQuery.of(context).size.width - 96,
                          radius: 14,
                          seed: song.title.hashCode.abs(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _TrackInfo(song: song),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                      ),
                      child: Slider(
                        value: positionMs.toDouble(),
                        max: durationMs > 0 ? durationMs.toDouble() : 1,
                        onChanged: durationMs > 0
                            ? (v) => setState(() => _dragValue = v)
                            : null,
                        onChangeEnd: (v) {
                          ref
                              .read(playerProvider.notifier)
                              .seek(Duration(milliseconds: v.round()));
                          setState(() => _dragValue = null);
                        },
                        activeColor: AppColors.textPrimary,
                        inactiveColor: AppColors.divider,
                      ),
                    ),
                    _TimeRow(positionMs: positionMs, durationMs: durationMs),
                    _Controls(player: player),
                    const SizedBox(height: 20),
                    _ExtrasRow(),
                    const SizedBox(height: 12),
                    _QueueButton(player: player),
                    if (player.hasError) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Couldn\'t load this track. Try another one.',
                        style: TextStyle(color: AppColors.danger, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textPrimary,
            size: 32,
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'Now Playing',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 44),
        Expanded(
          child: Column(
            children: [
              Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                song.artistNames.isEmpty ? 'Unknown artist' : song.artistNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 44, child: LikeButton(song: song, size: 26)),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.positionMs, required this.durationMs});

  final double positionMs;
  final double durationMs;

  String _fmt(double ms) {
    final d = Duration(milliseconds: ms.round());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _fmt(positionMs),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        Text(
          _fmt(durationMs),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.player});

  final GPlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Semantics(
          label: 'Toggle shuffle',
          button: true,
          child: IconButton(
            onPressed: () {
              hapticSelect();
              notifier.toggleShuffle();
            },
            icon: Icon(
              Icons.shuffle,
              color: player.shuffle == GShuffle.on
                  ? AppColors.accent
                  : AppColors.textSecondary,
              size: 26,
            ),
          ),
        ),
        Semantics(
          label: 'Previous track',
          button: true,
          child: IconButton(
            onPressed: () {
              hapticSelect();
              notifier.previous();
            },
            icon: const Icon(
              Icons.skip_previous_rounded,
              color: AppColors.textPrimary,
              size: 40,
            ),
          ),
        ),
        player.processing || player.buffering
            ? const SizedBox(
                width: 72,
                height: 72,
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Semantics(
                label: player.playing ? 'Pause' : 'Play',
                button: true,
                child: IconButton(
                  onPressed: () {
                    hapticMedium();
                    notifier.togglePlay();
                  },
                  icon: Icon(
                    player.playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: AppColors.textPrimary,
                    size: 72,
                  ),
                ),
              ),
        Semantics(
          label: 'Next track',
          button: true,
          child: IconButton(
            onPressed: () {
              hapticSelect();
              notifier.next();
            },
            icon: const Icon(
              Icons.skip_next_rounded,
              color: AppColors.textPrimary,
              size: 40,
            ),
          ),
        ),
        Semantics(
          label: 'Repeat mode',
          button: true,
          child: IconButton(
            onPressed: () {
              hapticSelect();
              notifier.cycleRepeat();
            },
            icon: Icon(
              player.repeat == GRepeat.one ? Icons.repeat_one : Icons.repeat,
              color: player.repeat == GRepeat.off
                  ? AppColors.textSecondary
                  : AppColors.accent,
              size: 26,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExtrasRow extends StatelessWidget {
  const _ExtrasRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ExtraChip(
          icon: Icons.lyrics_outlined,
          label: 'Lyrics',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LyricsScreen())),
        ),
        const SizedBox(width: 12),
        _ExtraChip(
          icon: Icons.play_circle_outline_rounded,
          label: 'Video',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MusicVideoScreen())),
        ),
      ],
    );
  }
}

class _ExtraChip extends StatelessWidget {
  const _ExtraChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        backgroundColor: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

class _QueueButton extends ConsumerWidget {
  const _QueueButton({required this.player});

  final GPlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => _QueueSheet(player: player),
      ),
      icon: const Icon(
        Icons.queue_music,
        color: AppColors.textSecondary,
        size: 20,
      ),
      label: Text(
        '${player.queue.length} in queue',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet({required this.player});

  final GPlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Queue',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: player.queue.length,
                itemBuilder: (context, i) {
                  final song = player.queue[i];
                  final isCurrent = i == player.index;
                  return SongTile(
                    song: song,
                    isPlaying: isCurrent,
                    showDuration: false,
                    trailing: isCurrent
                        ? Equalizer(active: player.playing, height: 16)
                        : IconButton(
                            onPressed: () => notifier.removeAt(i),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                    onTap: isCurrent ? null : () => notifier.skipTo(i),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
