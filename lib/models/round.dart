class Round {
  final String id;
  final String partyId;
  final String spotifyTrackId;
  final String status; // playing, buzzer_locked, answered, finished
  final DateTime startedAt;
  final String? winnerId;
  final String? correctAnswer;

  Round({
    required this.id,
    required this.partyId,
    required this.spotifyTrackId,
    required this.status,
    required this.startedAt,
    this.winnerId,
    this.correctAnswer,
  });

  factory Round.fromMap(Map<String, dynamic> map) {
    return Round(
      id: map['id'] as String,
      partyId: map['party_id'] as String,
      spotifyTrackId: map['spotify_track_id'] as String,
      status: map['status'] as String? ?? 'playing',
      startedAt: DateTime.parse(map['created_at'] as String? ?? map['started_at'] as String? ?? DateTime.now().toIso8601String()),
      winnerId: map['winner_id'] as String?,
      correctAnswer: map['correct_answer'] as String?,
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
    };
  }
}
