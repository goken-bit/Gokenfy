import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/stream_info.dart';
import 'stream_resolver.dart';

/// Serves a resolved YouTube stream to just_audio through a local HTTP
/// server.
///
/// YouTube's CDN now returns 403 for plain GETs and open-ended `Range:
/// bytes=0-` requests (the patterns ExoPlayer uses by default). It only
/// accepts bounded range requests. This proxy accepts whatever range
/// ExoPlayer asks for and forwards it to YouTube as a series of bounded
/// range requests, re-resolving the stream URL whenever the CDN answers
/// with 403.
class StreamProxy {
  StreamProxy(this._resolver);

  final StreamResolver _resolver;

  static const int _chunk = 256 * 1024;

  HttpServer? _server;
  StreamInfo? _info;
  String? _videoId;
  int _total = 0;

  /// Starts the proxy and returns the base URL to hand to just_audio.
  Future<String> serve(String videoId) async {
    await _refreshInfo(videoId);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle);
    return 'http://127.0.0.1:${server.port}/stream';
  }

  Future<void> _refreshInfo(String videoId) async {
    _videoId = videoId;
    _info = await _resolver.resolve(videoId);
    _total = _info?.contentLength ?? 0;
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final range = request.headers.value('range');
      var start = 0;
      if (range != null && range.startsWith('bytes=')) {
        final match = RegExp(r'bytes=(\d+)-').firstMatch(range);
        if (match != null) start = int.tryParse(match.group(1)!) ?? 0;
      }
      final end = _total - 1;
      final response = request.response;
      response.statusCode = HttpStatus.partialContent;
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$_total',
      );
      response.headers.set(HttpHeaders.contentLengthHeader, '${_total - start}');
      await _streamFrom(start, response);
      await response.close();
    } catch (_) {
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _streamFrom(int start, HttpResponse response) async {
    var offset = start;
    while (offset < _total) {
      final chunkEnd = (offset + _chunk - 1).clamp(0, _total - 1);
      final bytes = await _fetch(offset, chunkEnd);
      if (bytes == null) break;
      response.add(bytes);
      offset = chunkEnd + 1;
    }
  }

  Future<List<int>?> _fetch(int start, int end) async {
    var attempts = 0;
    while (attempts < 5) {
      final info = _info;
      if (info == null) return null;
      try {
        final response = await http
            .get(
              Uri.parse(info.url),
              headers: {
                'Range': 'bytes=$start-$end',
                'Connection': 'close',
              },
            )
            .timeout(const Duration(seconds: 25));
        if (response.statusCode == 206) return response.bodyBytes;
        if (response.statusCode == 403) {
          final videoId = _videoId;
          if (videoId != null) await _refreshInfo(videoId);
          attempts++;
          continue;
        }
        return null;
      } catch (_) {
        final videoId = _videoId;
        if (videoId != null) await _refreshInfo(videoId);
        attempts++;
      }
    }
    return null;
  }

  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
  }
}
