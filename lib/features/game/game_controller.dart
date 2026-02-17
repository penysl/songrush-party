import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songrush_party/core/utils/fuzzy_match.dart';
import 'package:songrush_party/features/party/party_controller.dart';
import 'package:songrush_party/models/buzzer.dart';
import 'package:songrush_party/models/round.dart';
import 'package:songrush_party/services/supabase_service.dart';

final gameControllerProvider = Provider((ref) {
  return GameController(ref.watch(supabaseServiceProvider));
});

// Stream provider for the current active round of a party
final currentRoundProvider = StreamProvider.family<Round?, String>((ref, partyId) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return supabaseService.rounds
      .stream(primaryKey: ['id'])
      .eq('party_id', partyId)
      .order('created_at', ascending: false)
      .limit(1)
      .map((data) => data.isEmpty ? null : Round.fromMap(data.first));
});

// Stream provider for the buzzer of a specific round
final roundBuzzerProvider = StreamProvider.family<Buzzer?, String>((ref, roundId) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return supabaseService.buzzers
      .stream(primaryKey: ['id'])
      .eq('round_id', roundId)
      .limit(1)
      .map((data) => data.isEmpty ? null : Buzzer.fromMap(data.first));
});


class GameController {
  final SupabaseService _supabaseService;

  GameController(this._supabaseService);

  /// Start a new round.
  /// [songTitle] is the correct answer for this round (entered by host).
  /// Later this will come from the Spotify track name.
  Future<void> startRound(String partyId, String songTitle) async {
    // 1. Create Round with correct answer
    final roundResponse = await _supabaseService.rounds.insert({
      'party_id': partyId,
      'spotify_track_id': 'spotify:track:mock_${DateTime.now().millisecondsSinceEpoch}',
      'status': 'playing',
      'correct_answer': songTitle,
    }).select().single();

    final round = Round.fromMap(roundResponse);

    // 2. Update Party with current round ID
    await _supabaseService.parties.update({
      'current_round_id': round.id,
      'status': 'playing',
    }).eq('id', partyId);
  }

  /// Attempt to buzz. Returns true if this player got the buzzer.
  Future<bool> buzz(String roundId, String playerId) async {
    try {
      await _supabaseService.buzzers.insert({
        'round_id': roundId,
        'player_id': playerId,
      });
      
      // Update round status to locked
      await _supabaseService.rounds.update({
        'status': 'buzzer_locked',
      }).eq('id', roundId);

      return true;
    } catch (e) {
      // Unique constraint violation = someone else buzzed first
      return false;
    }
  }

  /// Submit an answer. Returns a result with correct/incorrect info.
  Future<AnswerResult> submitAnswer({
    required String roundId,
    required String playerId,
    required String answer,
    required String correctAnswer,
  }) async {
    final isCorrect = FuzzyMatch.isMatch(answer, correctAnswer);
    final score = FuzzyMatch.similarity(answer, correctAnswer);

    if (isCorrect) {
      // 1. Award point to player
      await _awardPoint(playerId);

      // 2. Set winner and finish round
      await _supabaseService.rounds.update({
        'status': 'finished',
        'winner_id': playerId,
      }).eq('id', roundId);

      return AnswerResult(
        correct: true, 
        similarity: score,
        message: 'Richtig! 🎉',
      );
    } else {
      return AnswerResult(
        correct: false, 
        similarity: score,
        message: 'Falsch! ${(score * 100).toInt()}% Übereinstimmung',
      );
    }
  }

  /// After a wrong answer, reset the buzzer so the next player can try.
  Future<void> resetBuzzer(String roundId) async {
    // 1. Delete the buzzer entry
    await _supabaseService.buzzers.delete().eq('round_id', roundId);

    // 2. Set round back to playing
    await _supabaseService.rounds.update({
      'status': 'playing',
    }).eq('id', roundId);
  }

  /// End a round (timeout or skip). No winner.
  Future<void> endRound(String roundId) async {
    await _supabaseService.rounds.update({
      'status': 'finished',
    }).eq('id', roundId);
  }

  /// End the entire game and set party to finished.
  Future<void> endGame(String partyId) async {
    await _supabaseService.parties.update({
      'status': 'finished',
    }).eq('id', partyId);
  }

  /// Award +1 point to a player.
  Future<void> _awardPoint(String playerId) async {
    // Fetch current score and increment
    final playerData = await _supabaseService.players
        .select('score')
        .eq('id', playerId)
        .single();
    
    final currentScore = playerData['score'] as int;
    
    await _supabaseService.players.update({
      'score': currentScore + 1,
    }).eq('id', playerId);
  }
}

/// Result of an answer submission.
class AnswerResult {
  final bool correct;
  final double similarity;
  final String message;

  AnswerResult({
    required this.correct,
    required this.similarity,
    required this.message,
  });
}
