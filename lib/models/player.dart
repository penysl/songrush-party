class Player {
  final String id;
  final String partyId;
  final String name;
  final int score;
  final bool isHost;
  final DateTime joinedAt;

  Player({
    required this.id,
    required this.partyId,
    required this.name,
    required this.score,
    required this.isHost,
    required this.joinedAt,
  });

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] as String,
      partyId: map['party_id'] as String,
      name: map['name'] as String,
      score: map['score'] as int? ?? 0,
      isHost: map['is_host'] as bool? ?? false,
      joinedAt: DateTime.parse(map['created_at'] as String? ?? map['joined_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'party_id': partyId,
      'name': name,
      'score': score,
      'is_host': isHost,
      'created_at': joinedAt.toIso8601String(),
    };
  }
}
