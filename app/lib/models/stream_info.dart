/// A resolved, playable audio stream for a [Song].
class StreamInfo {
  const StreamInfo({
    required this.url,
    this.container,
    this.audioCodec,
    this.contentLength,
    this.durationMs,
  });

  final String url;
  final String? container;
  final String? audioCodec;
  final int? contentLength;
  final int? durationMs;
}
