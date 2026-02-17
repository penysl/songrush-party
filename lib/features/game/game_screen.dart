import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:songrush_party/core/theme/app_theme.dart';
import 'package:songrush_party/features/game/game_controller.dart';
import 'package:songrush_party/features/party/party_controller.dart';
import 'package:songrush_party/models/party.dart';
import 'package:songrush_party/models/round.dart';

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
    final partyStream = ref.watch(supabaseServiceProvider).streamParty(partyId);
    
    return Scaffold(
      body: StreamBuilder(
        stream: partyStream,
        builder: (context, partySnapshot) {
           if (!partySnapshot.hasData || partySnapshot.data!.isEmpty) {
             return const Center(child: CircularProgressIndicator());
           }
           
           final partyMap = partySnapshot.data!.first;
           final party = Party.fromMap(partyMap);

           // If game is finished, navigate to scoreboard
           if (party.status == 'finished') {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               context.go('/scoreboard/$partyId/$playerId');
             });
             return const Center(child: CircularProgressIndicator());
           }

           // Watch Current Round
           final roundAsync = ref.watch(currentRoundProvider(partyId));
           // Watch Local Player for isHost status
           final playerStream = ref.watch(supabaseServiceProvider).players.stream(primaryKey: ['id']).eq('id', playerId).limit(1);

           return StreamBuilder<List<Map<String, dynamic>>>(
             stream: playerStream,
             builder: (context, playerSnapshot) {
               final isHost = playerSnapshot.hasData && 
                              playerSnapshot.data!.isNotEmpty && 
                              playerSnapshot.data!.first['is_host'] == true;

               return roundAsync.when(
                 data: (round) {
                   if (round == null || round.status == 'finished') {
                     // No active round — show waiting view
                     return _WaitingView(
                       partyId: partyId,
                       playerId: playerId,
                       isHost: isHost,
                       lastRound: round,
                     ); 
                   }

                   return _ActiveRoundView(
                     party: party,
                     round: round,
                     playerId: playerId,
                   );
                 },
                 loading: () => const Center(child: CircularProgressIndicator()),
                 error: (err, stack) => Center(child: Text('Error: $err')),
               );
             },
           );
        },
      ),
    );
  }
}

// ============================================
// WAITING VIEW — Between rounds / Start round
// ============================================

class _WaitingView extends ConsumerStatefulWidget {
  final String partyId;
  final String playerId;
  final bool isHost;
  final Round? lastRound;

  const _WaitingView({
    required this.partyId,
    required this.playerId,
    required this.isHost,
    this.lastRound,
  });

  @override
  ConsumerState<_WaitingView> createState() => _WaitingViewState();
}

