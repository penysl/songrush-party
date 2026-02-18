import 'dart:async';
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

          // Determine if this player is the host
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
                  if (round == null || round.status == 'finished') {
                    return _WaitingView(
                      partyId: partyId,
                      playerId: playerId,
                      isHost: isHost,
                    );
                  }

                  // Round is 'answered' → show reveal
                  if (round.status == 'answered') {
                    return _RevealView(
                      party: party,
                      round: round,
                      playerId: playerId,
                      isHost: isHost,
                    );
                  }

                  // Round is 'playing'
                  return _ActiveRoundView(
                    party: party,
                    round: round,
                    playerId: playerId,
                    isHost: isHost,
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
    required this.partyId,
    required this.playerId,
    required this.isHost,
  });

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

          // Live scoreboard
          Expanded(
            child: StreamBuilder(
              stream: supabaseService.streamPlayers(partyId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final players = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final p = players[index];
                    final isMe = p['id'] == playerId;
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
                          backgroundColor: p['is_host'] == true
                              ? AppTheme.neonBlue
                              : Colors.grey[800],
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
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
                        trailing: Text(
                          '${p['score']} Pts',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neonPink,
                          ),
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
          : const Text('RUNDE STARTEN'),
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
                // Host gets pause/skip controls
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

// ── Active player: input field ───────────────────────────────

class _GuessInputView extends ConsumerStatefulWidget {
  final Round round;
  final String playerId;

  const _GuessInputView({required this.round, required this.playerId});

  @override
  ConsumerState<_GuessInputView> createState() => _GuessInputViewState();
}

class _GuessInputViewState extends ConsumerState<_GuessInputView> {
  final _controller = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 30;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          t.cancel();
          _onTimeout();
        }
      });
    });
  }

  void _onTimeout() {
    if (_submitted) return;
    setState(() => _submitted = true);
    // Mark round as answered with no winner so reveal shows
    ref.read(supabaseServiceProvider).rounds.update({
      'status': 'answered',
    }).eq('id', widget.round.id);
    try {
      ref.read(spotifyServiceProvider).pausePlayback();
    } catch (_) {}
  }

  Future<void> _submit() async {
    final answer = _controller.text.trim();
    if (answer.isEmpty || _submitted) return;
    _timer?.cancel();
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
    _timer?.cancel();
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
            Text('Antwort wird geprüft...', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Timer ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: _secondsLeft / 30,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation(
                    _secondsLeft <= 5 ? Colors.red : AppTheme.neonBlue,
                  ),
                ),
              ),
              Text(
                '$_secondsLeft',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: _secondsLeft <= 5 ? Colors.red : Colors.white,
                ),
              ),
            ],
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
    // Look up active player name
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

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note, size: 72, color: Colors.white24),
              const SizedBox(height: 24),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neonBlue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ist dran',
                style: TextStyle(fontSize: 20, color: Colors.white54),
              ),
            ],
          ),
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

              if (!isActivePlayer)
                Text(
                  correct
                      ? '${_playerName(round)} hat es gewusst!'
                      : 'Leider falsch...',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: correct ? Colors.green : Colors.red,
                  ),
                  textAlign: TextAlign.center,
                ),

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

  String _playerName(Round round) {
    // Fallback: active player name is resolved via stream in _OtherPlayerWaitView.
    // Here we just return a placeholder since we don't have the name synchronously.
    return 'Spieler';
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
