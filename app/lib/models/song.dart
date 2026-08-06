import 'artist.dart';

/// A playable track resolved from YouTube (audio or video).
class Song {
  const Song({
    required this.id,
    required this.title,
    this.artistNames = '',
    this.artists = const [],
    this.album,
    this.thumbnailUrl,
    this.durationMs,
    this.isExplicit = false,
    this.isVideo = false,
    this.channelId,
    this.playlistId,
    this.viewCount,
  });

  final String id;
  final String title;
  final String artistNames;
  final List<Artist> artists;
  final String? album;
  final String? thumbnailUrl;
  final int? durationMs;
  final bool isExplicit;
  final bool isVideo;
  final String? channelId;
  final String? playlistId;
  final String? viewCount;

  String get displayDuration {
    if (durationMs == null) return '';
    final d = Duration(milliseconds: durationMs!);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  Song copyWith({String? thumbnailUrl, int? durationMs, String? playlistId}) {
    return Song(
      id: id,
      title: title,
      artistNames: artistNames,
      artists: artists,
      album: album,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      isExplicit: isExplicit,
      isVideo: isVideo,
      channelId: channelId,
      playlistId: playlistId ?? this.playlistId,
      viewCount: viewCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artistNames': artistNames,
    'artists': artists.map((a) => a.toJson()).toList(),
    'album': album,
    'thumbnailUrl': thumbnailUrl,
    'durationMs': durationMs,
    'isExplicit': isExplicit,
    'isVideo': isVideo,
    'channelId': channelId,
    'playlistId': playlistId,
    'viewCount': viewCount,
  };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    artistNames: json['artistNames'] as String? ?? '',
    artists: (json['artists'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Artist.fromJson)
        .toList(),
    album: json['album'] as String?,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    durationMs: json['durationMs'] as int?,
    isExplicit: json['isExplicit'] as bool? ?? false,
    isVideo: json['isVideo'] as bool? ?? false,
    channelId: json['channelId'] as String?,
    playlistId: json['playlistId'] as String?,
    viewCount: json['viewCount'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Song && other.id == id && other.playlistId == playlistId;

  @override
  int get hashCode => Object.hash(id, playlistId);
}
