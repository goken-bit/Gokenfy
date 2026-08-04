import '../models/song.dart';

enum GRepeat { off, all, one }

enum GShuffle { off, on }

/// Serializable player UI state.
class GPlayerState {
  const GPlayerState({
    this.queue = const [],
    this.index,
    this.playing = false,
    this.buffering = false,
    this.processing = false,
    this.hasError = false,
    this.position = Duration.zero,
    this.duration,
    this.repeat = GRepeat.off,
    this.shuffle = GShuffle.off,
    this.speed = 1.0,
    this.volume = 1.0,
    this.autoplay = false,
    this.crossfade = false,
    this.sleepTimerRemaining,
  });

  final List<Song> queue;
  final int? index;
  final bool playing;
  final bool buffering;
  final bool processing;
  final bool hasError;
  final Duration position;
  final Duration? duration;
  final GRepeat repeat;
  final GShuffle shuffle;
  final double speed;
  final double volume;
  final bool autoplay;
  final bool crossfade;

  /// Remaining time before the sleep timer fires (null = disabled).
  final Duration? sleepTimerRemaining;

  Song? get current => (index != null && index! >= 0 && index! < queue.length)
      ? queue[index!]
      : null;

  bool get isEmpty => queue.isEmpty;

  double? get progress {
    final d = duration;
    if (d == null || d.inMilliseconds == 0) return null;
    return (position.inMilliseconds / d.inMilliseconds).clamp(0.0, 1.0);
  }

  GPlayerState copyWith({
    List<Song>? queue,
    int? index,
    bool? playing,
    bool? buffering,
    bool? processing,
    bool? hasError,
    Duration? position,
    Duration? duration,
    GRepeat? repeat,
    GShuffle? shuffle,
    double? speed,
    double? volume,
    bool? autoplay,
    bool? crossfade,
    Duration? sleepTimerRemaining,
    bool clearIndex = false,
    bool clearDuration = false,
    bool clearSleepTimer = false,
  }) {
    return GPlayerState(
      queue: queue ?? this.queue,
      index: clearIndex ? null : (index ?? this.index),
      playing: playing ?? this.playing,
      buffering: buffering ?? this.buffering,
      processing: processing ?? this.processing,
      hasError: hasError ?? this.hasError,
      position: position ?? this.position,
      duration: clearDuration ? null : (duration ?? this.duration),
      repeat: repeat ?? this.repeat,
      shuffle: shuffle ?? this.shuffle,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      autoplay: autoplay ?? this.autoplay,
      crossfade: crossfade ?? this.crossfade,
      sleepTimerRemaining: clearSleepTimer
          ? null
          : (sleepTimerRemaining ?? this.sleepTimerRemaining),
    );
  }
}
