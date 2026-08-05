import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/song.dart';
import '../providers.dart';
import '../widgets/art.dart';
import '../widgets/section_header.dart';
import 'player_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'Good night';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(libraryProvider.select((l) => l.history));
    final recent = history.take(10).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _greeting,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.accent,
                    child: Icon(
                      Icons.person,
                      color: AppColors.background,
                      size: 22,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: 'Made for you')),
          const SliverToBoxAdapter(child: _RecommendationTileRow()),
          if (recent.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Recently played'),
            ),
            SliverToBoxAdapter(
              child: TileRow(
                itemCount: recent.length,
                width: 140,
                itemBuilder: (context, i) {
                  final song = recent[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ArtCard(
                      seed: song.title.hashCode.abs(),
                      width: 140,
                      title: song.title,
                      subtitle: song.artistNames,
                      imageUrl: song.thumbnailUrl,
                      onTap: () => _play(context, ref, recent, i),
                    ),
                  );
                },
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          _DiscoveryShelves(),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }

  void _play(BuildContext context, WidgetRef ref, List<Song> songs, int index) {
    final list = List.of(songs);
    ref.read(playerProvider.notifier).playSong(list, index);
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }
}

/// "Good morning" style quick-pick grid of shortcut tiles.
class _RecommendationTileRow extends StatelessWidget {
  const _RecommendationTileRow();

  @override
  Widget build(BuildContext context) {
    const labels = ['Pop', 'Chill', 'Workout', 'Focus'];
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _QuickPickTile(label: labels[i], seed: i),
        ),
      ),
    );
  }
}

class _QuickPickTile extends StatelessWidget {
  const _QuickPickTile({required this.label, required this.seed});

  final String label;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 150,
        decoration: BoxDecoration(gradient: ArtGradients.of(seed)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Real discovery feed: one titled shelf of songs per curated query.
class _DiscoveryShelves extends ConsumerWidget {
  const _DiscoveryShelves();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shelvesAsync = ref.watch(discoveryProvider);
    return shelvesAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (shelves) {
        if (shelves.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
            final shelf = shelves[i];
            final songs = shelf.songs;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    _prettyTitle(shelf.title),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  height: 205,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: songs.length,
                    itemBuilder: (inner, j) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ArtCard(
                        seed: songs[j].title.hashCode.abs(),
                        width: 140,
                        title: songs[j].title,
                        subtitle: songs[j].artistNames,
                        imageUrl: songs[j].thumbnailUrl,
                        onTap: () {
                          ref
                              .read(playerProvider.notifier)
                              .playSong(List.of(songs), j);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PlayerScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          }, childCount: shelves.length),
        );
      },
    );
  }

  String _prettyTitle(String query) {
    switch (query) {
      case 'top hits':
        return 'Top hits';
      case 'new music':
        return 'New music';
      case 'trending songs':
        return 'Trending songs';
      case 'chill hits':
        return 'Chill hits';
      default:
        return query[0].toUpperCase() + query.substring(1);
    }
  }
}
