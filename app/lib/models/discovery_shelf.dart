import 'song.dart';

/// A titled shelf of songs shown on the Home screen (discovery feed).
class DiscoveryShelf {
  const DiscoveryShelf({required this.title, required this.songs});

  final String title;
  final List<Song> songs;
}
