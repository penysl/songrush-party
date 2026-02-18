class Round {
  final String id;
  final String partyId;
  final String spotifyTrackId;
  final String status; // playing, answered, finished
  final DateTime startedAt;
  final String? winnerId;
  final String? correctAnswer;
  final String? activePlayerId;
  final String? albumCoverUrl;
  final String? artistName;

  Round({
    required this.id,
    required this.partyId,
    required this.spotifyTrackId,
    required this.status,
    required this.startedAt,
    this.winnerId,
    this.correctAnswer,
    this.activePlayerId,
    this.albumCoverUrl,
    this.artistName,
  });

  factory Round.fromMap(Map<String, dynamic> map) {
    return Round(
      id: map['id'] as String,
      partyId: map['party_id'] as String,
      spotifyTrackId: map['spotify_track_id'] as String,
      status: map['status'] as String? ?? 'playing',
      startedAt: DateTime.parse(
        map['created_at'] as String? ??
            map['started_at'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      winnerId: map['winner_id'] as String?,
      correctAnswer: map['correct_answer'] as String?,
      activePlayerId: map['active_player_id'] as String?,
      albumCoverUrl: map['album_cover_url'] as String?,
      artistName: map['artist_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'party_id': partyId,
      'spotify_track_id': spotifyTrackId,
      'status': status,
      'created_at': startedAt.toIso8601String(),
      'winner_id': winnerId,
      'correct_answer': correctAnswer,
      'active_player_id': activePlayerId,
      'album_cover_url': albumCoverUrl,
      'artist_name': artistName,
    };
  }
}
