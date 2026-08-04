import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers.dart';
import '../screens/player_screen.dart';
import 'art.dart';

/// Compact now-playing bar pinned above the bottom navigation.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final song = player.current;

    if (song == null) return const SizedBox.shrink();

    final progress = player.progress ?? 0.0;

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PlayerScreen())),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 1.5,
              backgroundColor: AppColors.divider,
              color: AppColors.accent,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Hero(
                    tag: 'mini-art-${song.id}',
                    child: ArtImage(
                      url: song.thumbnailUrl,
                      size: 44,
                      radius: 6,
                      seed: song.title.hashCode.abs(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          song.artistNames.isEmpty
                              ? 'Unknown artist'
                              : song.artistNames,
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
                  if (player.buffering || player.processing)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Semantics(
                      label: player.playing ? 'Pause' : 'Play',
                      button: true,
                      child: IconButton(
                        onPressed: () =>
                            ref.read(playerProvider.notifier).togglePlay(),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 150),
                          child: Icon(
                            player.playing
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            key: ValueKey(player.playing),
                            color: AppColors.textPrimary,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  Semantics(
                    label: 'Next track',
                    button: true,
                    child: IconButton(
                      onPressed: () => ref.read(playerProvider.notifier).next(),
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: AppColors.textPrimary,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
