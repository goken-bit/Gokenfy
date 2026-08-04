import 'album.dart';
import 'artist.dart';
import 'playlist.dart';
import 'song.dart';

/// Grouped results for a search query.
class SearchResults {
  const SearchResults({
    this.songs = const [],
    this.videos = const [],
    this.albums = const [],
    this.artists = const [],
    this.playlists = const [],
    this.channels = const [],
  });

  final List<Song> songs;
  final List<Song> videos;
  final List<Album> albums;
  final List<Artist> artists;
  final List<Playlist> playlists;
  final List<Artist> channels;

  bool get isEmpty =>
      songs.isEmpty &&
      videos.isEmpty &&
      albums.isEmpty &&
      artists.isEmpty &&
      playlists.isEmpty &&
      channels.isEmpty;

  int get total =>
      songs.length +
      videos.length +
      albums.length +
      artists.length +
      playlists.length +
      channels.length;

  static const empty = SearchResults();
}
