import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show PlatformException, rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_sdk/spotify_sdk.dart';

final spotifyServiceProvider = Provider((ref) => SpotifyService());

/// Genre definitions: display label → Spotify search query fragment
const Map<String, String> kSpotifyGenres = {
  'Pop': 'genre:pop',
  'Rock': 'genre:rock',
  'Hip-Hop': 'genre:hip-hop',
  'Dance': 'genre:dance',
  'R&B': 'genre:r-n-b',
  '80er': 'year:1980-1989',
  '90er': 'year:1990-1999',
  '2000er': 'year:2000-2009',
};

/// Genre key → bundled JSON asset path
const Map<String, String> _kGenreAssets = {
  'Pop': 'assets/playlists/pop.json',
  'Rock': 'assets/playlists/rock.json',
  'Hip-Hop': 'assets/playlists/hip_hop.json',
  'Dance': 'assets/playlists/dance.json',
  'R&B': 'assets/playlists/rnb.json',
  '80er': 'assets/playlists/80er.json',
  '90er': 'assets/playlists/90er.json',
  '2000er': 'assets/playlists/2000er.json',
};

class SpotifyService {
  final String _clientId = dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  final String _clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';
  final String _redirectUri = dotenv.env['SPOTIFY_REDIRECT_URI'] ?? '';

  String? _accessToken;
  DateTime? _tokenExpiry;

  // Cache: playlistId → total track count
  final Map<String, int> _trackCountCache = {};

  // Pool: playlistId → shuffled list of pre-fetched tracks (50 at a time)
  final Map<String, List<Map<String, dynamic>>> _trackPool = {};

  // Genre pool: genreKey → shuffled tracks loaded from local JSON asset
  final Map<String, List<Map<String, dynamic>>> _genrePool = {};

  bool get isAuthenticated => _accessToken != null;

  Never _throw429(http.Response response) {
    final retryAfter = response.headers['retry-after'];
    final seconds = int.tryParse(retryAfter ?? '') ?? 60;
    throw Exception('Zu viele Anfragen – bitte $seconds Sekunden warten.');
  }

  // ──────────────────────────────────────────
  // SPOTIFY APP REMOTE CONNECTION
  // ──────────────────────────────────────────

  Future<bool> connectToSpotify() async {
    try {
      await SpotifySdk.getAccessToken(
        clientId: _clientId,
        redirectUrl: _redirectUri,
        scope: 'app-remote-control,streaming,user-read-playback-state',
      );
    } on PlatformException catch (e) {
      if (e.message?.contains('AUTHENTICATION_SERVICE_UNAVAILABLE') == true ||
          e.code == 'authenticationTokenError') {
        throw Exception(
          'Spotify App nicht erreichbar.\n'
          'Bitte öffne die Spotify App, stelle sicher dass du eingeloggt bist, '
          'und tippe dann erneut auf "Spotify verbinden".',
        );
      }
      rethrow;
    }
    return await SpotifySdk.connectToSpotifyRemote(
      clientId: _clientId,
      redirectUrl: _redirectUri,
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => false,
    );
  }

  Future<void> playTrack(String spotifyUri) async {
    await SpotifySdk.play(spotifyUri: spotifyUri);
  }

  Future<void> pausePlayback() async {
    await SpotifySdk.pause();
  }

  Future<void> resumePlayback() async {
    await SpotifySdk.resume();
  }

  // ──────────────────────────────────────────
  // AUTH (with expiry caching)
  // ──────────────────────────────────────────

  /// Re-uses the cached token as long as it has more than 60 seconds left.
  Future<void> _ensureToken() async {
    if (_accessToken != null &&
        _tokenExpiry != null &&
        _tokenExpiry!.isAfter(DateTime.now().add(const Duration(seconds: 60)))) {
      return;
    }
    await _authenticateWithClientCredentials();
  }

