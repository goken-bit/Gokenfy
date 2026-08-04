import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/song.dart';
import '../models/user_playlist.dart';
import '../providers.dart';

/// Context menu for a song (long-press anywhere): like, queue, add to playlist.
Future<void> showSongActions(
  BuildContext context,
  WidgetRef ref,
  Song song,
) async {
  final library = ref.read(libraryProvider.notifier);
  final liked = ref
      .read(libraryProvider)
      .likedSongs
      .any((s) => s.id == song.id);
  final downloads = ref.read(downloadProvider.notifier);
  final downloaded = downloads.isDownloaded(song.id);

  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final player = ref.read(playerProvider.notifier);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.play_arrow_rounded,
                color: AppColors.textSecondary,
              ),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                song.artistNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            const Divider(),
            _ActionItem(
              icon: liked ? Icons.favorite : Icons.favorite_border,
              color: liked
                  ? AppColors.heartPinkBright
                  : AppColors.textSecondary,
              label: liked ? 'Remove from Liked Songs' : 'Save to Liked Songs',
              onTap: () {
                Navigator.pop(ctx);
                library.toggleLike(song);
              },
            ),
            _ActionItem(
              icon: Icons.playlist_play,
              label: 'Play next',
              onTap: () {
                Navigator.pop(ctx);
                player.playNext(song);
              },
            ),
            _ActionItem(
              icon: Icons.queue_music,
              label: 'Add to queue',
              onTap: () {
                Navigator.pop(ctx);
                player.addToQueue(song);
              },
            ),
            _ActionItem(
              icon: Icons.playlist_add,
              label: 'Add to playlist',
              onTap: () {
                Navigator.pop(ctx);
                _showAddToPlaylist(ctx, ref, song);
              },
            ),
            _ActionItem(
              icon: downloaded ? Icons.download_done : Icons.download,
              label: downloaded ? 'Remove download' : 'Download for offline',
              onTap: () {
                Navigator.pop(ctx);
                final dc = ref.read(downloadProvider.notifier);
                if (downloaded) {
                  dc.remove(song.id);
                } else {
                  dc.download(song);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

void _showAddToPlaylist(BuildContext context, WidgetRef ref, Song song) async {
  final library = ref.read(libraryProvider);
  final notifier = ref.read(libraryProvider.notifier);

  final selected = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Add to playlist',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _ActionItem(
            icon: Icons.playlist_add,
            label: 'Create new playlist',
            onTap: () => Navigator.pop(ctx, '__new__'),
          ),
          if (library.playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No playlists yet. Create one!',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: library.playlists.length,
                itemBuilder: (inner, i) {
                  final p = library.playlists[i];
                  return _ActionItem(
                    icon: Icons.queue_music,
                    label: p.name,
                    onTap: () => Navigator.pop(ctx, p.id),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  if (selected == null) return;
  if (selected == '__new__') {
    final name = await _promptPlaylistName(context);
    if (name == null || name.isEmpty) return;
    await notifier.createPlaylist(name, songs: [song]);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Added to "$name"')));
    return;
  }
  await notifier.addToPlaylist(selected, song);
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to playlist')));
  }
}

Future<String?> _promptPlaylistName(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'New playlist',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(hintText: 'Playlist name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
