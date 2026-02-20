// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Map<String, String> readEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  return Map.fromEntries(
    file
        .readAsLinesSync()
        .where((l) => l.contains('=') && !l.trimLeft().startsWith('#'))
        .map((l) {
      final idx = l.indexOf('=');
      return MapEntry(
          l.substring(0, idx).trim(), l.substring(idx + 1).trim());
    }),
  );
}

Future<void> main() async {
  final env = readEnv('.env');
  final clientId = env['SPOTIFY_CLIENT_ID'] ?? '';
  final clientSecret = env['SPOTIFY_CLIENT_SECRET'] ?? '';

  final tokenResp = await http.post(
    Uri.parse('https://accounts.spotify.com/api/token'),
    headers: {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: {'grant_type': 'client_credentials'},
  );
  final token = jsonDecode(tokenResp.body)['access_token'] as String;
  print('Token OK\n');

  Future<void> test(String label, String url) async {
    final r = await http.get(Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'});
    final body =
        r.body.length > 400 ? '${r.body.substring(0, 400)}...' : r.body;
    print('$label → ${r.statusCode}');
    print('  $body\n');
  }

  await test('genre:pop limit=50 offset=0',
      'https://api.spotify.com/v1/search?q=genre%3Apop&type=track&limit=50&offset=0');
  await test('genre:pop limit=50 offset=4',
      'https://api.spotify.com/v1/search?q=genre%3Apop&type=track&limit=50&offset=4');
  await test('genre:pop limit=20 offset=4',
      'https://api.spotify.com/v1/search?q=genre%3Apop&type=track&limit=20&offset=4');
  await test('genre:pop limit=10 offset=4',
      'https://api.spotify.com/v1/search?q=genre%3Apop&type=track&limit=10&offset=4');
  await test('year:1990 limit=50 offset=0',
      'https://api.spotify.com/v1/search?q=year%3A1990&type=track&limit=50&offset=0');
  await test('year:1990 limit=50 offset=100',
      'https://api.spotify.com/v1/search?q=year%3A1990&type=track&limit=50&offset=100');
}