class _WaitingViewState extends ConsumerState<_WaitingView> {
  final _songTitleController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _songTitleController.dispose();
    super.dispose();
  }

  Future<void> _startRound() async {
    final title = _songTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Songtitel eingeben!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(gameControllerProvider).startRound(widget.partyId, title);
      _songTitleController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stream players for scoreboard display
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
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Icon(
                  widget.lastRound != null ? Icons.emoji_events : Icons.music_note,
                  size: 48,
                  color: AppTheme.neonPink,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.lastRound != null ? 'NÄCHSTE RUNDE' : 'BEREIT?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Live Scoreboard
          Expanded(
            child: StreamBuilder(
              stream: supabaseService.streamPlayers(widget.partyId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final players = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final p = players[index];
                    final isMe = p['id'] == widget.playerId;
                    return Card(
                      color: isMe ? AppTheme.surface.withValues(alpha: 0.8) : AppTheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isMe ? const BorderSide(color: AppTheme.neonBlue, width: 2) : BorderSide.none,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p['is_host'] == true ? AppTheme.neonBlue : Colors.grey[800],
                          child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          p['name'] as String,
                          style: TextStyle(
                            fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
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

          // Host Controls
          if (widget.isHost)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  TextField(
                    controller: _songTitleController,
                    decoration: const InputDecoration(
                      hintText: 'Songtitel eingeben...',
                      prefixIcon: Icon(Icons.music_note),
                      labelText: 'Korrekter Songtitel',
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _startRound,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('RUNDE STARTEN'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                          ),
                          onPressed: () {
                            ref.read(gameControllerProvider).endGame(widget.partyId);
                          },
                          child: const Text('BEENDEN'),
                        ),
                      ),
                    ],
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

// ============================================
// ACTIVE ROUND VIEW — Buzzer + Answer
// ============================================

class _ActiveRoundView extends ConsumerWidget {
  final Party party;
  final Round round;
  final String playerId;

  const _ActiveRoundView({
    required this.party,
    required this.round,
    required this.playerId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buzzerAsync = ref.watch(roundBuzzerProvider(round.id));

    return Column(
      children: [
        // Game Header
        SafeArea(
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Text(
              'STATUS: ${round.status.toUpperCase().replaceAll('_', ' ')}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        Expanded(
          child: buzzerAsync.when(
            data: (buzzer) {
                // If round is locked (buzzer exists)
                if (buzzer != null) {
                   if (buzzer.playerId == playerId) {
                     // This player buzzed — show answer input with timer
                     return _AnswerInputView(
                       round: round,
                       playerId: playerId,
                     );
                   } else {
                     // Another player buzzed — show locked state
                     return const Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.lock, size: 80, color: Colors.grey),
                           SizedBox(height: 20),
                           Text('GESPERRT',
                             style: TextStyle(fontSize: 48, color: Colors.grey, fontWeight: FontWeight.bold)),
                           SizedBox(height: 8),
                           Text('Ein anderer Spieler antwortet...',
                             style: TextStyle(color: Colors.white54)),
                         ],
                       ),
                     );
                   }
                }

                // If round is playing (no buzzer yet) — show buzzer button
                return _BuzzerView(
                  roundId: round.id,
                  playerId: playerId,
                );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

// ============================================
// BUZZER VIEW — The big red button
// ============================================

class _BuzzerView extends ConsumerStatefulWidget {
  final String roundId;
  final String playerId;

  const _BuzzerView({required this.roundId, required this.playerId});

  @override
  ConsumerState<_BuzzerView> createState() => _BuzzerViewState();
}

class _BuzzerViewState extends ConsumerState<_BuzzerView>
    with SingleTickerProviderStateMixin {
  bool _buzzing = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'HÖRST DU DEN SONG?',
            style: TextStyle(fontSize: 20, color: Colors.white54, letterSpacing: 2),
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = 1.0 + (_pulseController.value * 0.05);
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: GestureDetector(
              onTap: _buzzing ? null : () async {
                setState(() => _buzzing = true);
                final success = await ref.read(gameControllerProvider)
                    .buzz(widget.roundId, widget.playerId);
                if (!success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Zu langsam! Jemand war schneller.')),
                  );
                }
                if (mounted) setState(() => _buzzing = false);
              },
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFFFF4444), Color(0xFFCC0000)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.6),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: _buzzing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'BUZZER',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// ANSWER INPUT VIEW — Timer + Answer Field
// ============================================

class _AnswerInputView extends ConsumerStatefulWidget {
  final Round round;
  final String playerId;

  const _AnswerInputView({
    required this.round,
    required this.playerId,
  });

  @override
  ConsumerState<_AnswerInputView> createState() => _AnswerInputViewState();
}

class _AnswerInputViewState extends ConsumerState<_AnswerInputView> {
  final _answerController = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 15;
  bool _submitted = false;
  AnswerResult? _result;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          timer.cancel();
          _handleTimeout();
        }
      });
    });
  }

  void _handleTimeout() {
    if (_submitted) return;
    setState(() => _submitted = true);

    // Timeout — reset buzzer for next player
    ref.read(gameControllerProvider).resetBuzzer(widget.round.id);
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty || _submitted) return;

    _timer?.cancel();
    setState(() => _submitted = true);

    final correctAnswer = widget.round.correctAnswer ?? '';
    final result = await ref.read(gameControllerProvider).submitAnswer(
      roundId: widget.round.id,
      playerId: widget.playerId,
      answer: answer,
      correctAnswer: correctAnswer,
    );

    if (mounted) {
      setState(() => _result = result);
    }

    // If wrong, wait 2 seconds then reset buzzer for next player
    if (!result.correct) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await ref.read(gameControllerProvider).resetBuzzer(widget.round.id);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show result feedback
    if (_result != null) {
      return _buildResultView();
    }

    // Show timeout feedback
    if (_submitted && _result == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.timer_off, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text(
              'ZEIT ABGELAUFEN!',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nächster Spieler darf buzzern...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    // Answer input with timer
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Timer
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: _secondsLeft / 15,
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
            'DU HAST GEBUZZERT!',
            style: TextStyle(
              fontSize: 24,
              color: AppTheme.neonPink,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          TextField(
            controller: _answerController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Wie heißt der Song?',
              labelText: 'Deine Antwort',
              prefixIcon: Icon(Icons.edit),
            ),
            style: const TextStyle(color: Colors.white, fontSize: 18),
            onSubmitted: (_) => _submitAnswer(),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _submitAnswer,
              child: const Text('SENDEN'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final isCorrect = _result!.correct;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            size: 100,
            color: isCorrect ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 20),
          Text(
            isCorrect ? 'RICHTIG! 🎉' : 'FALSCH!',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isCorrect ? Colors.green : Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_result!.similarity * 100).toInt()}% Übereinstimmung',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          if (isCorrect) ...[
            const SizedBox(height: 8),
            const Text(
              '+1 Punkt!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.neonBlue,
              ),
            ),
          ],
          if (!isCorrect) ...[
            const SizedBox(height: 16),
            const Text(
              'Nächster Spieler darf buzzern...',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }
}
