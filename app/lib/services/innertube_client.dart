import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/album.dart';
import '../models/artist.dart';
import '../models/artist_page.dart';
import '../models/lyric_line.dart';
import '../models/playlist.dart';
import '../models/search_results.dart';
import '../models/song.dart';

/// Central place to tweak innertube client params if YouTube changes things.
class InnertubeConfig {
  InnertubeConfig._();

  static const String musicBase = 'https://music.youtube.com/youtubei/v1';
  static const String webBase = 'https://www.youtube.com/youtubei/v1';
  static const String musicKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
  static const String clientName = 'WEB_REMIX';
  static const String clientVersion = '1.20240725.01.00';
  static const String hl = 'en';
  static const String gl = 'US';
}

/// Direct client for YouTube's innertube API (same protocol yt-dlp uses).
class InnertubeClient {
  InnertubeClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final http.Client _http;

  void dispose() => _http.close();

  // ---------------------------------------------------------------------------
  // Requests
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _context() => {
    'context': {
      'client': {
        'clientName': InnertubeConfig.clientName,
        'clientVersion': InnertubeConfig.clientVersion,
        'hl': InnertubeConfig.hl,
        'gl': InnertubeConfig.gl,
      },
    },
  };

  Future<Map<String, dynamic>> _post(
    String base,
    String endpoint,
    Map<String, dynamic> body, {
    String? key,
  }) async {
    final uri = Uri.parse('$base/$endpoint').replace(
      queryParameters: key != null
          ? {'key': key, 'prettyPrint': 'false'}
          : null,
    );
    final response = await _http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent':
                'com.google.android.apps.youtube.music/7.01 (Linux; U; Android 14)',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('innertube ${response.statusCode}: ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  Future<SearchResults> search(String query, {int limit = 20}) async {
    final root = await _post(InnertubeConfig.musicBase, 'search', {
      ..._context(),
      'query': query,
    }, key: InnertubeConfig.musicKey);

    final results = SearchResults(
      songs: [],
      videos: [],
      albums: [],
      artists: [],
      playlists: [],
      channels: [],
    );
    try {
      final items = _collectItems(root);
      for (final item in items) {
        if (results.total >= limit && results.songs.length >= 15) break;
        final parsed = _parseListItem(item);
        if (parsed == null) continue;
        _dispatch(results, parsed);
      }
    } catch (_) {
      // Malformed responses are still partially usable.
    }
    return results;
  }

  /// Convenience: returns only the song hits for [query].
  Future<List<Song>> songs(String query, {int limit = 12}) async {
    final results = await search(query, limit: limit + 5);
    final songs = results.songs;
    return songs.take(limit).toList();
  }

  /// Fetches an artist page: header info, top songs and release carousels.
  Future<ArtistPage> artistPage(String channelId) async {
    final root = await _post(InnertubeConfig.musicBase, 'browse', {
      ..._context(),
      'browseId': channelId,
    }, key: InnertubeConfig.musicKey);

    final header = root['header']?['musicImmersiveHeaderRenderer'];
    final name = _runsText(header?['title']) ?? '';
    final thumbnail = _extractThumb(header?['thumbnail']);
    final monthly = _runsText(header?['monthlyListenerCount']);

    final sections = _at(root, [
      'contents',
      'singleColumnBrowseResultsRenderer',
      'tabs',
      0,
      'tabRenderer',
      'content',
      'sectionListRenderer',
      'contents',
    ]);

    final topSongs = <Song>[];
    final albums = <Album>[];
    final singles = <Album>[];
    String? about;

    if (sections is List) {
      for (final sec in sections) {
        if (sec is! Map) continue;
        final shelf = sec['musicShelfRenderer'];
        if (shelf is Map) {
          final items = shelf['contents'];
          if (items is List) {
            for (final item in items) {
              if (item is! Map) continue;
              final lr = item['musicResponsiveListItemRenderer'];
              if (lr is! Map) continue;
              final parsed = _parseListItem(lr);
              if (parsed is Song && !parsed.isVideo) topSongs.add(parsed);
            }
          }
          continue;
        }
        final carousel = sec['musicCarouselShelfRenderer'];
        if (carousel is Map) {
          final carTitle =
              _runsText(
                carousel['header']
                    ?['musicCarouselShelfBasicHeaderRenderer']?['title'],
              )?.toLowerCase() ??
              '';
          final items = carousel['contents'];
          if (items is List) {
            final list = <Album>[];
            for (final item in items) {
              if (item is! Map) continue;
              final tr = item['musicTwoRowItemRenderer'];
              if (tr is! Map) continue;
              final browse =
                  tr['navigationEndpoint']?['browseEndpoint'];
              final browseId = _asString(browse?['browseId']);
              if (browseId == null || !browseId.startsWith('MPREb_')) {
                continue;
              }
              final subtitle = _runsText(tr['subtitle']) ?? '';
              list.add(
                Album(
                  id: browseId,
                  title: _runsText(tr['title']) ?? '',
                  artist: name,
                  year: int.tryParse(subtitle.replaceAll(RegExp(r'[^\d]'), '')),
                  thumbnailUrl: _extractThumb(tr['thumbnailRenderer']),
                ),
              );
            }
            if (carTitle.contains('album')) {
              albums.addAll(list);
            } else if (carTitle.contains('single')) {
              singles.addAll(list);
            }
          }
          continue;
        }
        final desc = sec['musicDescriptionShelfRenderer'];
        if (desc is Map) {
          about = _runsText(desc['description']);
        }
      }
    }

    return ArtistPage(
      artist: Artist(id: channelId, name: name, thumbnailUrl: thumbnail),
      monthlyListeners: monthly,
      topSongs: topSongs,
      albums: albums,
      singles: singles,
      about: about,
    );
  }

  /// Returns the track list for an album (browseId like `MPREb_...`).
  Future<List<Song>> albumSongs(String browseId) async {
    final root = await _post(InnertubeConfig.musicBase, 'browse', {
      ..._context(),
      'browseId': browseId,
    }, key: InnertubeConfig.musicKey);

    final items = _at(root, [
      'contents',
      'twoColumnBrowseResultsRenderer',
      'secondaryContents',
      'sectionListRenderer',
      'contents',
      0,
      'musicShelfRenderer',
      'contents',
    ]);

    final songs = <Song>[];
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        final lr = item['musicResponsiveListItemRenderer'];
        if (lr is! Map) continue;
        final parsed = _parseListItem(lr);
        if (parsed is Song) songs.add(parsed);
      }
    }
    return songs;
  }

  // ---------------------------------------------------------------------------
  // Lyrics
  // ---------------------------------------------------------------------------

  /// Fetches synced lyrics for a track (timed segments from YT Music).
  ///
  /// YouTube Music no longer exposes lyrics through the old
  /// `getTranscriptEndpoint`/`get_transcript` flow. It now serves them as a
  /// browse page: `next` returns a "Lyrics" tab with an `MPLYt...` browseId,
  /// and browsing that id (with the Android client) returns timed segments.
  Future<List<LyricLine>> lyrics(String videoId) async {
    final next = await _post(InnertubeConfig.musicBase, 'next', {
      ..._context(),
      'enablePersistentPlaylistPanel': true,
      'isAudioOnly': true,
      'tunerSettingValue': 'AUTOMIX_SETTING_NORMAL',
      'videoId': videoId,
      'playlistId': 'RDAMVM$videoId',
      'watchEndpointMusicSupportedConfigs': {
        'watchEndpointMusicConfig': {
          'hasPersistentPlaylistPanel': true,
          'musicVideoType': 'MUSIC_VIDEO_TYPE_ATV',
        },
      },
    }, key: InnertubeConfig.musicKey);

    final browseId = _findLyricsBrowseId(next);
    if (browseId == null) return const [];

    // Timed lyrics are only returned to the Android (mobile) client.
    final browse = await _post(
      InnertubeConfig.musicBase,
      'browse',
      {..._androidContext(), 'browseId': browseId},
      key: InnertubeConfig.musicKey,
    );

    final data = _at(browse, [
      'contents',
      'elementRenderer',
      'newElement',
      'type',
      'componentType',
      'model',
      'timedLyricsModel',
      'lyricsData',
      'timedLyricsData',
    ]);
    if (data is! List || data.isEmpty) {
      // No timed segments from the Android client — try static lyrics from the
      // web client (a plain multi-line description shelf).
      return _parseStaticLyrics(browseId);
    }

    final out = <LyricLine>[];
    for (final seg in data) {
      if (seg is! Map) continue;
      final text = _asString(seg['lyricLine'])?.trim();
      if (text == null || text.isEmpty) continue;
      final cue = seg['cueRange'];
      if (cue is! Map) continue;
      final start = int.tryParse('${cue['startTimeMilliseconds']}');
      if (start == null) continue;
      out.add(
        LyricLine(
          text: text,
          offsetMs: start,
          endMs: int.tryParse('${cue['endTimeMilliseconds']}'),
        ),
      );
    }
    return out;
  }

  /// Fetches static (untimed) lyrics from the web client's browse page.
  Future<List<LyricLine>> _parseStaticLyrics(String browseId) async {
    final web = await _post(
      InnertubeConfig.musicBase,
      'browse',
      {..._context(), 'browseId': browseId},
      key: InnertubeConfig.musicKey,
    );
    final shelf = _at(web, [
      'contents',
      'sectionListRenderer',
      'contents',
      0,
      'musicDescriptionShelfRenderer',
    ]);
    if (shelf is! Map) return const [];
    final text = _runsText(shelf['description']);
    if (text == null) return const [];
    return text
        .split('\n')
        .map((line) => LyricLine(text: line.trim()))
        .where((l) => l.text.isNotEmpty)
        .toList();
  }

  /// Finds the selectable "Lyrics" tab browseId (`MPLYt...`) in a `next`
  /// response. Tabs marked `unselectable` mean lyrics are not available.
  String? _findLyricsBrowseId(Map<String, dynamic> root) {
    final tabs = _at(root, [
      'contents',
      'singleColumnMusicWatchNextResultsRenderer',
      'tabbedRenderer',
      'watchNextTabbedResultsRenderer',
      'tabs',
    ]);
    if (tabs is! List) return null;
    for (final tab in tabs) {
      if (tab is! Map) continue;
      final renderer = tab['tabRenderer'];
      if (renderer is! Map<String, dynamic>) continue;
      if (renderer.containsKey('unselectable')) continue;
      final browse = _at(renderer, ['endpoint', 'browseEndpoint']);
      if (browse is! Map<String, dynamic>) continue;
      final pageType = _at(browse, [
        'browseEndpointContextSupportedConfigs',
        'browseEndpointContextMusicConfig',
        'pageType',
      ]);
      if (pageType != 'MUSIC_PAGE_TYPE_TRACK_LYRICS') continue;
      final browseId = _asString(browse['browseId']);
      if (browseId != null && browseId.startsWith('MPLYt_')) return browseId;
    }
    return null;
  }

  /// Android client context; timed lyrics are only served to this client.
  Map<String, dynamic> _androidContext() => {
    'context': {
      'client': {
        'clientName': 'ANDROID_MUSIC',
        'clientVersion': '7.21.50',
        'hl': InnertubeConfig.hl,
        'gl': InnertubeConfig.gl,
      },
    },
  };

  /// Gather every list item from any section layout YouTube currently emits.
  List<Map<String, dynamic>> _collectItems(Map<String, dynamic> root) {
    final contents = _at(root, [
      'contents',
      'tabbedSearchResultsRenderer',
      'tabs',
      0,
      'tabRenderer',
      'content',
      'sectionListRenderer',
      'contents',
    ]);
    final items = <Map<String, dynamic>>[];
    if (contents is! List) return items;

    for (final section in contents) {
      if (section is! Map) continue;
      for (final entry in section.entries) {
        final renderer = entry.value;
        if (renderer is! Map) continue;
        final subContents = renderer['contents'];
        if (subContents is! List) continue;
        for (final raw in subContents) {
          if (raw is Map && raw['musicResponsiveListItemRenderer'] is Map) {
            items.add(
              raw['musicResponsiveListItemRenderer'] as Map<String, dynamic>,
            );
          }
        }
      }
    }
    return items;
  }

  void _dispatch(SearchResults out, dynamic item) {
    if (item is Song) {
      if (item.isVideo) {
        out.videos.add(item);
      } else {
        out.songs.add(item);
      }
    } else if (item is Album) {
      out.albums.add(item);
    } else if (item is Playlist) {
      out.playlists.add(item);
    } else if (item is Artist) {
      out.artists.add(item);
    }
  }

  // ---------------------------------------------------------------------------
  // List item parsing (current innertube format)
  // ---------------------------------------------------------------------------

  dynamic _parseListItem(Map<String, dynamic> lr) {
    try {
      final flex = lr['flexColumns'];
      if (flex is! List || flex.isEmpty) return null;

      final t0 = _flexText(flex, 0);
      final t1 = _flexText(flex, 1) ?? '';
      final t2 = _flexText(flex, 2);
      if (t0 == null) return null;

      final thumbnail = _extractThumb(lr['thumbnail']);
      final playlistItemData = lr['playlistItemData'];
      final pld = playlistItemData is Map
          ? _asString(playlistItemData['videoId'])
          : null;
      final isExplicit = lr['badges'] is List;

      final marker = _marker(t1);
      final runNav = _flexRunNav(flex, 0);
      final watch =
          runNav['watchEndpoint'] ?? lr['navigationEndpoint']?['watchEndpoint'];
      final browse =
          runNav['browseEndpoint'] ??
          lr['navigationEndpoint']?['browseEndpoint'];

      switch (marker) {
        case 'Song':
          final videoId = pld ?? _asString(watch?['videoId']);
          if (videoId == null) return null;
          return Song(
            id: videoId,
            title: t0,
            artistNames: _afterMarker(t1),
            artists: _flexArtists(flex, 1),
            thumbnailUrl: thumbnail,
            durationMs: _durationToMs(t1),
            isExplicit: isExplicit,
            playlistId: _asString(watch?['playlistId']),
          );

        case 'Video':
          final videoId = pld ?? _asString(watch?['videoId']);
          if (videoId == null) return null;
          return Song(
            id: videoId,
            title: t0,
            artistNames: _afterMarker(t1),
            artists: _flexArtists(flex, 1),
            thumbnailUrl: thumbnail,
            durationMs: _durationToMs(t1),
            isVideo: true,
            playlistId: _asString(watch?['playlistId']),
          );

        case 'Artist':
          final browseId = _asString(browse?['browseId']);
          if (browseId == null) return null;
          return Artist(
            id: browseId,
            name: t0,
            thumbnailUrl: thumbnail,
            subscriberCount: _afterMarker(t1),
          );

        case 'Album':
        case 'Single':
          final browseId = _asString(browse?['browseId']);
          if (browseId == null) return null;
          return Album(
            id: browseId,
            title: t0,
            artist: _albumArtist(t1),
            year: _yearOf(t1),
            thumbnailUrl: thumbnail,
            trackCount: null,
          );

        case 'Playlist':
          final browseId = _asString(browse?['browseId']);
          if (browseId == null) return null;
          return Playlist(
            id: browseId,
            title: t0,
            author: _playlistAuthor(t1),
            trackCount: _playlistTrackCount(t1),
            thumbnailUrl: thumbnail,
          );

        default:
          // Top-result card: no marker prefix, decide from navigation.
          if (watch is Map || pld != null) {
            final videoId = pld ?? _asString(watch?['videoId']);
            if (videoId == null) return null;
            final isVideo = t1.contains('views');
            return Song(
              id: videoId,
              title: t0,
              artistNames: _artistFromTopCard(t1),
              thumbnailUrl: thumbnail,
              durationMs: _durationToMs(t1),
              isVideo: isVideo,
              playlistId: _asString(watch?['playlistId']),
            );
          }
          if (browse is Map) {
            final browseId = _asString(browse['browseId']);
            if (browseId == null) return null;
            if (browseId.startsWith('MPREb_')) {
              return Album(
                id: browseId,
                title: t0,
                artist: _albumArtist(t1),
                year: _yearOf(t1),
                thumbnailUrl: thumbnail,
              );
            }
            if (browseId.startsWith('VL')) {
              return Playlist(
                id: browseId,
                title: t0,
                author: _playlistAuthor(t1),
                trackCount: _playlistTrackCount(t1),
                thumbnailUrl: thumbnail,
              );
            }
            if (browseId.startsWith('UC')) {
              return Artist(
                id: browseId,
                name: t0,
                thumbnailUrl: thumbnail,
                subscriberCount: null,
              );
            }
          }
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  String _marker(String t1) {
    final trimmed = t1.trimLeft();
    if (trimmed.startsWith('Song ')) return 'Song';
    if (trimmed.startsWith('Video ')) return 'Video';
    if (trimmed.startsWith('Artist ')) return 'Artist';
    if (trimmed.startsWith('Album ')) return 'Album';
    if (trimmed.startsWith('Single ')) return 'Single';
    if (trimmed.startsWith('Playlist ')) return 'Playlist';
    return 'Unknown';
  }

  /// Text after the type marker, e.g. "Song • Rihanna" -> "Rihanna".
  String _afterMarker(String t1) {
    final marker = _marker(t1);
    if (marker == 'Unknown') return '';
    final rest = t1.substring(marker.length).trim();
    return rest.replaceFirst(RegExp(r'^•\s*'), '').trim();
  }

  String _albumArtist(String t1) {
    final rest = _afterMarker(t1);
    final parts = rest
        .split('•')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isEmpty ? '' : parts.first;
  }

  int? _yearOf(String t1) {
    final match = RegExp(r'\b(19|20)\d{2}\b').firstMatch(t1);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  String? _playlistAuthor(String t1) {
    final rest = _afterMarker(t1);
    final parts = rest
        .split('•')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.first;
  }

  int? _playlistTrackCount(String t1) {
    final match = RegExp(r'(\d+)\s+(songs?|tracks?)\b').firstMatch(t1);
    if (match != null) return int.tryParse(match.group(1) ?? '');
    return null;
  }

  /// For top-result songs the subtitle is "Artist • 29M views • 3:07".
  String _artistFromTopCard(String t1) {
    final parts = t1
        .split('•')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isEmpty ? '' : parts.first;
  }

  int? _durationToMs(String? text) {
    if (text == null) return null;
    final match = RegExp(r'(?:(\d+):)?(\d+):(\d{2})').firstMatch(text);
    if (match == null) return null;
    final h = int.tryParse(match.group(1) ?? '') ?? 0;
    final m = int.tryParse(match.group(2) ?? '') ?? 0;
    final s = int.tryParse(match.group(3) ?? '') ?? 0;
    return ((h * 3600) + (m * 60) + s) * 1000;
  }

  String? _flexText(List<dynamic> flex, int index) {
    if (flex.length <= index) return null;
    final col = flex[index];
    if (col is! Map) return null;
    final text = col['musicResponsiveListItemFlexColumnRenderer']?['text'];
    return _runsText(text);
  }

  Map<String, dynamic> _flexRunNav(List<dynamic> flex, int index) {
    try {
      final col = flex[index];
      final runs =
          col['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
      if (runs is! List) return const {};
      for (final run in runs) {
        if (run is Map && run['navigationEndpoint'] is Map) {
          return (run['navigationEndpoint'] as Map).cast<String, dynamic>();
        }
      }
    } catch (_) {
      return const {};
    }
    return const {};
  }

  /// Collects artists from a flex column whose runs carry browse endpoints.
  List<Artist> _flexArtists(List<dynamic> flex, int index) {
    try {
      final col = flex[index];
      final runs =
          col['musicResponsiveListItemFlexColumnRenderer']?['text']?['runs'];
      if (runs is! List) return const [];
      final out = <Artist>[];
      for (final run in runs) {
        if (run is! Map) continue;
        final text = run['text'];
        if (text is! String || text.trim().isEmpty) continue;
        final nav = run['navigationEndpoint'];
        if (nav is! Map) continue;
        final browse = nav['browseEndpoint'];
        if (browse is! Map) continue;
        final id = browse['browseId'];
        if (id is String && id.startsWith('UC')) {
          out.add(Artist(id: id, name: text.trim()));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  String? _runsText(dynamic text) {
    if (text is! Map) return null;
    final runs = text['runs'];
    if (runs is! List) return null;
    final buf = StringBuffer();
    for (final run in runs) {
      if (run is Map) buf.write(run['text'] ?? '');
    }
    final s = buf.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? _extractThumb(dynamic thumb) {
    try {
      final thumbnails =
          thumb['musicThumbnailRenderer']?['thumbnail']?['thumbnails'];
      if (thumbnails is! List || thumbnails.isEmpty) return null;
      final urls = thumbnails
          .whereType<Map>()
          .map((t) => t['url'])
          .whereType<String>()
          .toList();
      return urls.isEmpty ? null : urls.last;
    } catch (_) {
      return null;
    }
  }

  String? _asString(dynamic v) => v is String ? v : null;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static dynamic _at(Map<String, dynamic> root, List<Object> path) {
    dynamic node = root;
    for (final key in path) {
      if (node is Map) {
        node = node[key];
      } else if (node is List && key is int) {
        if (key >= node.length) return null;
        node = node[key];
      } else {
        return null;
      }
    }
    return node;
  }
}
