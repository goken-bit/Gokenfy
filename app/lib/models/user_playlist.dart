import 'song.dart';

/// A playlist the user created locally.
class UserPlaylist {
  UserPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.folder,
    DateTime? createdAt,
    List<Song>? songs,
  }) : createdAt = createdAt ?? DateTime.now(),
       songs = songs ?? [];

  final String id;
  String name;
  String? description;
  String? folder;
  final DateTime createdAt;
  final List<Song> songs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'folder': folder,
    'createdAt': createdAt.toIso8601String(),
    'songs': songs.map((s) => s.toJson()).toList(),
  };

  factory UserPlaylist.fromJson(Map<String, dynamic> json) => UserPlaylist(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    folder: json['folder'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    songs: (json['songs'] as List? ?? [])
        .whereType<Map>()
        .map((m) => Song.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
  );

  UserPlaylist copyWith({
    String? name,
    String? description,
    String? folder,
    List<Song>? songs,
    bool clearFolder = false,
  }) => UserPlaylist(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    folder: clearFolder ? null : (folder ?? this.folder),
    createdAt: createdAt,
    songs: songs ?? List.of(this.songs),
  );
}
