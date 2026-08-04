import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/discovery_shelf.dart';
import 'models/download_entry.dart';
import 'models/library_state.dart';
import 'models/lyric_line.dart';
import 'models/player_state.dart';
import 'models/search_results.dart';
import 'services/download_controller.dart';
import 'services/innertube_client.dart';
import 'services/library_controller.dart';
import 'services/player_controller.dart';
import 'services/spotify_csv_importer.dart';
import 'services/storage_service.dart';
import 'services/stream_resolver.dart';

/// Shared innertube client (single HTTP client for connection pooling).
final innertubeClientProvider = Provider<InnertubeClient>((ref) {
  final client = InnertubeClient();
  ref.onDispose(client.dispose);
  return client;
});

/// Live search: invalidate this provider with a query to re-run the search.
final searchProvider = FutureProvider.family<SearchResults, String>((
  ref,
  query,
) async {
  final q = query.trim();
  if (q.isEmpty) return SearchResults.empty;
  return ref.read(innertubeClientProvider).search(q);
});

/// Synced lyrics for a track (timed segments from YT Music).
final lyricsProvider = FutureProvider.family<List<LyricLine>, String>((
  ref,
  videoId,
) async {
  return ref.read(innertubeClientProvider).lyrics(videoId);
});

/// Playable music-video stream URL for a track (null when unavailable).
final musicVideoProvider = FutureProvider.family<String?, String>((
  ref,
  videoId,
) async {
  return ref.read(streamResolverProvider).resolveVideoUrl(videoId);
});

/// Spotify CSV import helper.
final csvImporterProvider = Provider<SpotifyCsvImporter>((ref) {
  return SpotifyCsvImporter(ref.read(innertubeClientProvider));
});

/// Curated discovery shelves for the Home screen.
final discoveryProvider = FutureProvider<List<DiscoveryShelf>>((ref) async {
  const queries = ['top hits', 'new music', 'trending songs', 'chill hits'];
  final client = ref.read(innertubeClientProvider);
  final shelves = <DiscoveryShelf>[];
  for (final q in queries) {
    try {
      final songs = await client.songs(q, limit: 12);
      if (songs.isNotEmpty) {
        shelves.add(DiscoveryShelf(title: q, songs: songs));
      }
    } catch (_) {
      // Keep the other shelves even if one query fails.
    }
  }
  return shelves;
});

/// Resolves playable stream URLs (youtube_explode_dart engine).
final streamResolverProvider = Provider<StreamResolver>((ref) {
  final resolver = StreamResolver();
  ref.onDispose(resolver.dispose);
  return resolver;
});

/// Local persistence layer.
final storageProvider = Provider<StorageService>((ref) {
  final storage = StorageService();
  ref.onDispose(storage.dispose);
  return storage;
});

/// User library: likes, playlists, history.
final libraryProvider = StateNotifierProvider<LibraryController, LibraryState>(
  (ref) => LibraryController(ref.read(storageProvider)),
);

/// Offline downloads manager.
final downloadProvider =
    StateNotifierProvider<DownloadController, Map<String, DownloadEntry>>((
      ref,
    ) {
      final controller = DownloadController(
        ref.read(streamResolverProvider),
        storage: ref.read(storageProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

/// Global playback controller. Records played tracks into history.
final playerProvider = StateNotifierProvider<PlayerController, GPlayerState>((
  ref,
) {
  final controller = PlayerController(
    ref.read(streamResolverProvider),
    storage: ref.read(storageProvider),
    onTrackStarted: (song) {
      ref.read(libraryProvider.notifier).recordPlay(song);
    },
    resolveCachedPath: (id) async => ref.read(downloadProvider).pathFor(id),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
