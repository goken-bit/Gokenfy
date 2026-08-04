import 'song.dart';

enum DownloadStatus { none, downloading, done, failed }

class DownloadEntry {
  const DownloadEntry({
    required this.songId,
    this.status = DownloadStatus.none,
    this.progress = 0,
    this.filePath,
    this.error,
    this.song,
  });

  final String songId;
  final DownloadStatus status;
  final double progress;
  final String? filePath;
  final String? error;
  final Song? song;

  bool get isDone => status == DownloadStatus.done;
  bool get isDownloading => status == DownloadStatus.downloading;

  @override
  bool operator ==(Object other) =>
      other is DownloadEntry &&
      other.songId == songId &&
      other.status == status &&
      other.progress == progress &&
      other.filePath == filePath &&
      other.error == error &&
      other.song == song;

  @override
  int get hashCode =>
      Object.hash(songId, status, progress, filePath, error, song);
}
