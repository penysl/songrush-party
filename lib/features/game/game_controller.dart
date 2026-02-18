import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songrush_party/core/utils/fuzzy_match.dart';
import 'package:songrush_party/features/party/party_controller.dart';
import 'package:songrush_party/models/round.dart';
import 'package:songrush_party/services/spotify_service.dart';
import 'package:songrush_party/services/supabase_service.dart';

final gameControllerProvider = Provider((ref) {
  return GameController(
    ref.watch(supabaseServiceProvider),
    ref.watch(spotifyServiceProvider),
  );
});

/// Stream of the current (latest) round for a party.
final currentRoundProvider = StreamProvider.family<Round?, String>((ref, partyId) {
  return ref
      .watch(supabaseServiceProvider)
      .rounds
      .stream(primaryKey: ['id'])
      .eq('party_id', partyId)
      .order('created_at', ascending: false)
      .limit(1)
      .map((data) => data.isEmpty ? null : Round.fromMap(data.first));
});

class GameController {
  final SupabaseService _db;
  final SpotifyService _spotify;

  GameController(this._db, this._spotify);

  // ──────────────────────────────────────────
  // START ROUND
  // ──────────────────────────────────────────

  /// Start a new round:
  /// - Determines the active player from party.current_player_index
  /// - Fetches a random track for the party's genre
  /// - Creates the round in DB
  /// - Plays the track on the host's Spotify device
  Future<void> startRound(String partyId) async {
    // 1. Fetch party data
    final partyData = await _db.parties
        .select('genre, current_player_index')
        .eq('id', partyId)
        .single();

    final genre = (partyData['genre'] as String?) ?? 'Pop';
    final playerIndex = (partyData['current_player_index'] as int?) ?? 0;

    // 2. Fetch players ordered by join time to determine who's up
    final playersData = await _db.players
        .select('id')
        .eq('party_id', partyId)
        .order('joined_at', ascending: true);

    if (playersData.isEmpty) return;
    final activePlayerId =
        playersData[playerIndex % playersData.length]['id'] as String;

    // 3. Get a random Spotify track for the genre
    final track = await _spotify.getRandomTrackForGenre(genre);

    // 4. Create round in DB
    final roundData = await _db.rounds.insert({
      'party_id': partyId,
      'spotify_track_id': track['spotifyUri'] as String,
      'status': 'playing',
      'correct_answer': track['name'] as String,
      'active_player_id': activePlayerId,
      'album_cover_url': track['albumCoverUrl'] as String?,
      'artist_name': track['artistName'] as String,
    }).select().single();

    final round = Round.fromMap(roundData);

    // 5. Update party: set current round
    await _db.parties.update({
      'current_round_id': round.id,
    }).eq('id', partyId);

    // 6. Play on host's Spotify device
    await _spotify.playTrack(track['spotifyUri'] as String);
  }

  // ──────────────────────────────────────────
  // SUBMIT ANSWER
  // ──────────────────────────────────────────

  /// Validate the player's answer using fuzzy matching.
  /// Pauses playback, updates round status, awards point if correct.
  Future<AnswerResult> submitAnswer({
    required String roundId,
    required String playerId,
    required String answer,
    required String correctAnswer,
  }) async {
    final isCorrect = FuzzyMatch.isMatch(answer, correctAnswer);
    final similarity = FuzzyMatch.similarity(answer, correctAnswer);

    // Pause playback regardless of result
    try {
      await _spotify.pausePlayback();
    } catch (_) {
      // Don't fail submission if pause fails
    }

    if (isCorrect) {
      await _awardPoint(playerId);
      await _db.rounds.update({
        'status': 'answered',
        'winner_id': playerId,
      }).eq('id', roundId);
    } else {
      await _db.rounds.update({
        'status': 'answered',
      }).eq('id', roundId);
    }

    return AnswerResult(
      correct: isCorrect,
      similarity: similarity,
    );
  }

  // ──────────────────────────────────────────
  // NEXT ROUND / SKIP
  // ──────────────────────────────────────────

  /// Advance to the next player and mark the current round as finished.
  Future<void> nextRound(String partyId, String currentRoundId) async {
    // Fetch current player index and player count
    final partyData = await _db.parties
        .select('current_player_index')
        .eq('id', partyId)
        .single();

    final currentIndex = (partyData['current_player_index'] as int?) ?? 0;

    final playersData =
        await _db.players.select('id').eq('party_id', partyId);
    final playerCount = playersData.length;

    final nextIndex = playerCount > 0 ? (currentIndex + 1) % playerCount : 0;

    // Update party: advance turn, clear current round
    await _db.parties.update({
      'current_player_index': nextIndex,
      'current_round_id': null,
    }).eq('id', partyId);

    // Mark round as finished
    await _db.rounds.update({
      'status': 'finished',
    }).eq('id', currentRoundId);
  }

  /// Skip the current round without guessing (host action).
  Future<void> skipRound(String partyId, String currentRoundId) async {
    try {
      await _spotify.pausePlayback();
    } catch (_) {}
    await nextRound(partyId, currentRoundId);
  }

  // ──────────────────────────────────────────
  // END GAME
  // ──────────────────────────────────────────

  Future<void> endGame(String partyId) async {
    try {
      await _spotify.pausePlayback();
    } catch (_) {}
    await _db.parties.update({'status': 'finished'}).eq('id', partyId);
  }

  // ──────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────

  Future<void> _awardPoint(String playerId) async {
    final playerData =
        await _db.players.select('score').eq('id', playerId).single();
    final currentScore = (playerData['score'] as int?) ?? 0;
    await _db.players
        .update({'score': currentScore + 1}).eq('id', playerId);
  }
}

/// Result of an answer submission.
class AnswerResult {
  final bool correct;
  final double similarity;

  AnswerResult({required this.correct, required this.similarity});
}
