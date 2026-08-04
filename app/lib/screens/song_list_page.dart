import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/song.dart';
import '../providers.dart';
import '../widgets/art.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';

/// Reusable page: a header, a "Play all" row, then a list of songs.
class SongListPage extends ConsumerWidget {
  const SongListPage({
    super.key,
    required this.title,
    required this.songs,
    this.subtitle,
    this.header,
    this.onRemove,
    this.emptyText = 'Nothing here yet.',
    this.actions = const [],
  });

  final String title;
  final List<Song> songs;
  final String? subtitle;
  final Widget? header;
  final void Function(Song song)? onRemove;
  final String emptyText;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: Column(
        children: [
          if (header != null) header!,
          if (songs.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  emptyText,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: _PlayAllButton(songs: songs),
                title: const Text(
                  'Play all',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: subtitle != null
                    ? Text(
                        subtitle!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      )
                    : null,
                onTap: () => _play(context, ref, 0),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 90),
                itemCount: songs.length,
                itemBuilder: (context, i) {
                  final song = songs[i];
                  final isCurrent = ref.watch(
                    playerProvider.select(
                      (p) => p.index == i && p.current?.id == song.id,
                    ),
                  );
                  return SongTile(
                    song: song,
                    isPlaying: isCurrent,
                    onTap: () => _play(context, ref, i),
                    trailing: onRemove != null
                        ? IconButton(
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            onPressed: () => onRemove!(song),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _play(BuildContext context, WidgetRef ref, int index) {
    if (songs.isEmpty) return;
    ref.read(playerProvider.notifier).playSong(List.of(songs), index);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }
}

class _PlayAllButton extends StatelessWidget {
  const _PlayAllButton({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: AppColors.background,
        size: 30,
      ),
    );
  }
}

/// A gradient banner used as a playlist/album header.
class ListHeaderBanner extends StatelessWidget {
  const ListHeaderBanner({
    super.key,
    required this.seed,
    this.thumbnailUrl,
    required this.title,
    this.subtitle,
  });

  final int seed;
  final String? thumbnailUrl;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          ArtImage(url: thumbnailUrl, size: 96, radius: 10, seed: seed),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
