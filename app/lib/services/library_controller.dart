import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/library_state.dart';
import '../models/song.dart';
import '../models/user_playlist.dart';
import 'storage_service.dart';

/// Manages the persisted user library (likes, playlists, history).
class LibraryController extends StateNotifier<LibraryState> {
  LibraryController(this._storage) : super(const LibraryState()) {
    _load();
  }

  final StorageService _storage;
  final Random _rand = Random();

  Future<void> _load() async {
    final liked = await _storage.loadLiked();
    final playlists = await _storage.loadPlaylists();
    final history = await _storage.loadHistory();
    final playCounts = await _storage.loadPlayCounts();
    state = state.copyWith(
      likedSongs: liked,
      playlists: playlists,
      history: history,
      playCounts: playCounts,
      loaded: true,
    );
  }

  static String _uid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';

  // -------------------------------------------------------------------------
  // Likes
  // -------------------------------------------------------------------------

  bool isLiked(Song song) => state.likedSongs.any((s) => s.id == song.id);

  Future<void> toggleLike(Song song) async {
    final liked = List.of(state.likedSongs);
    final existing = liked.indexWhere((s) => s.id == song.id);
    if (existing >= 0) {
      liked.removeAt(existing);
    } else {
      liked.insert(0, song);
    }
    state = state.copyWith(likedSongs: liked);
    await _storage.saveLiked(liked);
  }

  Future<void> like(Song song) async {
    if (isLiked(song)) return;
    await toggleLike(song);
  }

  Future<void> unlike(Song song) async {
    if (!isLiked(song)) return;
    await toggleLike(song);
  }

  // -------------------------------------------------------------------------
  // History
  // -------------------------------------------------------------------------

  static const int _maxHistory = 100;

  Future<void> recordPlay(Song song) async {
    final history = List.of(state.history)..removeWhere((s) => s.id == song.id);
    history.insert(0, song);
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }
    final playCounts = Map<String, int>.of(state.playCounts);
    playCounts[song.id] = (playCounts[song.id] ?? 0) + 1;
    state = state.copyWith(history: history, playCounts: playCounts);
    await _storage.saveHistory(history);
    await _storage.savePlayCounts(playCounts);
  }

  /// Songs ordered by play count (descending), for smart playlists.
  List<Song> mostPlayed({int limit = 20}) {
    final counts = state.playCounts;
    final byId = <String, Song>{};
    for (final s in state.history) {
      byId.putIfAbsent(s.id, () => s);
    }
    for (final s in state.likedSongs) {
      byId.putIfAbsent(s.id, () => s);
    }
    final ordered = byId.values.toList()
      ..sort((a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0));
    return ordered.where((s) => (counts[s.id] ?? 0) > 0).take(limit).toList();
  }

  /// Folder names currently in use, alphabetically (subset of playlists).
  List<String> folders() {
    final set = state.playlists
        .map((p) => p.folder?.trim())
        .whereType<String>()
        .where((f) => f.isNotEmpty)
        .toSet();
    final list = set.toList()..sort();
    return list;
  }

  Future<void> clearHistory() async {
    state = state.copyWith(history: const []);
    await _storage.saveHistory(const []);
  }

  // -------------------------------------------------------------------------
  // Playlists
  // -------------------------------------------------------------------------

  Future<UserPlaylist> createPlaylist(
    String name, {
    String? description,
    String? folder,
    List<Song>? songs,
  }) async {
    final playlist = UserPlaylist(
      id: _uid(),
      name: name,
      description: description,
      folder: folder,
      songs: songs ?? const [],
    );
    state = state.copyWith(playlists: [...state.playlists, playlist]);
    await _storage.savePlaylists(state.playlists);
    return playlist;
  }

  Future<void> deletePlaylist(String id) async {
    state = state.copyWith(
      playlists: state.playlists.where((p) => p.id != id).toList(),
    );
    await _storage.savePlaylists(state.playlists);
  }

  Future<void> renamePlaylist(String id, String name) async {
    state = state.copyWith(
      playlists: state.playlists
          .map((p) => p.id == id ? p.copyWith(name: name) : p)
          .toList(),
    );
    await _storage.savePlaylists(state.playlists);
  }

  UserPlaylist? playlistById(String id) {
    for (final p in state.playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> setPlaylistFolder(String id, String? folder) async {
    final normalized = folder?.trim();
    state = state.copyWith(
      playlists: state.playlists
          .map(
            (p) => p.id == id
                ? p.copyWith(
                    folder: normalized != null && normalized.isEmpty
                        ? null
                        : normalized,
                  )
                : p,
          )
          .toList(),
    );
    await _storage.savePlaylists(state.playlists);
  }

  Future<void> addToPlaylist(String id, Song song) async {
    final playlists = state.playlists.map((p) {
      if (p.id != id) return p;
      return p.copyWith(songs: List.of(p.songs)..add(song));
    }).toList();
    state = state.copyWith(playlists: playlists);
    await _storage.savePlaylists(playlists);
  }

  Future<void> removeFromPlaylist(String id, int index) async {
    final playlists = state.playlists.map((p) {
      if (p.id != id) return p;
      final songs = List.of(p.songs)..removeAt(index);
      return p.copyWith(songs: songs);
    }).toList();
    state = state.copyWith(playlists: playlists);
    await _storage.savePlaylists(playlists);
  }

  Future<void> reorderPlaylist(String id, int from, int to) async {
    final playlists = state.playlists.map((p) {
      if (p.id != id) return p;
      if (from < 0 ||
          to < 0 ||
          from >= p.songs.length ||
          to >= p.songs.length) {
        return p;
      }
      final songs = List.of(p.songs);
      final song = songs.removeAt(from);
      songs.insert(to, song);
      return p.copyWith(songs: songs);
    }).toList();
    state = state.copyWith(playlists: playlists);
    await _storage.savePlaylists(playlists);
  }

  /// Exports the entire library as a JSON string.
  String exportLibrary() {
    final data = {
      'likedSongs': state.likedSongs.map((s) => s.toJson()).toList(),
      'playlists': state.playlists.map((p) => p.toJson()).toList(),
      'history': state.history.map((s) => s.toJson()).toList(),
      'playCounts': state.playCounts,
      'exportedAt': DateTime.now().toIso8601String(),
      'version': 1,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Imports a library JSON string (merges with current state).
  Future<void> importLibrary(String json) async {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final liked = (data['likedSongs'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Song.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    final playlists = (data['playlists'] as List? ?? [])
        .whereType<Map>()
        .map((m) => UserPlaylist.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    final history = (data['history'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Song.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    final counts = <String, int>{};
    if (data['playCounts'] is Map) {
      (data['playCounts'] as Map).forEach((k, v) {
        counts[k.toString()] = (v as num).toInt();
      });
    }
    state = state.copyWith(
      likedSongs: liked,
      playlists: playlists,
      history: history,
      playCounts: counts,
    );
    await _storage.saveLiked(liked);
    await _storage.savePlaylists(playlists);
    await _storage.saveHistory(history);
    await _storage.savePlayCounts(counts);
  }
}
