class LyricLine {
  const LyricLine({required this.text, this.offsetMs, this.endMs});

  /// The lyric text (one line, may be empty for instrumental gaps).
  final String text;

  /// Start time in the track, when synced lyrics are available.
  final int? offsetMs;

  /// End time in the track, when available.
  final int? endMs;

  @override
  bool operator ==(Object other) =>
      other is LyricLine &&
      other.text == text &&
      other.offsetMs == offsetMs &&
      other.endMs == endMs;

  @override
  int get hashCode => Object.hash(text, offsetMs, endMs);
}
