class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.subscriberCount,
  });

  final String id;
  final String name;
  final String? thumbnailUrl;
  final String? subscriberCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'thumbnailUrl': thumbnailUrl,
    'subscriberCount': subscriberCount,
  };

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String?,
    subscriberCount: json['subscriberCount'] as String?,
  );
}
