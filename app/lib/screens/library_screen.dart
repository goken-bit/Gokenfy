import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/download_entry.dart';
import '../models/library_state.dart';
import '../models/user_playlist.dart';
import '../providers.dart';
import '../services/library_controller.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';
import 'playlist_page.dart';
import 'song_list_page.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final notifier = ref.read(libraryProvider.notifier);
    final downloads = ref.watch(downloadProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Your Library',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _createPlaylist(context, ref),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.textSecondary,
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
          ExpansionTile(
            leading: const _LibrarySquare(seed: 1, icon: Icons.favorite),
            title: const Text(
              'Liked Songs',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${library.likedSongs.length} songs',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            children: [_LikedPreview(library: library)],
          ),
          ExpansionTile(
            leading: const _LibrarySquare(seed: 3, icon: Icons.history),
            title: const Text(
              'Recently played',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              library.history.isEmpty
                  ? 'Nothing yet'
                  : '${library.history.length} tracks',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SongListPage(
                      title: 'Recently played',
                      songs: library.history,
                      emptyText: 'Play some music to see it here.',
                    ),
                  ),
                ),
                leading: const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
                ),
                title: const Text(
                  'See all recently played',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          ExpansionTile(
            leading: const _LibrarySquare(seed: 4, icon: Icons.offline_pin),
            title: const Text(
              'Downloads',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${downloads.values.where((e) => e.isDone).length} songs',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            children: [_DownloadsPreview(downloads: downloads)],
          ),
          ExpansionTile(
            leading: const _LibrarySquare(seed: 5, icon: Icons.auto_awesome),
            title: const Text(
              'Smart playlists',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${notifier.mostPlayed().length} most played',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            children: [
              ListTile(
                leading: const Icon(
                  Icons.trending_up,
                  color: AppColors.textSecondary,
                ),
                title: const Text('Most played'),
                subtitle: const Text('Based on your listening'),
                onTap: () {
                  final songs = notifier.mostPlayed();
                  if (songs.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SongListPage(
                        title: 'Most played',
                        songs: songs,
                        emptyText: 'Play more music to build this list.',
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.shuffle,
                  color: AppColors.textSecondary,
                ),
                title: const Text('Liked mix'),
                subtitle: Text('${library.likedSongs.length} tracks'),
                onTap: () {
                  final songs = List.of(library.likedSongs)..shuffle();
                  if (songs.isEmpty) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SongListPage(
                        title: 'Liked mix',
                        songs: songs,
                        emptyText: 'Like some songs first.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Playlists',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (library.playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                'Create a playlist to get started.',
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            )
          else
            ..._buildPlaylists(context, notifier, library),
        ],
      ),
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final result = await _promptPlaylist(context);
    if (result == null) return;
    final name = result.$1.trim();
    if (name.isEmpty) return;
    final folder = result.$2.trim();
    await context
        .read(libraryProvider.notifier)
        .createPlaylist(name, folder: folder.isEmpty ? null : folder);
  }

  Future<(String, String)?> _promptPlaylist(BuildContext context) async {
    final nameController = TextEditingController();
    final folderController = TextEditingController();
    return showDialog<(String, String)>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'New playlist',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Playlist name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: folderController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Folder (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, (
              nameController.text.trim(),
              folderController.text.trim(),
            )),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPlaylists(
    BuildContext context,
    LibraryController notifier,
    LibraryState library,
  ) {
    final playlists = library.playlists;
    final folders = notifier.folders();
    final widgets = <Widget>[];
    final noFolder = playlists
        .where((p) => p.folder == null || p.folder!.trim().isEmpty)
        .toList();

    for (final folder in folders) {
      final inFolder = playlists
          .where((p) => p.folder != null && p.folder!.trim() == folder)
          .toList();
      if (inFolder.isEmpty) continue;
      widgets.add(_FolderHeader(name: folder, count: inFolder.length));
      widgets.addAll(inFolder.map((p) => _playlistTile(context, p)));
    }
    if (noFolder.isNotEmpty) {
      widgets.addAll(noFolder.map((p) => _playlistTile(context, p)));
    }
    return widgets;
  }

  Widget _playlistTile(BuildContext context, UserPlaylist p) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => PlaylistPage(playlistId: p.id))),
      onLongPress: () => _assignFolder(context, p),
      leading: _PlaylistSquare(id: p.id),
      title: Text(
        p.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${p.songs.length} ${p.songs.length == 1 ? 'song' : 'songs'}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
    );
  }

  Future<void> _assignFolder(BuildContext context, UserPlaylist p) async {
    final controller = TextEditingController(text: p.folder ?? '');
    final folder = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Move to folder',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Folder name (empty removes it)',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, controller.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (folder == null) return;
    final value = folder.trim().isEmpty ? null : folder.trim();
    await context.read(libraryProvider.notifier).setPlaylistFolder(p.id, value);
  }
}

class _LikedPreview extends ConsumerWidget {
  const _LikedPreview({required this.library});

  final LibraryState library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = library.likedSongs.take(3).toList();
    return Column(
      children: [
        for (final song in songs)
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            leading: _MiniArt(seed: song.title.hashCode.abs()),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              song.artistNames,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 32, right: 16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SongListPage(
                title: 'Liked Songs',
                songs: library.likedSongs,
                emptyText: 'Tap the heart on songs you love.',
                onRemove: (song) =>
                    ref.read(libraryProvider.notifier).unlike(song),
              ),
            ),
          ),
          title: const Text(
            'See all',
            style: TextStyle(color: AppColors.accent, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _LibrarySquare extends StatelessWidget {
  const _LibrarySquare({required this.seed, required this.icon});
  final int seed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: ArtGradients.of(seed),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: Colors.white, size: 26),
    );
  }
}

class _PlaylistSquare extends StatelessWidget {
  const _PlaylistSquare({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: ArtGradients.of(id.hashCode.abs()),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.queue_music,
        color: Colors.white.withValues(alpha: 0.85),
        size: 26,
      ),
    );
  }
}

class _MiniArt extends StatelessWidget {
  const _MiniArt({required this.seed});
  final int seed;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: ArtGradients.of(seed),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _FolderHeader extends StatelessWidget {
  const _FolderHeader({required this.name, required this.count});

  final String name;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder, color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadsPreview extends ConsumerWidget {
  const _DownloadsPreview({required this.downloads});

  final Map<String, DownloadEntry> downloads;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = downloads.values
        .where((e) => e.isDone && e.song != null)
        .map((e) => e.song!)
        .toList();

    if (songs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Download songs to play them offline.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Column(
      children: [
        for (final song in songs)
          SongTile(
            song: song,
            seed: song.id.hashCode.abs(),
            onTap: () {
              ref
                  .read(playerProvider.notifier)
                  .playSong(songs, songs.indexOf(song));
            },
            onLongPress: () => showSongActions(context, ref, song),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () =>
                  ref.read(downloadProvider.notifier).remove(song.id),
            ),
          ),
      ],
    );
  }
}
