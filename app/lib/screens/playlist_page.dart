import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/song.dart';
import '../providers.dart';
import 'song_list_page.dart';

/// Detail page for a locally-created playlist.
class PlaylistPage extends ConsumerWidget {
  const PlaylistPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final playlist = library.playlists
        .where((p) => p.id == playlistId)
        .firstOrNull;
    final notifier = ref.read(libraryProvider.notifier);

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Playlist')),
        body: const Center(
          child: Text(
            'This playlist no longer exists.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return SongListPage(
      title: playlist.name,
      songs: playlist.songs,
      subtitle:
          '${playlist.songs.length} ${playlist.songs.length == 1 ? 'song' : 'songs'}',
      emptyText:
          'No songs yet.\nSearch, then long-press a song to add it here.',
      header: ListHeaderBanner(
        seed: playlist.id.hashCode.abs(),
        thumbnailUrl: playlist.songs.isEmpty
            ? null
            : playlist.songs.first.thumbnailUrl,
        title: playlist.name,
        subtitle: playlist.description,
      ),
      onRemove: (song) {
        final idx = playlist.songs.indexWhere((s) => s.id == song.id);
        if (idx >= 0) notifier.removeFromPlaylist(playlistId, idx);
      },
      actions: [
        IconButton(
          tooltip: 'Rename',
          onPressed: () => _rename(context, ref),
          icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
        ),
        IconButton(
          tooltip: 'Delete',
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: const Text(
                  'Delete playlist?',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                content: const Text(
                  'This can\'t be undone.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await notifier.deletePlaylist(playlistId);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          icon: const Icon(
            Icons.delete_outline,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Rename playlist',
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(libraryProvider.notifier).renamePlaylist(playlistId, name);
    }
  }
}
