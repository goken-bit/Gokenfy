import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/search_results.dart';
import '../models/song.dart';
import '../providers.dart';
import '../widgets/art.dart';
import '../widgets/like_button.dart';
import '../widgets/section_header.dart';
import '../widgets/song_actions.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = value.trim();
      if (q == _query) return;
      setState(() => _query = q);
      ref.invalidate(searchProvider(q));
    });
  }

  void _searchNow(String value) {
    _debounce?.cancel();
    _controller.text = value;
    final q = value.trim();
    if (q.isEmpty) return;
    setState(() => _query = q);
    ref.invalidate(searchProvider(q));
    ref.read(searchHistoryProvider.notifier).add(q);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchBar(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: (value) {
                final q = value.trim();
                if (q.isEmpty) return;
                setState(() => _query = q);
                ref.invalidate(searchProvider(q));
                ref.read(searchHistoryProvider.notifier).add(q);
              },              hintText: 'What do you want to listen to?',
              backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
              elevation: const WidgetStatePropertyAll(0),
              leading: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.search, color: AppColors.textSecondary),
              ),
              trailing: [
                if (_query.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                      ref.invalidate(searchProvider(''));
                    },
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? _BrowseAll(onSearch: _searchNow)
                : _ResultsView(query: _query),
          ),
        ],
      ),
    );
  }
}

class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(searchProvider(query));
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Couldn\'t search.\nCheck your connection and try again.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return const Center(
            child: Text(
              'No results. Try a different search.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return _SearchResultsList(results: results);
      },
    );
  }
}

/// Search results grouped by type, scrolled as one list.
class _SearchResultsList extends ConsumerWidget {
  const _SearchResultsList({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 90),
      children: [
        if (results.songs.isNotEmpty) ...[
          const SectionHeader(title: 'Songs'),
          ...results.songs.asMap().entries.map(
            (e) => SongTile(
              song: e.value,
              onTap: () => _onPlay(
                context,
                ref,
                results.songs,
                e.key,
                e.value.thumbnailUrl,
              ),
              onLongPress: () => showSongActions(context, ref, e.value),
              trailing: LikeButton(song: e.value),
            ),
          ),
        ],
        if (results.albums.isNotEmpty) ...[
          const SectionHeader(title: 'Albums'),
          SizedBox(
            height: 170,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.albums.length,
              itemBuilder: (context, i) {
                final a = results.albums[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ArtImage(
                          url: a.thumbnailUrl,
                          size: 130,
                          seed: a.id.hashCode.abs(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          a.artist ?? '',
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
                );
              },
            ),
          ),
        ],
        if (results.artists.isNotEmpty) ...[
          const SectionHeader(title: 'Artists'),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.artists.length,
              itemBuilder: (context, i) {
                final a = results.artists[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 120,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: AppColors.surfaceAlt,
                          backgroundImage: a.thumbnailUrl != null
                              ? NetworkImage(a.thumbnailUrl!)
                              : null,
                          child: a.thumbnailUrl == null
                              ? Icon(
                                  Icons.person,
                                  color: AppColors.textSecondary,
                                  size: 36,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (results.playlists.isNotEmpty) ...[
          const SectionHeader(title: 'Playlists'),
          ...results.playlists.map(
            (p) => ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              dense: true,
              leading: ArtImage(
                url: p.thumbnailUrl,
                size: 48,
                radius: 6,
                seed: p.id.hashCode.abs(),
              ),
              title: Text(
                p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                p.author != null ? p.author! : 'Playlist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
        if (results.videos.isNotEmpty) ...[
          const SectionHeader(title: 'Videos'),
          ...results.videos.asMap().entries.map(
            (e) => SongTile(
              song: e.value,
              onTap: () => _onPlay(
                context,
                ref,
                results.videos,
                e.key,
                e.value.thumbnailUrl,
              ),
              onLongPress: () => showSongActions(context, ref, e.value),
              trailing: LikeButton(song: e.value),
            ),
          ),
        ],
      ],
    );
  }

  void _onPlay(
    BuildContext context,
    WidgetRef ref,
    List<Song> list,
    int index,
    String? thumb,
  ) {
    // Ensure art is set so the player has a cover in mini/full view.
    final songs = list
        .map(
          (s) => s.thumbnailUrl == null ? s.copyWith(thumbnailUrl: thumb) : s,
        )
        .toList();
    ref.read(playerProvider.notifier).playSong(songs, index);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }
}

class _BrowseAll extends ConsumerWidget {
  const _BrowseAll({required this.onSearch});

  final void Function(String query) onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    const genres = [
      'Pop',
      'Hip-Hop',
      'Chill',
      'Rock',
      'Electronic',
      'R&B',
      'Latin',
      'K-Pop',
      'Jazz',
      'Classical',
      'Workout',
      'Focus',
      'Sleep',
      'Anime',
      'Indie',
      'Gaming',
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        if (history.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent searches',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      ref.read(searchHistoryProvider.notifier).clear(),
                  child: const Text(
                    'Clear all',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final term in history)
                  InputChip(
                    label: Text(term),
                    backgroundColor: AppColors.surface,
                    side: BorderSide(color: AppColors.divider.withValues(alpha: 0.6)),
                    labelStyle: const TextStyle(color: AppColors.textPrimary),
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => onSearch(term),
                    onDeleted: () =>
                        ref.read(searchHistoryProvider.notifier).remove(term),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        const SectionHeader(title: 'Browse all'),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
          ),
          itemCount: genres.length,
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => onSearch(genres[i]),
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: ArtGradients.of(i)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  genres[i],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
