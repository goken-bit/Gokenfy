import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/artist.dart';
import '../models/artist_page.dart';
import '../models/song.dart';
import '../providers.dart';
import '../widgets/art.dart';
import '../widgets/like_button.dart';
import '../widgets/section_header.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';
import 'song_list_page.dart';

/// Artist detail page: header, top songs and release carousels.
class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: artist.id.isNotEmpty
          ? _ArtistBody(artist: artist)
          : _ResolveArtist(name: artist.name),
    );
  }
}

/// Resolves an artist id by name when a song only carried a name.
class _ResolveArtist extends ConsumerWidget {
  const _ResolveArtist({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolved = ref.watch(artistByNameProvider(name));
    return resolved.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (_, __) => _NotFound(name: name),
      data: (artist) {
        if (artist == null) return _NotFound(name: name);
        return _ArtistBody(artist: artist);
      },
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artist')),
      body: Center(
        child: Text(
          'Couldn\'t find "$name".',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _ArtistBody extends ConsumerWidget {
  const _ArtistBody({required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(artistPageProvider(artist.id));
    return pageAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(artist.name)),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: Text(artist.name)),
        body: const Center(
          child: Text(
            'Couldn\'t load this artist.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (page) => _ArtistContent(page: page),
    );
  }
}

class _ArtistContent extends ConsumerWidget {
  const _ArtistContent({required this.page});

  final ArtistPage page;

  void _play(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs, {
    int index = 0,
  }) {
    if (songs.isEmpty) return;
    ref.read(playerProvider.notifier).playSong(List.of(songs), index);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  void _openAlbum(BuildContext context, WidgetRef ref, String browseId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AlbumPage(albumId: browseId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artist = page.artist;
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        _ArtistHeader(
          thumbnailUrl: artist.thumbnailUrl,
          name: artist.name,
          monthlyListeners: page.monthlyListeners,
          seed: artist.id.hashCode.abs(),
        ),
        if (page.topSongs.isNotEmpty) ...[
          _PlayAllBar(
            onPlay: () => _play(context, ref, page.topSongs),
          ),
          const SizedBox(height: 4),
          ...page.topSongs.asMap().entries.map(
            (e) => SongTile(
              song: e.value,
              onTap: () => _play(context, ref, page.topSongs, index: e.key),
              onLongPress: () => showSongActions(context, ref, e.value),
              trailing: LikeButton(song: e.value),
            ),
          ),
        ],
        if (page.albums.isNotEmpty) ...[
          SectionHeader(title: 'Albums'),
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: page.albums.length,
              itemBuilder: (context, i) {
                final a = page.albums[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ArtCard(
                    seed: a.id.hashCode.abs(),
                    width: 150,
                    title: a.title,
                    subtitle: a.year?.toString(),
                    imageUrl: a.thumbnailUrl,
                    onTap: () => _openAlbum(context, ref, a.id),
                  ),
                );
              },
            ),
          ),
        ],
        if (page.singles.isNotEmpty) ...[
          SectionHeader(title: 'Singles & EPs'),
          SizedBox(
            height: 210,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: page.singles.length,
              itemBuilder: (context, i) {
                final a = page.singles[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ArtCard(
                    seed: a.id.hashCode.abs(),
                    width: 150,
                    title: a.title,
                    subtitle: a.year?.toString(),
                    imageUrl: a.thumbnailUrl,
                    onTap: () => _openAlbum(context, ref, a.id),
                  ),
                );
              },
            ),
          ),
        ],
        if (page.about != null && page.about!.isNotEmpty) ...[
          SectionHeader(title: 'About'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              page.about!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ArtistHeader extends StatelessWidget {
  const _ArtistHeader({
    required this.thumbnailUrl,
    required this.name,
    required this.monthlyListeners,
    required this.seed,
  });

  final String? thumbnailUrl;
  final String name;
  final String? monthlyListeners;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 20),
      child: Column(
        children: [
          ArtImage(url: thumbnailUrl, size: 180, radius: 90, seed: seed),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (monthlyListeners != null && monthlyListeners!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              monthlyListeners!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayAllBar extends StatelessWidget {
  const _PlayAllBar({required this.onPlay});

  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onPlay,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text(
              'Play',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Album detail page backed by `albumSongsProvider`.
class _AlbumPage extends ConsumerWidget {
  const _AlbumPage({required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(albumSongsProvider(albumId));
    return songsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Album')),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Album')),
        body: const Center(
          child: Text(
            'Couldn\'t load this album.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (songs) => SongListPage(
        title: 'Album',
        songs: songs,
        emptyText: 'No songs found.',
      ),
    );
  }
}
