import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:songrush_party/core/theme/app_theme.dart';
import 'package:songrush_party/features/game/game_controller.dart';
import 'package:songrush_party/features/party/party_controller.dart';
import 'package:songrush_party/models/party.dart';
import 'package:songrush_party/models/round.dart';
import 'package:songrush_party/services/spotify_service.dart';

class GameScreen extends ConsumerWidget {
  final String partyId;
  final String playerId;

  const GameScreen({
    super.key,
    required this.partyId,
    required this.playerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partyStream =
        ref.watch(supabaseServiceProvider).streamParty(partyId);

    return Scaffold(
      body: StreamBuilder(
        stream: partyStream,
        builder: (context, partySnapshot) {
          if (partySnapshot.hasError) {
            return const Center(
              child: Text(
                'Verbindung verloren',
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
            );
          }
          if (!partySnapshot.hasData || partySnapshot.data!.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final party = Party.fromMap(partySnapshot.data!.first);

          if (party.status == 'finished') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/scoreboard/$partyId/$playerId');
            });
            return const Center(child: CircularProgressIndicator());
          }

          final playerStream = ref
              .watch(supabaseServiceProvider)
              .players
              .stream(primaryKey: ['id'])
              .eq('id', playerId)
              .limit(1);

          final roundAsync = ref.watch(currentRoundProvider(partyId));

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: playerStream,
            builder: (context, playerSnapshot) {
              final isHost = playerSnapshot.hasData &&
                  playerSnapshot.data!.isNotEmpty &&
                  playerSnapshot.data!.first['is_host'] == true;

              return roundAsync.when(
                data: (round) {
                  final Widget view;
                  final String viewKey;

                  if (round == null || round.status == RoundStatus.finished) {
                    viewKey = 'waiting';
                    view = _WaitingView(
                      key: const ValueKey('waiting'),
                      partyId: partyId,
                      playerId: playerId,
                      isHost: isHost,
                    );
                  } else if (round.status == RoundStatus.answered) {
                    viewKey = 'reveal-${round.id}';
                    view = _RevealView(
                      key: ValueKey(viewKey),
                      party: party,
                      round: round,
                      playerId: playerId,
                      isHost: isHost,
                    );
                  } else {
                    viewKey = 'active-${round.id}';
                    view = _ActiveRoundView(
                      key: ValueKey(viewKey),
                      party: party,
                      round: round,
                      playerId: playerId,
                      isHost: isHost,
                    );
                  }

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: view,
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Fehler: $e')),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// WAITING VIEW — Between rounds
// ============================================================

class _WaitingView extends ConsumerWidget {
  final String partyId;
  final String playerId;
  final bool isHost;

  const _WaitingView({
    super.key,
    required this.partyId,
    required this.playerId,
    required this.isHost,
  });

  Color _rankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silber
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return Colors.grey[800]!;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseService = ref.watch(supabaseServiceProvider);

    return SafeArea(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: const Column(
              children: [
                Icon(Icons.music_note, size: 48, color: AppTheme.neonPink),
                SizedBox(height: 8),
                Text(
                  'NÄCHSTE RUNDE',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Live scoreboard (sorted by score)
          Expanded(
            child: StreamBuilder(
              stream: supabaseService.streamPlayers(partyId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final players = List<Map<String, dynamic>>.from(snapshot.data!);
                players.sort((a, b) =>
                    ((b['score'] as int?) ?? 0)
                        .compareTo((a['score'] as int?) ?? 0));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final p = players[index];
                    final isMe = p['id'] == playerId;
                    final rank = index + 1;
                    return Card(
                      color: AppTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isMe
                            ? const BorderSide(
                                color: AppTheme.neonBlue, width: 2)
                            : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _rankColor(rank),
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: rank <= 3 ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                        title: Text(
                          p['name'] as String,
                          style: TextStyle(
                            fontWeight: isMe
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${p['score']} Pts',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.neonPink,
                              ),
                            ),
                            if (p['is_host'] == true) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.star,
                                  size: 16, color: AppTheme.neonBlue),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Host controls
          if (isHost)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: _StartRoundButton(partyId: partyId),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800]),
                      onPressed: () => ref
                          .read(gameControllerProvider)
                          .endGame(partyId),
                      child: const Text('BEENDEN'),
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Warte auf Host...',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _StartRoundButton extends ConsumerStatefulWidget {
  final String partyId;
  const _StartRoundButton({required this.partyId});

  @override
  ConsumerState<_StartRoundButton> createState() => _StartRoundButtonState();
}

class _StartRoundButtonState extends ConsumerState<_StartRoundButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _start,
      child: _loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('RUNDE STARTEN'),
            ),
    );
  }

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      await ref.read(gameControllerProvider).startRound(widget.partyId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ============================================================
// ACTIVE ROUND VIEW — Song is playing, player must guess
// ============================================================

class _ActiveRoundView extends ConsumerWidget {
  final Party party;
  final Round round;
  final String playerId;
  final bool isHost;

  const _ActiveRoundView({
    super.key,
    required this.party,
    required this.round,
    required this.playerId,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActivePlayer = round.activePlayerId == playerId;

    return Column(
      children: [
        // Header: song is playing indicator
        SafeArea(
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.graphic_eq,
                    color: AppTheme.neonPink, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'SONG LÄUFT...',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 16,
                  ),
                ),
                if (isHost) ...[
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline,
                        color: Colors.white70),
                    onPressed: () =>
                        ref.read(spotifyServiceProvider).pausePlayback(),
                    tooltip: 'Pause',
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white70),
                    onPressed: () => ref
                        .read(gameControllerProvider)
                        .skipRound(party.id, round.id),
                    tooltip: 'Überspringen',
                  ),
                ],
              ],
            ),
          ),
        ),

        Expanded(
          child: isActivePlayer
              ? _GuessInputView(round: round, playerId: playerId)
              : isHost
                  ? _HostWatchView(round: round)
                  : _OtherPlayerWaitView(round: round),
        ),
      ],
    );
  }
}

// ── Active player: input field (no timer) ────────────────────

class _GuessInputView extends ConsumerStatefulWidget {
  final Round round;
  final String playerId;

  const _GuessInputView({required this.round, required this.playerId});

  @override
  ConsumerState<_GuessInputView> createState() => _GuessInputViewState();
}

class _GuessInputViewState extends ConsumerState<_GuessInputView> {
  final _controller = TextEditingController();
  bool _submitted = false;

  Future<void> _submit() async {
    final answer = _controller.text.trim();
    if (answer.isEmpty || _submitted) return;
    setState(() => _submitted = true);

    await ref.read(gameControllerProvider).submitAnswer(
          roundId: widget.round.id,
          playerId: widget.playerId,
          answer: answer,
          correctAnswer: widget.round.correctAnswer ?? '',
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Antwort wird geprüft...',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pulsing music icon instead of timer
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1.15),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            builder: (context, scale, child) => Transform.scale(
              scale: scale,
              child: child,
            ),
            onEnd: () => setState(() {}), // retrigger animation
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.neonBlue, width: 3),
                color: AppTheme.neonBlue.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.headphones,
                size: 48,
                color: AppTheme.neonBlue,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'DU BIST DRAN!',
            style: TextStyle(
              fontSize: 24,
              color: AppTheme.neonPink,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hör gut zu und rate den Songnamen',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Wie heißt der Song?',
              labelText: 'Deine Antwort',
              prefixIcon: Icon(Icons.edit),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('SENDEN'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Host watching view ────────────────────────────────────────

class _HostWatchView extends StatelessWidget {
  final Round round;
  const _HostWatchView({required this.round});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (round.albumCoverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  round.albumCoverUrl!,
                  width: 180,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 24),
            const Icon(Icons.hearing, size: 48, color: AppTheme.neonBlue),
            const SizedBox(height: 12),
            const Text(
              'Spieler hört zu...',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Other players waiting view ────────────────────────────────

class _OtherPlayerWaitView extends ConsumerWidget {
  final Round round;
  const _OtherPlayerWaitView({required this.round});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerStream = round.activePlayerId != null
        ? ref
            .watch(supabaseServiceProvider)
            .players
            .stream(primaryKey: ['id'])
            .eq('id', round.activePlayerId!)
            .limit(1)
        : null;

    if (playerStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: playerStream,
      builder: (context, snapshot) {
        final name = snapshot.hasData && snapshot.data!.isNotEmpty
            ? snapshot.data!.first['name'] as String
            : '...';

        return Stack(
          fit: StackFit.expand,
          children: [
            // Blurred album cover as background (if available)
            if (round.albumCoverUrl != null) ...[
              Image.network(
                round.albumCoverUrl!,
                fit: BoxFit.cover,
              ),
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ],
            // Foreground content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (round.albumCoverUrl == null)
                    const Icon(Icons.music_note,
                        size: 72, color: Colors.white24),
                  if (round.albumCoverUrl == null)
                    const SizedBox(height: 24),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.neonBlue,
                      shadows: [
                        Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2))
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ist dran',
                    style: TextStyle(fontSize: 20, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================
// REVEAL VIEW — Show answer after guess
// ============================================================

class _RevealView extends ConsumerWidget {
  final Party party;
  final Round round;
  final String playerId;
  final bool isHost;

  const _RevealView({
    super.key,
    required this.party,
    required this.round,
    required this.playerId,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWinner = round.winnerId == playerId;
    final isActivePlayer = round.activePlayerId == playerId;
    final correct = round.winnerId != null;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Result icon
              Icon(
                correct ? Icons.check_circle : Icons.cancel,
                size: 80,
                color: correct ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 16),

              // Correct / Wrong label (shown to active player)
              if (isActivePlayer)
                Text(
                  correct ? 'RICHTIG!' : 'FALSCH!',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: correct ? Colors.green : Colors.red,
                  ),
                ),

              if (!isActivePlayer) ...[
                if (!correct)
                  const Text(
                    'Leider falsch...',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  )
                else
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: ref
                        .watch(supabaseServiceProvider)
                        .players
                        .stream(primaryKey: ['id'])
                        .eq('id', round.activePlayerId ?? '')
                        .limit(1),
                    builder: (context, snapshot) {
                      final name =
                          snapshot.hasData && snapshot.data!.isNotEmpty
                              ? snapshot.data!.first['name'] as String
                              : '...';
                      return Text(
                        '$name hat es gewusst!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      );
                    },
                  ),
              ],

              const SizedBox(height: 24),

              // Album cover
              if (round.albumCoverUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    round.albumCoverUrl!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 20),

              // Song title
              Text(
                round.correctAnswer ?? '',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              if (round.artistName != null) ...[
                const SizedBox(height: 4),
                Text(
                  round.artistName!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              if (correct && isWinner) ...[
                const SizedBox(height: 16),
                const Text(
                  '+1 Punkt!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.neonBlue,
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Only host can proceed
              if (isHost)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _NextRoundButton(
                    partyId: party.id,
                    currentRoundId: round.id,
                  ),
                )
              else
                const Text(
                  'Warte auf Host...',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextRoundButton extends ConsumerStatefulWidget {
  final String partyId;
  final String currentRoundId;

  const _NextRoundButton({
    required this.partyId,
    required this.currentRoundId,
  });

  @override
  ConsumerState<_NextRoundButton> createState() => _NextRoundButtonState();
}

class _NextRoundButtonState extends ConsumerState<_NextRoundButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _next,
      child: _loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
          : const Text('WEITER'),
    );
  }

  Future<void> _next() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(gameControllerProvider)
          .nextRound(widget.partyId, widget.currentRoundId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
