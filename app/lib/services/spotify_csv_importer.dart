import '../models/song.dart';
import 'innertube_client.dart';

/// A parsed row from a Spotify export CSV (Liked Songs / playlist copy).
class SpotifyTrack {
  const SpotifyTrack({required this.name, required this.artist});

  final String name;
  final String artist;
}

/// Imports tracks from a Spotify CSV export by matching each row against
/// YT Music search.
class SpotifyCsvImporter {
  SpotifyCsvImporter(this._client);

  final InnertubeClient _client;

  /// Parses a Spotify CSV blob into track rows.
  List<SpotifyTrack> parse(String csv) {
    final rows = _parseCsv(csv);
    final tracks = <SpotifyTrack>[];
    for (final row in rows) {
      if (row.isEmpty) continue;
      // Spotify export columns: URI, Name, Artist, Album, Added At.
      final name = row.length > 1 ? row[1].trim() : '';
      final artist = row.length > 2 ? row[2].trim() : '';
      if (name.isEmpty && artist.isEmpty) continue;
      if (_looksLikeHeader(name, artist)) continue;
      tracks.add(SpotifyTrack(name: name, artist: artist));
    }
    return tracks;
  }

  /// Finds a playable match for [track] on YT Music.
  Future<Song?> findBySearch(SpotifyTrack track, {int attempt = 0}) async {
    final query = track.artist.isEmpty
        ? track.name
        : '${track.artist} ${track.name}';
    try {
      final results = await _client.search(query, limit: 3);
      if (results.songs.isEmpty) return null;
      return results.songs.first;
    } catch (_) {
      if (attempt == 0) {
        // Retry once with just the track name.
        return findBySearch(
          SpotifyTrack(name: track.name, artist: ''),
          attempt: 1,
        );
      }
      return null;
    }
  }

  /// Imports [tracks], returning songs that matched. Honors [limit] cap.
  Future<List<Song>> import(
    List<SpotifyTrack> tracks, {
    int limit = 100,
    void Function(int done, int total)? onProgress,
  }) async {
    final capped = tracks.take(limit).toList();
    final songs = <Song>[];
    for (var i = 0; i < capped.length; i++) {
      final song = await findBySearch(capped[i]);
      if (song != null) songs.add(song);
      onProgress?.call(i + 1, capped.length);
    }
    return songs;
  }

  bool _looksLikeHeader(String name, String artist) =>
      name.toLowerCase() == 'name' || artist.toLowerCase() == 'artist';

  List<List<String>> _parseCsv(String input) {
    final result = <List<String>>[];
    var row = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final c = input[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buf.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        row.add(buf.toString().trim());
        buf.clear();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        row.add(buf.toString().trim());
        buf.clear();
        result.add(row);
        row = [];
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty || row.isNotEmpty) {
      row.add(buf.toString().trim());
      result.add(row);
    }
    return result;
  }
}
