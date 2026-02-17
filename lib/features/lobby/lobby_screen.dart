import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:songrush_party/core/theme/app_theme.dart';
import 'package:songrush_party/features/party/party_controller.dart';
import 'package:songrush_party/models/party.dart';
import 'package:songrush_party/models/player.dart';

final partyStreamProvider = StreamProvider.family<Party?, String>((ref, id) {
  return ref.watch(supabaseServiceProvider).streamParty(id).map((event) {
    if (event.isEmpty) return null;
    return Party.fromMap(event.first);
  });
});

class LobbyScreen extends ConsumerStatefulWidget {
  final String partyId;
  final String playerId;

  const LobbyScreen({
    super.key, 
    required this.partyId,
    required this.playerId,
  });

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  
  @override
  Widget build(BuildContext context) {
    final supabaseService = ref.watch(supabaseServiceProvider);

    // Listen to party status changes
    ref.listen(
      partyStreamProvider(widget.partyId),
      (previous, next) {
        if (next.value != null && next.value!.status == 'playing') {
           // Navigate to Game Screen
           context.go('/game/${widget.partyId}/${widget.playerId}');
        }
      }
    );

    return Scaffold(
      appBar: AppBar(title: const Text('LOBBY')),
      body: Column(
        children: [
          // Header with Code
          Container(
            padding: const EdgeInsets.all(32),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              children: [
                const Text('PARTY CODE', style: TextStyle(color: Colors.white70, letterSpacing: 2)),
                const SizedBox(height: 8),
                StreamBuilder(
                  stream: supabaseService.streamParty(widget.partyId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
                    final party = snapshot.data!.first;
                    return Text(
                      party['code'],
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppTheme.neonPink, letterSpacing: 8),
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text('Warte auf Spieler...', style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabaseService.streamPlayers(widget.partyId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final players = snapshot.data!.map((data) => Player.fromMap(data)).toList();
                
                // Identify local player
                final localPlayer = players.firstWhere(
                  (p) => p.id == widget.playerId, 
                  orElse: () => players.first // Fallback if not found (shouldn't happen)
                );
                
                final isHost = localPlayer.isHost;

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: players.length,
                        itemBuilder: (context, index) {
                          final player = players[index];
                          return Card(
                            color: AppTheme.surface,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: player.isHost ? const BorderSide(color: AppTheme.neonBlue, width: 2) : BorderSide.none,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: player.isHost ? AppTheme.neonBlue : Colors.grey[800],
                                foregroundColor: Colors.white,
                                child: Icon(player.isHost ? Icons.star : Icons.person),
                              ),
                              title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              trailing: Text('${player.score} Pts', style: const TextStyle(color: Colors.white70)),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Start Button for Host
                    if (isHost)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () async {
                               try {
                                 // Start the game session: update party status to 'playing'
                                 // Rounds are started individually from the game screen
                                 await ref.read(supabaseServiceProvider).parties.update({
                                   'status': 'playing',
                                 }).eq('id', widget.partyId);
                               } catch (e) {
                                 if (context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text('Fehler beim Starten: $e')),
                                   );
                                 }
                               }
                            },
                            child: const Text('SPIEL STARTEN'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


