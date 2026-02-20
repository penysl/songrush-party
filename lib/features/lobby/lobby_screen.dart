import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:songrush_party/core/theme/app_theme.dart';
import 'package:songrush_party/features/party/party_controller.dart';
import 'package:songrush_party/models/party.dart';
import 'package:songrush_party/models/player.dart';
import 'package:songrush_party/services/spotify_service.dart';

final partyStreamProvider = StreamProvider.family<Party?, String>((ref, id) {
  return ref.watch(supabaseServiceProvider).streamParty(id).map((event) {
    if (event.isEmpty) return null;
    return Party.fromMap(event.first);
  });
});

/// Tracks whether the host has connected to Spotify in this session.
final spotifyConnectedProvider = StateProvider<bool>((ref) => false);

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
  bool _connectingSpotify = false;

  @override
  Widget build(BuildContext context) {
    final supabaseService = ref.watch(supabaseServiceProvider);
    final spotifyConnected = ref.watch(spotifyConnectedProvider);

    // Navigate to game screen when party status changes to 'playing'
    ref.listen(
      partyStreamProvider(widget.partyId),
      (previous, next) {
        if (next.value != null && next.value!.status == 'playing') {
          context.go('/game/${widget.partyId}/${widget.playerId}');
        }
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text('LOBBY')),
      body: Column(
        children: [
          // Header with party code
          Container(
            padding: const EdgeInsets.all(32),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Column(
              children: [
                const Text(
                  'PARTY CODE',
                  style: TextStyle(color: Colors.white70, letterSpacing: 2),
                ),
                const SizedBox(height: 8),
                StreamBuilder(
                  stream: supabaseService.streamParty(widget.partyId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SizedBox();
                    }
                    final party = snapshot.data!.first;
                    return Text(
                      party['code'] as String,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.neonPink,
                        letterSpacing: 8,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Warte auf Spieler...',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),

          // Player list + host controls
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabaseService.streamPlayers(widget.partyId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Fehler: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final players =
                    snapshot.data!.map((d) => Player.fromMap(d)).toList();
                final localPlayer = players.firstWhere(
                  (p) => p.id == widget.playerId,
                  orElse: () => players.first,
                );
                final isHost = localPlayer.isHost;

                return Column(
                  children: [
                    // Player list
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
                              side: player.isHost
                                  ? const BorderSide(
                                      color: AppTheme.neonBlue, width: 2)
                                  : BorderSide.none,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: player.isHost
                                    ? AppTheme.neonBlue
                                    : Colors.grey[800],
                                foregroundColor: Colors.white,
                                child: Icon(
                                    player.isHost ? Icons.star : Icons.person),
                              ),
                              title: Text(
                                player.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              trailing: Text(
                                '${player.score} Pts',
                                style:
                                    const TextStyle(color: Colors.white70),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Host-only controls
                    if (isHost) ...[
                      _GenreSelector(partyId: widget.partyId),
                      _SpotifyConnectButton(
                        connected: spotifyConnected,
                        connecting: _connectingSpotify,
                        onConnect: () => _connectSpotify(),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: spotifyConnected
                                ? () => _startGame()
                                : null,
                            child: const Text('SPIEL STARTEN'),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectSpotify() async {
    setState(() => _connectingSpotify = true);
    try {
      final connected =
          await ref.read(spotifyServiceProvider).connectToSpotify();
      if (mounted) {
        ref.read(spotifyConnectedProvider.notifier).state = connected;
        if (!connected) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 6),
              content: Text(
                'Verbindung fehlgeschlagen. Bitte öffne die Spotify App zuerst und stelle sicher, dass du Spotify Premium hast.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connectingSpotify = false);
    }
  }

  Future<void> _startGame() async {
    try {
      await ref.read(supabaseServiceProvider).parties.update({
        'status': 'playing',
      }).eq('id', widget.partyId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Starten: $e')),
        );
      }
    }
  }
}

// ──────────────────────────────────────────
// Genre Selector
// ──────────────────────────────────────────

class _GenreSelector extends ConsumerWidget {
  final String partyId;

  const _GenreSelector({required this.partyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GENRE WÄHLEN',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: ref
                .watch(supabaseServiceProvider)
                .streamParty(partyId),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox();
              }
              final currentGenre =
                  (snapshot.data!.first['genre'] as String?) ?? 'Pop';

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kSpotifyGenres.keys.map((label) {
                  final isSelected = currentGenre == label;
                  return ChoiceChip(
                    label: Text(label),
                    selected: isSelected,
                    selectedColor: AppTheme.neonPink,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    backgroundColor: AppTheme.surface,
                    onSelected: (_) async {
                      await ref
                          .read(supabaseServiceProvider)
                          .parties
                          .update({'genre': label})
                          .eq('id', partyId);
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// Spotify Connect Button
// ──────────────────────────────────────────

class _SpotifyConnectButton extends StatelessWidget {
  final bool connected;
  final bool connecting;
  final VoidCallback onConnect;

  const _SpotifyConnectButton({
    required this.connected,
    required this.connecting,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: connected || connecting ? null : onConnect,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: connected ? Colors.green : AppTheme.neonBlue,
              width: 2,
            ),
          ),
          icon: connecting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  connected ? Icons.check_circle : Icons.music_note,
                  color: connected ? Colors.green : AppTheme.neonBlue,
                ),
          label: Text(
            connected ? 'Spotify verbunden' : 'Spotify verbinden',
            style: TextStyle(
              color: connected ? Colors.green : AppTheme.neonBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
