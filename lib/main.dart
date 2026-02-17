import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:songrush_party/core/theme/app_theme.dart';
import 'package:songrush_party/features/home/home_screen.dart';
import 'package:songrush_party/features/party/create_party_screen.dart';
import 'package:songrush_party/features/party/join_party_screen.dart';
import 'package:songrush_party/features/lobby/lobby_screen.dart';
import 'package:songrush_party/features/game/game_screen.dart';
import 'package:songrush_party/features/scoreboard/scoreboard_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) => const CreatePartyScreen(),
    ),
    GoRoute(
      path: '/join',
      builder: (context, state) => const JoinPartyScreen(),
    ),
    GoRoute(
      path: '/lobby/:partyId/:playerId',
      builder: (context, state) {
        final partyId = state.pathParameters['partyId']!;
        final playerId = state.pathParameters['playerId']!;
        return LobbyScreen(partyId: partyId, playerId: playerId);
      },
    ),
    GoRoute(
      path: '/game/:partyId/:playerId',
      builder: (context, state) {
        final partyId = state.pathParameters['partyId']!;
        final playerId = state.pathParameters['playerId']!;
        return GameScreen(partyId: partyId, playerId: playerId);
      },
    ),
    GoRoute(
      path: '/scoreboard/:partyId/:playerId',
      builder: (context, state) {
        final partyId = state.pathParameters['partyId']!;
        final playerId = state.pathParameters['playerId']!;
        return ScoreboardScreen(partyId: partyId, playerId: playerId);
      },
    ),
  ],
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load env
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Error loading .env: $e");
  }

  // Init Supabase
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl != null && supabaseAnonKey != null && supabaseUrl != 'YOUR_SUPABASE_URL') {
     await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } else {
    // Only print warning, app screens might still load but fail on action
    debugPrint("Supabase not initialized: Missing keys in .env");
  }

  runApp(const ProviderScope(child: SongrushPartyApp()));
}

class SongrushPartyApp extends ConsumerWidget {
  const SongrushPartyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Songrush Party',
      theme: AppTheme.darkTheme,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
