class Buzzer {
  final String id;
  final String roundId;
  final String playerId;
  final DateTime buzzedAt;

  Buzzer({
    required this.id,
    required this.roundId,
    required this.playerId,
    required this.buzzedAt,
  });

  factory Buzzer.fromMap(Map<String, dynamic> map) {
    return Buzzer(
      id: map['id'] as String,
      roundId: map['round_id'] as String,
      playerId: map['player_id'] as String,
      buzzedAt: DateTime.parse(map['buzzed_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'round_id': roundId,
      'player_id': playerId,
      'buzzed_at': buzzedAt.toIso8601String(),
    };
  }
}
