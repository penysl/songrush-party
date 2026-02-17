import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:songrush_party/core/theme/app_theme.dart';
import 'package:songrush_party/features/party/party_controller.dart';
import 'package:songrush_party/models/player.dart';

class ScoreboardScreen extends ConsumerWidget {
  final String partyId;
  final String playerId;

  const ScoreboardScreen({
    super.key,
    required this.partyId,
    required this.playerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseService = ref.watch(supabaseServiceProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              const Color(0xFF1A1A2E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Header
              const Text(
                'GAME OVER',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.neonPink,
                  letterSpacing: 4,
                ),
              ),
              const Text(
                'FINAL RANKING',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 40),

              // Ranking List
              Expanded(
                child: StreamBuilder(
                  stream: supabaseService.streamPlayers(partyId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final players = snapshot.data!.map((d) => Player.fromMap(d)).toList();
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final player = players[index];
                        final isMe = player.id == playerId;
                        final isWinner = index == 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isWinner 
                                ? AppTheme.neonPink.withValues(alpha: 0.1) 
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isWinner 
                                  ? AppTheme.neonPink 
                                  : (isMe ? AppTheme.neonBlue : Colors.transparent),
                              width: 2,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isWinner ? AppTheme.neonPink : Colors.grey[800],
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            title: Text(
                              player.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                color: isWinner ? AppTheme.neonPink : Colors.white,
                              ),
                            ),
                            trailing: Text(
                              '${player.score} Pts',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.neonBlue,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Back Home Button
              Padding(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () => context.go('/'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'ZURÜCK ZUM HAUPTMENÜ',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
