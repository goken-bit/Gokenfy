import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/song.dart';
import '../providers.dart';

/// Heart toggle for a song (persists into Liked Songs).
class LikeButton extends ConsumerWidget {
  const LikeButton({super.key, required this.song, this.size = 24});

  final Song song;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(
      libraryProvider.select((l) => l.likedSongs.any((s) => s.id == song.id)),
    );
    return IconButton(
      onPressed: () => ref.read(libraryProvider.notifier).toggleLike(song),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          liked ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(liked),
          color: liked ? AppColors.heartPinkBright : AppColors.textSecondary,
          size: size,
        ),
      ),
    );
  }
}
