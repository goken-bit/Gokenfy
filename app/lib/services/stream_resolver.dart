import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide StreamInfo;

import '../models/song.dart';
import '../models/stream_info.dart';

/// Resolves playable audio streams for a video.
///
/// Uses `youtube_explode_dart` (which handles YouTube's signature + n-signature
/// challenges), falling back to nothing yet — it is currently the only
/// mechanism that reliably works against YouTube's anti-scraping.
class StreamResolver {
  StreamResolver() : _yt = YoutubeExplode();

  final YoutubeExplode _yt;

  /// Returns the best (largest) audio-only stream for [videoId].
  Future<StreamInfo> resolve(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final audio = manifest.audioOnly.toList()
      ..sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));
    if (audio.isEmpty) {
      throw Exception('No audio streams available');
    }
    final best = audio.first;
    return StreamInfo(
      url: best.url.toString(),
      container: best.container.name,
      audioCodec: best.audioCodec,
      contentLength: best.size.totalBytes,
    );
  }

  /// Returns a playable muxed (video+audio) URL for the music video.
  ///
  /// Falls back to the highest-quality video-only stream if no muxed stream
  /// exists (that variant has no audio track).
  Future<String?> resolveVideoUrl(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);
    final muxed = manifest.muxed.toList()
      ..sort((a, b) => b.size.totalBytes.compareTo(a.size.totalBytes));
    if (muxed.isNotEmpty) return muxed.first.url.toString();
    if (manifest.videoOnly.isNotEmpty) {
      return manifest.videoOnly
          .reduce((a, b) => b.size.totalBytes > a.size.totalBytes ? b : a)
          .url
          .toString();
    }
    return null;
  }

  /// Returns similar videos for autoplay ("radio").
  Future<List<Song>> related(Song song, {int limit = 15}) async {
    final query = '${song.artistNames} ${song.title}';
    final results = await _yt.search.search(query, filter: TypeFilters.video);
    final out = <Song>[];
    for (final v in results) {
      if (v.id.value == song.id) continue;
      out.add(
        Song(
          id: v.id.value,
          title: v.title,
          artistNames: v.author,
          thumbnailUrl: v.thumbnails.mediumResUrl,
          durationMs: v.duration?.inMilliseconds,
          isVideo: true,
        ),
      );
      if (out.length >= limit) break;
    }
    return out;
  }

  void dispose() => _yt.close();
}
