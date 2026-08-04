import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/download_entry.dart';
import '../models/song.dart';
import 'storage_service.dart';
import 'stream_resolver.dart';

/// Manages offline downloads: streaming resolved audio to local files.
class DownloadController extends StateNotifier<Map<String, DownloadEntry>> {
  DownloadController(this._resolver, {required StorageService storage})
    : _storage = storage,
      _http = http.Client(),
      super(const {}) {
    _load();
  }

  final StreamResolver _resolver;
  final StorageService _storage;
  final http.Client _http;

  Future<void> _load() async {
    final entries = await _storage.loadDownloads();
    final result = <String, DownloadEntry>{};
    entries.forEach((id, e) {
      if (e.filePath != null && File(e.filePath!).existsSync()) {
        result[id] = e;
      }
    });
    state = result;
  }

  String? pathFor(String songId) => state[songId]?.filePath;

  bool isDownloaded(String songId) => state[songId]?.isDone ?? false;

  Future<String> _downloadDir() async {
    final dir = await getApplicationSupportDirectory();
    final downloads = Directory('${dir.path}/downloads');
    if (!await downloads.exists()) await downloads.create(recursive: true);
    return downloads.path;
  }

  Future<void> download(Song song) async {
    if (isDownloaded(song.id)) return;
    state = {
      ...state,
      song.id: DownloadEntry(
        songId: song.id,
        status: DownloadStatus.downloading,
        song: song,
      ),
    };
    try {
      final info = await _resolver.resolve(song.id);
      final dir = await _downloadDir();
      final ext = info.container?.isNotEmpty == true ? info.container : 'mp4';
      final file = File('$dir/${song.id}.$ext');

      final request = http.Request('GET', Uri.parse(info.url));
      final response = await _http.send(request);
      if (response.statusCode != 200) {
        throw Exception('Download failed: ${response.statusCode}');
      }
      final total = info.contentLength ?? response.contentLength ?? 0;
      final sink = file.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0 && mounted) {
          final progress = (received / total).clamp(0.0, 1.0);
          state = {
            ...state,
            song.id: DownloadEntry(
              songId: song.id,
              status: DownloadStatus.downloading,
              progress: progress,
              song: song,
            ),
          };
        }
      }
      await sink.flush();
      await sink.close();
      if (mounted) {
        state = {
          ...state,
          song.id: DownloadEntry(
            songId: song.id,
            status: DownloadStatus.done,
            filePath: file.path,
            song: song,
          ),
        };
      }
      await _persist();
    } catch (e) {
      if (mounted) {
        state = {
          ...state,
          song.id: DownloadEntry(
            songId: song.id,
            status: DownloadStatus.failed,
            error: e.toString(),
            song: song,
          ),
        };
      }
    }
  }

  Future<void> remove(String songId) async {
    final entry = state[songId];
    if (entry?.filePath != null) {
      try {
        final f = File(entry!.filePath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    final next = Map<String, DownloadEntry>.from(state)..remove(songId);
    state = next;
    await _persist();
  }

  Future<void> removeAll() async {
    for (final e in state.values) {
      if (e.filePath != null) {
        try {
          final f = File(e.filePath!);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
    state = const {};
    await _persist();
  }

  Future<void> _persist() async {
    final entries = <String, DownloadEntry>{};
    state.forEach((id, e) {
      if (e.isDone && e.filePath != null) {
        entries[id] = e;
      }
    });
    await _storage.saveDownloads(entries);
  }

  void dispose() {
    _http.close();
    super.dispose();
  }
}
