import 'album.dart';
import 'artist.dart';
import 'song.dart';

/// Parsed artist page from YT Music: header info plus top songs and releases.
class ArtistPage {
  const ArtistPage({
    required this.artist,
    this.monthlyListeners,
    this.topSongs = const [],
    this.albums = const [],
    this.singles = const [],
    this.about,
  });

  final Artist artist;
  final String? monthlyListeners;
  final List<Song> topSongs;
  final List<Album> albums;
  final List<Album> singles;
  final String? about;
}
