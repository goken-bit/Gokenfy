class Album {
  const Album({
    required this.id,
    required this.title,
    this.artist,
    this.year,
    this.thumbnailUrl,
    this.trackCount,
  });

  final String id;
  final String title;
  final String? artist;
  final int? year;
  final String? thumbnailUrl;
  final int? trackCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'year': year,
    'thumbnailUrl': thumbnailUrl,
    'trackCount': trackCount,
  };

  factory Album.fromJson(Map<String, dynamic> json) => Album(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    artist: json['artist'] as String?,
    year: json['year'] as int?,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    trackCount: json['trackCount'] as int?,
  );
}
