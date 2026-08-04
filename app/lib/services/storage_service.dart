import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import '../models/download_entry.dart';
import '../models/song.dart';
import '../models/user_playlist.dart';

/// Thin persistence layer over Hive. Data is stored as JSON strings so no
/// codegen/adapters are required.
class StorageService {
  Box<String>? _likedBox;
  Box<String>? _playlistBox;
  Box<String>? _historyBox;
  Box<String>? _prefsBox;
  Box<String>? _downloadBox;
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
    _likedBox = await Hive.openBox<String>('gokenfy_liked');
    _playlistBox = await Hive.openBox<String>('gokenfy_playlists');
    _historyBox = await Hive.openBox<String>('gokenfy_history');
    _prefsBox = await Hive.openBox<String>('gokenfy_prefs');
    _downloadBox = await Hive.openBox<String>('gokenfy_downloads');
    _ready = true;
  }

  // -------------------------------------------------------------------------
  // Player preferences
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> loadPlayerPrefs() async {
    await _ensure();
    final raw = _prefsBox!.get('player');
    if (raw == null || raw.isEmpty) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  Future<void> savePlayerPrefs(Map<String, dynamic> prefs) async {
    await _ensure();
    await _prefsBox!.put('player', jsonEncode(prefs));
  }

  // Play counts (songId -> int), for smart playlists.
  Future<Map<String, int>> loadPlayCounts() async {
    await _ensure();
    final raw = _prefsBox!.get('playCounts');
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> savePlayCounts(Map<String, int> counts) async {
    await _ensure();
    await _prefsBox!.put('playCounts', jsonEncode(counts));
  }

  // -------------------------------------------------------------------------
  // Downloads (songId -> absolute file path)
  // -------------------------------------------------------------------------

  Future<Map<String, DownloadEntry>> loadDownloads() async {
    await _ensure();
    final raw = _downloadBox!.get('v');
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, DownloadEntry>{};
      map.forEach((k, v) {
        final data = (v is Map<String, dynamic>) ? v : <String, dynamic>{};
        final path = data['path'] as String?;
        final songJson = data['song'];
        Song? song;
        if (songJson is Map) {
          try {
            song = Song.fromJson(Map<String, dynamic>.from(songJson));
          } catch (_) {
            song = null;
          }
        }
        result[k] = DownloadEntry(
          songId: k,
          status: path == null ? DownloadStatus.none : DownloadStatus.done,
          filePath: path,
          song: song,
        );
      });
      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveDownloads(Map<String, DownloadEntry> downloads) async {
    await _ensure();
    final map = <String, dynamic>{};
    downloads.forEach((id, e) {
      map[id] = {
        'path': e.filePath,
        if (e.song != null) 'song': e.song!.toJson(),
      };
    });
    await _downloadBox!.put('v', jsonEncode(map));
  }

  // -------------------------------------------------------------------------
  // Liked songs
  // -------------------------------------------------------------------------

  Future<List<Song>> loadLiked() async {
    await _ensure();
    return _decodeSongs(_likedBox!.get('v'));
  }

  Future<void> saveLiked(List<Song> songs) async {
    await _ensure();
    await _likedBox!.put('v', _encodeSongs(songs));
  }

  // -------------------------------------------------------------------------
  // Playlists
  // -------------------------------------------------------------------------

  Future<List<UserPlaylist>> loadPlaylists() async {
    await _ensure();
    final raw = _playlistBox!.get('v');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((m) => UserPlaylist.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlaylists(List<UserPlaylist> playlists) async {
    await _ensure();
    await _playlistBox!.put(
      'v',
      jsonEncode(playlists.map((p) => p.toJson()).toList()),
    );
  }

  // -------------------------------------------------------------------------
  // History
  // -------------------------------------------------------------------------

  Future<List<Song>> loadHistory() async {
    await _ensure();
    return _decodeSongs(_historyBox!.get('v'));
  }

  Future<void> saveHistory(List<Song> songs) async {
    await _ensure();
    await _historyBox!.put('v', _encodeSongs(songs));
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static List<Song> _decodeSongs(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((m) => Song.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String _encodeSongs(List<Song> songs) =>
      jsonEncode(songs.map((s) => s.toJson()).toList());

  void dispose() {
    _likedBox?.close();
    _playlistBox?.close();
    _historyBox?.close();
    _prefsBox?.close();
    _downloadBox?.close();
  }
}
