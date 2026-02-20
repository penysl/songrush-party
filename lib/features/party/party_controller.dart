import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songrush_party/models/party.dart';
import 'package:songrush_party/models/player.dart';
import 'package:songrush_party/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService(Supabase.instance.client);
});

final partyControllerProvider = StateNotifierProvider<PartyController, AsyncValue<Party?>>((ref) {
  return PartyController(ref.watch(supabaseServiceProvider));
});

class PartyController extends StateNotifier<AsyncValue<Party?>> {
  final SupabaseService _supabaseService;

  PartyController(this._supabaseService) : super(const AsyncData(null));

  // Generate a random 6-digit code
  String _generatePartyCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      6,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }

  // Create a new party
  Future<Player?> createParty(String hostName) async {
    debugPrint('DEBUG: createParty called for $hostName');
    state = const AsyncLoading();
    try {
      final code = _generatePartyCode();
      final hostId = const Uuid().v4(); 
      debugPrint('DEBUG: Generated code: $code, hostId: $hostId');

      // 1. Create Party
      final partyResponse = await _supabaseService.parties.insert({
        'code': code,
        'host_id': hostId,
        'status': 'lobby',
      }).select().single();
      debugPrint('DEBUG: Party created: $partyResponse');

      final party = Party.fromMap(partyResponse);

      // 2. Add Host as Player
      final playerResponse = await _supabaseService.players.insert({
        'party_id': party.id,
        'name': hostName,
        'is_host': true,
      }).select().single();
      debugPrint('DEBUG: Player (Host) added: $playerResponse');

      final player = Player.fromMap(playerResponse);

      // 3. Update Party with real Host Player ID
      await _supabaseService.parties.update({
        'host_id': player.id,
      }).eq('id', party.id);
      debugPrint('DEBUG: Party host_id updated to: ${player.id}');

      state = AsyncData(party);
      return player;
    } catch (e, stack) {
      debugPrint('DEBUG: createParty error: $e');
      debugPrint('DEBUG: Stacktrace: $stack');
      state = AsyncError(e, stack);
      rethrow; // Rethrow so the UI can catch it and show SnackBar
    }
  }

  // Join an existing party
  Future<Player?> joinParty(String code, String playerName) async {
    debugPrint('DEBUG: joinParty called for $playerName with code $code');
    state = const AsyncLoading();
    try {
      // 1. Find party
      final partyResponse = await _supabaseService.parties
          .select()
          .eq('code', code.toUpperCase())
          .maybeSingle();

      debugPrint('DEBUG: JoinParty find party response: $partyResponse');

      if (partyResponse == null) {
        throw Exception('Party not found');
      }

      final party = Party.fromMap(partyResponse);

      if (party.status != 'lobby') {
        throw Exception('Party already started or finished');
      }

      // 2. Add as Player
      final playerResponse = await _supabaseService.players.insert({
        'party_id': party.id,
        'name': playerName,
        'is_host': false,
      }).select().single();

      debugPrint('DEBUG: JoinParty player added response: $playerResponse');

      final player = Player.fromMap(playerResponse);

      state = AsyncData(party);
      return player;
    } catch (e, stack) {
      debugPrint('DEBUG: joinParty error: $e');
      debugPrint('DEBUG: JoinParty stacktrace: $stack');
      state = AsyncError(e, stack);
      rethrow;
    }
  }
  
  // Leave party / Reset state
  void leaveParty() {
    state = const AsyncData(null);
  }
}
