// ignore_for_file: avoid_print
// One-time script to populate assets/playlists/*.json with Spotify tracks.
//
// Run from the project root:
//   dart run scripts/seed_playlists.dart
//
// Reads SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET from .env
// Fetches ~200 tracks per genre and writes them to assets/playlists/.
// After running, rebuild the app — no more API calls needed for genre mode.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

// ── Config ────────────────────────────────────────────────────────────────────

const int tracksPerGenre = 200;

/// Genre label → (list of search queries to rotate through, output file)
/// Multiple queries are used for decade genres so we get variety across years.
final genres = {
  'Pop': (['genre:pop'], 'assets/playlists/pop.json'),
  'Rock': (['genre:rock'], 'assets/playlists/rock.json'),
  'Hip-Hop': (['genre:hip-hop'], 'assets/playlists/hip_hop.json'),
  'Dance': (['genre:dance', 'genre:edm', 'genre:electronic'], 'assets/playlists/dance.json'),
  'R&B': (['genre:r-n-b', 'genre:soul'], 'assets/playlists/rnb.json'),
  '80er': (
    ['year:1980', 'year:1981', 'year:1982', 'year:1983', 'year:1984',
     'year:1985', 'year:1986', 'year:1987', 'year:1988', 'year:1989'],
    'assets/playlists/80er.json',
  ),
  '90er': (
    ['year:1990', 'year:1991', 'year:1992', 'year:1993', 'year:1994',
     'year:1995', 'year:1996', 'year:1997', 'year:1998', 'year:1999'],
    'assets/playlists/90er.json',
  ),
  '2000er': (
    ['year:2000', 'year:2001', 'year:2002', 'year:2003', 'year:2004',
     'year:2005', 'year:2006', 'year:2007', 'year:2008', 'year:2009'],
    'assets/playlists/2000er.json',
  ),
};

// ── Main ──────────────────────────────────────────────────────────────────────

Future<void> main() async {
  final env = _readEnv('.env');
  final clientId = env['SPOTIFY_CLIENT_ID'] ?? '';
  final clientSecret = env['SPOTIFY_CLIENT_SECRET'] ?? '';

  if (clientId.isEmpty || clientSecret.isEmpty) {
    stderr.writeln('ERROR: SPOTIFY_CLIENT_ID / SPOTIFY_CLIENT_SECRET not found in .env');
    exit(1);
  }

  print('Authenticating with Spotify...');
  final token = await _getToken(clientId, clientSecret);
  print('OK\n');

  Directory('assets/playlists').createSync(recursive: true);

  for (final entry in genres.entries) {
    final name = entry.key;
    final (queries, outputPath) = entry.value;

    print('[$name] Fetching $tracksPerGenre tracks...');
    final tracks = await _fetchTracks(token, queries, tracksPerGenre);
    File(outputPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(tracks),
    );
    print('[$name] → ${tracks.length} tracks saved to $outputPath\n');

    await Future.delayed(const Duration(milliseconds: 300));
  }

  print('Done! Rebuild the app to bundle the new assets.');
}

// ── Spotify helpers ───────────────────────────────────────────────────────────

Future<String> _getToken(String clientId, String clientSecret) async {
  final response = await http.post(
    Uri.parse('https://accounts.spotify.com/api/token'),
    headers: {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: {'grant_type': 'client_credentials'},
  );
  if (response.statusCode != 200) {
    throw Exception('Auth failed: ${response.body}');
  }
  return jsonDecode(response.body)['access_token'] as String;
}

/// Fetches [target] unique tracks by rotating through [queries].
/// Probes the total result count per query first to avoid out-of-range offsets.
Future<List<Map<String, dynamic>>> _fetchTracks(
  String token,
  List<String> queries,
  int target,
) async {
  final tracks = <Map<String, dynamic>>[];
  final seen = <String>{};
  final rng = Random();
  int queryIdx = 0;

  // Cache total available results per query to cap offsets correctly
  final totals = <String, int>{};

  // With limit=10, we need more passes to collect enough unique tracks
  final maxPasses = (target / 10).ceil() * 3;

  for (int pass = 0; pass < maxPasses && tracks.length < target; pass++) {
    final query = queries[queryIdx % queries.length];
    queryIdx++;

    // Probe total for this query on first encounter
    if (!totals.containsKey(query)) {
      final probe = await http.get(
        Uri.parse('https://api.spotify.com/v1/search').replace(
          queryParameters: {
            'q': query,
            'type': 'track',
            'limit': '1',
            'offset': '0',
          },
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (probe.statusCode == 200) {
        final total = (jsonDecode(probe.body)['tracks']['total'] as num).toInt();
        totals[query] = total;
        print('  "$query" → $total total results');
      } else {
        totals[query] = 0;
        print('  WARNING: probe failed for "$query" (${probe.statusCode})');
        continue;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    final total = totals[query]!;
    if (total == 0) continue;

    // Client Credentials API caps search limit at 10
    const limit = 10;

    // Cap offset so we never request beyond what Spotify has
    final maxOffset = (total - limit).clamp(0, 990);
    final offset = maxOffset > 0 ? rng.nextInt(maxOffset) : 0;

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/search').replace(
        queryParameters: {
          'q': query,
          'type': 'track',
          'limit': '$limit',
          'offset': '$offset',
        },
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 429) {
      final wait = int.tryParse(response.headers['retry-after'] ?? '10') ?? 10;
      print('  Rate limited — waiting ${wait}s...');
      await Future.delayed(Duration(seconds: wait));
      queryIdx--; // retry same query
      continue;
    }

    if (response.statusCode != 200) {
      print('  WARNING: ${response.statusCode} for "$query" offset=$offset — skipping');
      continue;
    }

    final items = jsonDecode(response.body)['tracks']['items'] as List;
    for (final item in items) {
      final id = item['id'] as String?;
      if (id == null || seen.contains(id)) continue;
      seen.add(id);
      final artists = (item['artists'] as List)
          .map((a) => a['name'] as String)
          .join(', ');
      final images = item['album']['images'] as List;
      tracks.add({
        'id': id,
        'name': item['name'] as String,
        'artistName': artists,
        'albumCoverUrl':
            images.isNotEmpty ? images.first['url'] as String : null,
        'spotifyUri': 'spotify:track:$id',
      });
    }

    print('  ${tracks.length}/$target tracks collected...');
    await Future.delayed(const Duration(milliseconds: 250));
  }

  return tracks;
}

// ── .env reader ───────────────────────────────────────────────────────────────

Map<String, String> _readEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  return Map.fromEntries(
    file
        .readAsLinesSync()
        .where((l) => l.contains('=') && !l.trimLeft().startsWith('#'))
        .map((l) {
      final idx = l.indexOf('=');
      return MapEntry(
        l.substring(0, idx).trim(),
        l.substring(idx + 1).trim(),
      );
    }),
  );
}
