import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/player_state.dart';
import '../models/song.dart';
import 'storage_service.dart';
import 'stream_resolver.dart';

/// Wraps just_audio + StreamResolver and exposes playback state.
class PlayerController extends StateNotifier<GPlayerState> {
  PlayerController(
    this._resolver, {
    StorageService? storage,
    void Function(Song song)? onTrackStarted,
    Future<String?> Function(String songId)? resolveCachedPath,
  }) : _storage = storage,
       _resolveCachedPath = resolveCachedPath,
       _onTrackStarted = onTrackStarted,
       _player = AudioPlayer(),
       super(const GPlayerState()) {
    _init();
  }

  final StreamResolver _resolver;
  final StorageService? _storage;
  final Future<String?> Function(String songId)? _resolveCachedPath;
  final AudioPlayer _player;
  final void Function(Song song)? _onTrackStarted;
  final Random _rand = Random();
  final List<StreamSubscription<dynamic>> _subs = [];

  bool _handlingComplete = false;

  Timer? _sleepTimer;
  DateTime? _sleepEnd;
  static const Duration _fadeWindow = Duration(seconds: 5);

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // Best-effort.
    }
    _subs.add(_player.playerStateStream.listen(_onPlayback));
    _subs.add(_player.positionStream.listen(_onPosition));
    _subs.add(
      _player.durationStream.listen((d) {
        if (!mounted) return;
        state = state.copyWith(duration: d);
      }),
    );
    await _restorePrefs();
  }

  Future<void> _restorePrefs() async {
    final prefs = await _storage?.loadPlayerPrefs();
    if (prefs == null || !mounted) return;
    final speed = (prefs['speed'] as num?)?.toDouble() ?? 1.0;
    final volume = (prefs['volume'] as num?)?.toDouble() ?? 1.0;
    final autoplay = prefs['autoplay'] as bool? ?? false;
    final crossfade = prefs['crossfade'] as bool? ?? false;
    await _player.setSpeed(speed);
    await _player.setVolume(volume);
    state = state.copyWith(
      speed: speed,
      volume: volume,
      autoplay: autoplay,
      crossfade: crossfade,
    );
  }

  Future<void> _persist() async {
    final prefs = {
      'speed': state.speed,
      'volume': state.volume,
      'autoplay': state.autoplay,
      'crossfade': state.crossfade,
    };
    await _storage?.savePlayerPrefs(prefs);
  }

  void _onPlayback(PlayerState ps) {
    if (!mounted) return;
    state = state.copyWith(
      playing: ps.playing,
      buffering: ps.processingState == ProcessingState.buffering,
      processing: ps.processingState == ProcessingState.loading,
      position: _player.position,
    );
    if (ps.processingState == ProcessingState.completed && !_handlingComplete) {
      _handlingComplete = true;
      _onTrackComplete();
      _handlingComplete = false;
    }
  }

  void _onPosition(Duration p) {
    if (!mounted) return;
    final dur = state.duration ?? Duration.zero;
    if (state.crossfade &&
        state.playing &&
        dur.inSeconds > 0 &&
        (dur - p) <= _fadeWindow &&
        (dur - p) > Duration.zero) {
      final remainingMs = (dur - p).inMilliseconds;
      final fadeMs = _fadeWindow.inMilliseconds;
      final target = state.volume * (remainingMs / fadeMs).clamp(0.0, 1.0);
      _player.setVolume(target.clamp(0.0, 1.0));
    }
    state = state.copyWith(position: p);
  }

  // ---------------------------------------------------------------------------
  // Core playback
  // ---------------------------------------------------------------------------

  Future<void> playSong(List<Song> queue, int index) async {
    if (queue.isEmpty || index < 0 || index >= queue.length) return;
    state = state.copyWith(
      queue: List.of(queue),
      index: index,
      playing: false,
      buffering: false,
      processing: true,
      hasError: false,
      position: Duration.zero,
      clearDuration: true,
    );
    await _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final song = state.current;
    if (song == null) return;
    try {
      state = state.copyWith(processing: true, hasError: false);
      await _player.setVolume(state.volume);

      final cachedPath = await _resolveCachedPath?.call(song.id);
      if (cachedPath != null && File(cachedPath).existsSync()) {
        await _player.setAudioSource(
          AudioSource.file(cachedPath, tag: _mediaItem(song)),
        );
      } else {
        final info = await _resolver.resolve(song.id);
        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(info.url), tag: _mediaItem(song)),
        );
      }
      await _player.play();
      _onTrackStarted?.call(song);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(processing: false, hasError: true, playing: false);
    }
  }

  MediaItem _mediaItem(Song song) => MediaItem(
    id: song.id,
    title: song.title,
    artist: song.artistNames,
    album: song.album,
    artUri: song.thumbnailUrl != null && song.thumbnailUrl!.isNotEmpty
        ? Uri.tryParse(song.thumbnailUrl!)
        : null,
  );

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    state = state.copyWith(
      index: index,
      playing: false,
      buffering: false,
      processing: true,
      hasError: false,
      position: Duration.zero,
      clearDuration: true,
    );
    await _loadCurrent();
  }

  Future<void> togglePlay() async {
    if (state.isEmpty) return;
    if (state.hasError) {
      await _loadCurrent();
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> seek(Duration position) async {
    if (state.isEmpty) return;
    await _player.seek(position);
    state = state.copyWith(position: position);
  }

  Future<void> next() async {
    final n = _nextIndex();
    if (n < 0) {
      await _stopAtEnd();
      return;
    }
    await _playIndex(n);
  }

  Future<void> previous() async {
    if (state.isEmpty) return;
    if (state.position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    final i = state.index ?? 0;
    if (i > 0) {
      await _playIndex(i - 1);
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> _stopAtEnd() async {
    await _player.stop();
    state = state.copyWith(playing: false, position: Duration.zero);
  }

  int _nextIndex() {
    final q = state.queue;
    if (q.isEmpty) return -1;
    final i = state.index ?? -1;
    if (state.shuffle == GShuffle.on) {
      if (q.length == 1) return 0;
      var j = _rand.nextInt(q.length);
      if (j == i) j = (j + 1) % q.length;
      return j;
    }
    if (i + 1 < q.length) return i + 1;
    return state.repeat == GRepeat.all ? 0 : -1;
  }

  Future<void> _onTrackComplete() async {
    if (state.repeat == GRepeat.one) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    final n = _nextIndex();
    if (n >= 0) {
      await _playIndex(n);
      return;
    }
    // Queue exhausted.
    if (state.autoplay && state.current != null) {
      await _autoplayContinue();
      return;
    }
    state = state.copyWith(playing: false, position: Duration.zero);
  }

  Future<void> _autoplayContinue() async {
    final song = state.current;
    if (song == null) return;
    try {
      state = state.copyWith(processing: true);
      final similar = await _resolver.related(song);
      final queue = List.of(state.queue)
        ..removeWhere((s) => s.id == song.id)
        ..addAll(similar);
      state = state.copyWith(queue: queue);
      await _playIndex(queue.length - similar.length);
    } catch (_) {
      state = state.copyWith(processing: false, playing: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Speed / volume / autoplay / crossfade
  // ---------------------------------------------------------------------------

  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    await _player.setSpeed(clamped);
    state = state.copyWith(speed: clamped);
    await _persist();
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _player.setVolume(clamped);
    state = state.copyWith(volume: clamped);
    await _persist();
  }

  Future<void> toggleAutoplay() async {
    state = state.copyWith(autoplay: !state.autoplay);
    await _persist();
  }

  Future<void> toggleCrossfade() async {
    state = state.copyWith(crossfade: !state.crossfade);
    if (!state.crossfade) {
      await _player.setVolume(state.volume);
    }
    await _persist();
  }

  // ---------------------------------------------------------------------------
  // Sleep timer
  // ---------------------------------------------------------------------------

  Future<void> startSleepTimer(Duration duration) async {
    _sleepTimer?.cancel();
    _sleepEnd = DateTime.now().add(duration);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _sleepEnd!.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _sleepTimer?.cancel();
        _player.pause();
        state = state.copyWith(playing: false, clearSleepTimer: true);
      } else {
        state = state.copyWith(sleepTimerRemaining: remaining);
      }
    });
    state = state.copyWith(sleepTimerRemaining: duration);
  }

  Future<void> cancelSleepTimer() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepEnd = null;
    state = state.copyWith(clearSleepTimer: true);
  }

  String sleepTimerLabel() {
    final remaining = state.sleepTimerRemaining;
    if (remaining == null) return 'Off';
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  // ---------------------------------------------------------------------------
  // Queue management
  // ---------------------------------------------------------------------------

  Future<void> skipTo(int index) async {
    if (index < 0 || index >= state.queue.length || index == state.index) {
      return;
    }
    await _playIndex(index);
  }

  Future<void> playNext(Song song) async {
    final q = List.of(state.queue);
    final i = state.index ?? 0;
    q.insert(i + 1, song);
    state = state.copyWith(queue: q);
  }

  Future<void> addToQueue(Song song) async {
    state = state.copyWith(queue: List.of(state.queue)..add(song));
  }

  Future<void> removeAt(int index) async {
    if (state.queue.isEmpty || index < 0 || index >= state.queue.length) {
      return;
    }
    final q = List.of(state.queue);
    q.removeAt(index);
    final currentIndex = state.index ?? 0;
    if (index == currentIndex) {
      await _player.stop();
      if (q.isEmpty) {
        state = state.copyWith(
          queue: q,
          playing: false,
          clearIndex: true,
          position: Duration.zero,
          clearDuration: true,
        );
      } else {
        final nextIndex = currentIndex < q.length ? currentIndex : q.length - 1;
        state = state.copyWith(queue: q);
        await _playIndex(nextIndex);
      }
    } else {
      state = state.copyWith(
        queue: q,
        index: index < currentIndex ? currentIndex - 1 : currentIndex,
      );
    }
  }

  Future<void> move(int from, int to) async {
    if (from < 0 ||
        to < 0 ||
        from >= state.queue.length ||
        to >= state.queue.length) {
      return;
    }
    final q = List.of(state.queue);
    final song = q.removeAt(from);
    q.insert(to, song);
    final i = state.index ?? 0;
    int newIndex = i;
    if (from == i) {
      newIndex = to;
    } else if (from < i && to >= i) {
      newIndex = i - 1;
    } else if (from > i && to <= i) {
      newIndex = i + 1;
    }
    state = state.copyWith(queue: q, index: newIndex);
  }

  Future<void> clearQueue() async {
    await _player.stop();
    state = state.copyWith(
      queue: const [],
      playing: false,
      clearIndex: true,
      position: Duration.zero,
      clearDuration: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Modes
  // ---------------------------------------------------------------------------

  Future<void> cycleRepeat() async {
    state = state.copyWith(
      repeat: switch (state.repeat) {
        GRepeat.off => GRepeat.all,
        GRepeat.all => GRepeat.one,
        GRepeat.one => GRepeat.off,
      },
    );
  }

  Future<void> toggleShuffle() async {
    state = state.copyWith(
      shuffle: state.shuffle == GShuffle.on ? GShuffle.off : GShuffle.on,
    );
  }

  void dispose() {
    _sleepTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}
