import 'song.dart';
import 'user_playlist.dart';

/// Serializable state of the user's library.
class LibraryState {
  const LibraryState({
    this.likedSongs = const [],
    this.playlists = const [],
    this.history = const [],
    this.playCounts = const {},
    this.loaded = false,
  });

  final List<Song> likedSongs;
  final List<UserPlaylist> playlists;
  final List<Song> history;

  /// songId -> number of times played (for smart playlists).
  final Map<String, int> playCounts;

  /// True once persisted data has been read from disk.
  final bool loaded;

  LibraryState copyWith({
    List<Song>? likedSongs,
    List<UserPlaylist>? playlists,
    List<Song>? history,
    Map<String, int>? playCounts,
    bool? loaded,
  }) {
    return LibraryState(
      likedSongs: likedSongs ?? this.likedSongs,
      playlists: playlists ?? this.playlists,
      history: history ?? this.history,
      playCounts: playCounts ?? this.playCounts,
      loaded: loaded ?? this.loaded,
    );
  }
}
