import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/song.dart';
import 'art.dart';

/// Standard song row: art | title/artist | trailing action.
class SongTile extends ConsumerWidget {
  const SongTile({
    super.key,
    required this.song,
    this.artSize = 48,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.isPlaying = false,
    this.showDuration = true,
    this.seed,
  });

  final Song song;
  final double artSize;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool isPlaying;
  final bool showDuration;
  final int? seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      dense: true,
      leading: ArtImage(
        url: song.thumbnailUrl,
        size: artSize,
        radius: 6,
        seed: seed ?? song.title.hashCode.abs(),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isPlaying ? AppColors.accent : AppColors.textPrimary,
          fontSize: 15,
          fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        song.artistNames.isEmpty ? 'Unknown artist' : song.artistNames,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing:
          trailing ??
          (showDuration
              ? Text(
                  _leading(song),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                )
              : null),
    );
  }

  String _leading(Song song) {
    if (isPlaying) return '';
    return song.displayDuration;
  }
}
