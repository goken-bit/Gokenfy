class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    this.author,
    this.trackCount,
    this.thumbnailUrl,
  });

  final String id;
  final String title;
  final String? author;
  final int? trackCount;
  final String? thumbnailUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'trackCount': trackCount,
    'thumbnailUrl': thumbnailUrl,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    author: json['author'] as String?,
    trackCount: json['trackCount'] as int?,
    thumbnailUrl: json['thumbnailUrl'] as String?,
  );
}
