class Party {
  final String id;
  final String code;
  final String hostId;
  final String status;
  final String? currentRoundId;
  final String genre;
  final int currentPlayerIndex;
  final DateTime createdAt;
  final String? playlistId;
  final String? playlistName;

  Party({
    required this.id,
    required this.code,
    required this.hostId,
    required this.status,
    this.currentRoundId,
    this.genre = 'pop',
    this.currentPlayerIndex = 0,
    required this.createdAt,
    this.playlistId,
    this.playlistName,
  });

  factory Party.fromMap(Map<String, dynamic> map) {
    return Party(
      id: map['id'] as String,
      code: map['code'] as String,
      hostId: map['host_id'] as String,
      status: map['status'] as String,
      currentRoundId: map['current_round_id'] as String?,
      genre: (map['genre'] as String?) ?? 'pop',
      currentPlayerIndex: (map['current_player_index'] as int?) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      playlistId: map['playlist_id'] as String?,
      playlistName: map['playlist_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'host_id': hostId,
      'status': status,
      'current_round_id': currentRoundId,
      'genre': genre,
      'current_player_index': currentPlayerIndex,
      'created_at': createdAt.toIso8601String(),
      'playlist_id': playlistId,
      'playlist_name': playlistName,
    };
  }
}
