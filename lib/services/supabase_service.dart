import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService(this._client);

  SupabaseClient get client => _client;

  // Table getters
  SupabaseQueryBuilder get parties => _client.from('parties');
  SupabaseQueryBuilder get players => _client.from('players');
  SupabaseQueryBuilder get rounds => _client.from('rounds');
  SupabaseQueryBuilder get buzzers => _client.from('buzzers');

  // Stream party updates
  Stream<List<Map<String, dynamic>>> streamParty(String partyId) {
    return parties.stream(primaryKey: ['id']).eq('id', partyId);
  }

  // Stream players in a party
  Stream<List<Map<String, dynamic>>> streamPlayers(String partyId) {
    return players.stream(primaryKey: ['id']).eq('party_id', partyId).order('score', ascending: false);
  }
}
