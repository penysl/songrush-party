class Party {
  final String id;
  final String code;
  final String hostId;
  final String status;
  final String? currentRoundId;
  final DateTime createdAt;

  Party({
    required this.id,
    required this.code,
    required this.hostId,
    required this.status,
    this.currentRoundId,
    required this.createdAt,
  });

  factory Party.fromMap(Map<String, dynamic> map) {
    return Party(
      id: map['id'] as String,
      code: map['code'] as String,
      hostId: map['host_id'] as String,
      status: map['status'] as String,
      currentRoundId: map['current_round_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'host_id': hostId,
      'status': status,
      'current_round_id': currentRoundId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