  Future<void> _authenticateWithClientCredentials() async {
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$_clientId:$_clientSecret'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      _accessToken = body['access_token'] as String;
      final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));
    } else {
      throw Exception('Spotify auth failed: ${response.body}');
    }
  }

  /// Makes an authorized GET request.
  /// Automatically ensures a valid token and retries once on 401.
  Future<http.Response> _authorizedGet(Uri uri) async {
    await _ensureToken();
    var res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );
    if (res.statusCode == 401) {
      _accessToken = null;
      _tokenExpiry = null;
      await _ensureToken();
      res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
    }
    return res;
  }

  // ──────────────────────────────────────────
  // GENRE SEARCH
  // ──────────────────────────────────────────

  /// Returns a random track for the genre.
  /// Loads from the bundled JSON asset (0 API calls).
  /// Falls back to Spotify Search API only if the asset is empty/missing.
  Future<Map<String, dynamic>> getRandomTrackForGenre(String genreKey) async {
    // Lazily load + shuffle asset on first call per genre
    if (!_genrePool.containsKey(genreKey)) {
      await _loadGenrePool(genreKey);
    }

    final pool = _genrePool[genreKey]!;
    if (pool.isNotEmpty) {
      // Reshuffle when exhausted so play never stops
      if (pool.length == 1) {
        await _loadGenrePool(genreKey);
      }
      return pool.removeAt(0);
    }

    // Asset empty → fall back to API
    return _fetchRandomTrackFromApi(genreKey);
  }

  /// Loads the local JSON asset for [genreKey] into [_genrePool] (shuffled).
  Future<void> _loadGenrePool(String genreKey) async {
    final assetPath = _kGenreAssets[genreKey];
    if (assetPath == null) {
      _genrePool[genreKey] = [];
      return;
    }
    try {
      final raw = await rootBundle.loadString(assetPath);
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      list.shuffle();
      _genrePool[genreKey] = list;
    } catch (_) {
      _genrePool[genreKey] = [];
    }
  }

  /// Spotify Search API fallback — used only when the local JSON is empty.
  Future<Map<String, dynamic>> _fetchRandomTrackFromApi(String genreKey) async {
    final query = kSpotifyGenres[genreKey] ?? 'genre:pop';
    final offset = Random().nextInt(100);

    final uri = Uri.parse('https://api.spotify.com/v1/search').replace(
      queryParameters: {
        'q': query,
        'type': 'track',
        'limit': '1',
        'offset': offset.toString(),
      },
    );

    final response = await _authorizedGet(uri);

    if (response.statusCode == 429) _throw429(response);
    if (response.statusCode != 200) {
      throw Exception('Track search failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final items = data['tracks']['items'] as List;
    if (items.isEmpty) {
      throw Exception('Keine Tracks für Genre "$genreKey" gefunden.');
    }

    return _parseTrack(items.first as Map<String, dynamic>);
  }

  // ──────────────────────────────────────────
  // PLAYLIST METHODS
  // ──────────────────────────────────────────

  /// Extracts the Spotify playlist ID from a URL, URI or plain ID.
  static String? extractPlaylistId(String input) {
    final trimmed = input.trim();
    final urlMatch =
        RegExp(r'spotify\.com/playlist/([A-Za-z0-9]+)').firstMatch(trimmed);
    if (urlMatch != null) return urlMatch.group(1);
    final uriMatch =
        RegExp(r'spotify:playlist:([A-Za-z0-9]+)').firstMatch(trimmed);
    if (uriMatch != null) return uriMatch.group(1);
    if (RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(trimmed)) return trimmed;
    return null;
  }

  /// Returns the playlist name and total track count.
  /// One API call using `fields` — track count is read directly from the response
  /// and cached for the session.
  Future<Map<String, dynamic>> getPlaylistInfo(String playlistId) async {
    final response = await _authorizedGet(
      Uri.parse(
        'https://api.spotify.com/v1/playlists/$playlistId'
        '?fields=name,tracks.total',
      ),
    );

    if (response.statusCode == 429) _throw429(response);
    if (response.statusCode == 403) {
      throw Exception('Zugriff verweigert (403). Ist die Playlist öffentlich?');
    }
    if (response.statusCode != 200) {
      throw Exception(
          'Fehler ${response.statusCode}: Playlist nicht gefunden.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final trackCount = (data['tracks']['total'] as num).toInt();
    _trackCountCache[playlistId] = trackCount;

    return {
      'name': data['name'] as String,
      'trackCount': trackCount,
    };
  }

  /// Fetches only the total track count (used when not already cached).
  Future<int> _fetchTrackCount(String playlistId) async {
    final response = await _authorizedGet(
      Uri.parse(
          'https://api.spotify.com/v1/playlists/$playlistId?fields=tracks.total'),
    );
    if (response.statusCode == 429) _throw429(response);
    if (response.statusCode != 200) {
      throw Exception('Track count failed (${response.statusCode})');
    }
    final count =
        (jsonDecode(response.body)['tracks']['total'] as num).toInt();
    _trackCountCache[playlistId] = count;
    return count;
  }

  /// Fetches up to 50 tracks in a single API call and adds them (shuffled) to
  /// the in-memory pool for this playlist.
  Future<void> _refillPool(String playlistId) async {
    final total =
        _trackCountCache[playlistId] ?? await _fetchTrackCount(playlistId);
    if (total == 0) return;

    const batchSize = 50;
    final offset = Random().nextInt(max(1, total - batchSize));
    final limit = batchSize.clamp(1, total - offset);

    final response = await _authorizedGet(
      Uri.parse(
        'https://api.spotify.com/v1/playlists/$playlistId/items'
        '?limit=$limit&offset=$offset'
        '&fields=items(track(id,name,artists(name),album(images),is_local))',
      ),
    );

    if (response.statusCode == 429) _throw429(response);
    if (response.statusCode != 200) {
      throw Exception('Track pool fetch failed: ${response.body}');
    }

    final items = jsonDecode(response.body)['items'] as List;
    final tracks = <Map<String, dynamic>>[];
    for (final item in items) {
      final track = item['track'];
      if (track == null || track['is_local'] == true) continue;
      tracks.add(_parseTrack(track as Map<String, dynamic>));
    }

    tracks.shuffle();
    _trackPool[playlistId] = [...?_trackPool[playlistId], ...tracks];
  }

  /// Returns a random unused track from the playlist.
  ///
  /// Uses an in-memory pool — only makes an API call (50 tracks at once) when
  /// the pool is empty, instead of one call per track.
  Future<Map<String, dynamic>> getRandomUnusedTrackFromPlaylist(
    String playlistId,
    List<String> usedTrackIds, {
    int maxAttempts = 3,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if ((_trackPool[playlistId] ?? []).isEmpty) {
        await _refillPool(playlistId);
      }

      final pool = _trackPool[playlistId] ?? [];
      if (pool.isEmpty) throw Exception('Playlist ist leer.');

      final idx =
          pool.indexWhere((t) => !usedTrackIds.contains(t['id'] as String));

      if (idx != -1) {
        final track = pool.removeAt(idx);
        _trackPool[playlistId] = pool;
        return track;
      }

      // All tracks in current pool were already used — discard and refill
      _trackPool[playlistId] = [];
    }

    throw Exception('Keine neuen Tracks verfügbar.');
  }

  /// Call this when starting a new game to reset the track pool and cached
  /// track count for a playlist, so stale data from a previous session can't
  /// cause out-of-bounds offsets (e.g. if tracks were removed from the playlist).
  void clearPlaylistCache(String playlistId) {
    _trackPool.remove(playlistId);
    _trackCountCache.remove(playlistId);
  }

  /// Clears all caches (e.g. when switching playlists).
  void clearAllCaches() {
    _trackPool.clear();
    _trackCountCache.clear();
  }

  // ──────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────

  Map<String, dynamic> _parseTrack(Map<String, dynamic> track) {
    final artists =
        (track['artists'] as List).map((a) => a['name'] as String).join(', ');
    final images = track['album']['images'] as List;
    return {
      'id': track['id'] as String,
      'name': track['name'] as String,
      'artistName': artists,
      'albumCoverUrl': images.isNotEmpty ? images.first['url'] as String : null,
      'spotifyUri': 'spotify:track:${track['id']}',
    };
  }
}
