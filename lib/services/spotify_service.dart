import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
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

class SpotifyService {
  final String _clientId = dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  final String _clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';
  final String _redirectUri = dotenv.env['SPOTIFY_REDIRECT_URI'] ?? '';

  String? _accessToken;

  bool get isAuthenticated => _accessToken != null;

  // ──────────────────────────────────────────
  // SPOTIFY APP CONNECTION (spotify_sdk)
  // ──────────────────────────────────────────

  /// Connect to the Spotify app via Remote SDK.
  /// Step 1: Get an OAuth token via browser (visible to user).
  /// Step 2: Use that token to connect to the Spotify Remote SDK.
  Future<bool> connectToSpotify() async {
    try {
      // Step 1: OAuth via browser – user sees and approves the login
      final token = await SpotifySdk.getAccessToken(
        clientId: _clientId,
        redirectUrl: _redirectUri,
        scope: 'app-remote-control streaming',
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          debugPrint('Spotify auth token timeout');
          throw Exception('Auth timeout');
        },
      );

      debugPrint('Spotify token obtained, connecting remote...');

      // Step 2: Connect Remote SDK with the token (skips internal auth)
      return await SpotifySdk.connectToSpotifyRemote(
        clientId: _clientId,
        redirectUrl: _redirectUri,
        accessToken: token,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Spotify remote connect timeout');
          return false;
        },
      );
    } catch (e) {
      debugPrint('Spotify connect error: $e');
      return false;
    }
  }

  /// Play a track by its Spotify URI (e.g. "spotify:track:abc123").
  Future<void> playTrack(String spotifyUri) async {
    await SpotifySdk.play(spotifyUri: spotifyUri);
  }

  /// Pause the currently playing track.
  Future<void> pausePlayback() async {
    await SpotifySdk.pause();
  }

  /// Resume playback.
  Future<void> resumePlayback() async {
    await SpotifySdk.resume();
  }

  // ──────────────────────────────────────────
  // SPOTIFY WEB API (HTTP / Client Credentials)
  // ──────────────────────────────────────────

  /// Authenticate via Client Credentials for search-only access.
  Future<void> _ensureToken() async {
    if (_accessToken != null) return;
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
      _accessToken = jsonDecode(response.body)['access_token'] as String;
    } else {
      throw Exception('Spotify auth failed: ${response.body}');
    }
  }

  /// Return a random track for the given genre key (one of [kSpotifyGenres]).
  /// Returns a map with: id, name, artistName, albumCoverUrl, spotifyUri.
  Future<Map<String, dynamic>> getRandomTrackForGenre(String genreKey) async {
    await _ensureToken();

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

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode == 401) {
      // Token expired – retry once
      _accessToken = null;
      await _ensureToken();
      return getRandomTrackForGenre(genreKey);
    }

    if (response.statusCode != 200) {
      throw Exception('Track search failed: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final items = data['tracks']['items'] as List;
    if (items.isEmpty) {
      throw Exception('Keine Tracks für Genre "$genreKey" gefunden.');
    }

    final track = items.first as Map<String, dynamic>;
    final artists = (track['artists'] as List)
        .map((a) => a['name'] as String)
        .join(', ');
    final images = track['album']['images'] as List;
    final coverUrl =
        images.isNotEmpty ? images.first['url'] as String : null;

    return {
      'id': track['id'] as String,
      'name': track['name'] as String,
      'artistName': artists,
      'albumCoverUrl': coverUrl,
      'spotifyUri': 'spotify:track:${track['id']}',
    };
  }

  // ──────────────────────────────────────────
  // PLAYLIST METHODS
  // ──────────────────────────────────────────

  /// Extracts the Spotify playlist ID from a URL, URI or plain ID.
  /// Accepts:
  ///   https://open.spotify.com/playlist/ABC123?si=...
  ///   spotify:playlist:ABC123
  ///   ABC123
  static String? extractPlaylistId(String input) {
    final trimmed = input.trim();
    // URL
    final urlMatch = RegExp(r'spotify\.com/playlist/([A-Za-z0-9]+)').firstMatch(trimmed);
    if (urlMatch != null) return urlMatch.group(1);
    // URI
    final uriMatch = RegExp(r'spotify:playlist:([A-Za-z0-9]+)').firstMatch(trimmed);
    if (uriMatch != null) return uriMatch.group(1);
    // Plain ID (22 chars, alphanumeric)
    if (RegExp(r'^[A-Za-z0-9]{22}$').hasMatch(trimmed)) return trimmed;
    return null;
  }

  /// Returns the playlist name and total track count.
  Future<Map<String, dynamic>> getPlaylistInfo(String playlistId) async {
    await _ensureToken();
    final headers = {'Authorization': 'Bearer $_accessToken'};

    // Name from playlist endpoint, total from /items endpoint (more reliable)
    final nameResponse = await http.get(
      Uri.parse('https://api.spotify.com/v1/playlists/$playlistId'),
      headers: headers,
    );
    if (nameResponse.statusCode == 401) {
      _accessToken = null;
      await _ensureToken();
      return getPlaylistInfo(playlistId);
    }
    if (nameResponse.statusCode == 429) {
      throw Exception('Zu viele Anfragen – bitte 1 Minute warten und erneut versuchen.');
    }
    if (nameResponse.statusCode == 403) {
      throw Exception('Zugriff verweigert (403). Ist die Playlist öffentlich?');
    }
    if (nameResponse.statusCode != 200) {
      throw Exception('Fehler ${nameResponse.statusCode}: Playlist nicht gefunden.');
    }
    final playlistData = jsonDecode(nameResponse.body) as Map<String, dynamic>;
    final trackCount = await getPlaylistTrackCount(playlistId);
    return {
      'name': playlistData['name'] as String,
      'trackCount': trackCount,
    };
  }

  /// Returns the total number of tracks in a playlist via the /items endpoint.
  Future<int> getPlaylistTrackCount(String playlistId) async {
    await _ensureToken();
    final uri = Uri.parse(
      'https://api.spotify.com/v1/playlists/$playlistId/items?limit=1',
    );
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $_accessToken'});
    if (response.statusCode == 401) {
      _accessToken = null;
      await _ensureToken();
      return getPlaylistTrackCount(playlistId);
    }
    if (response.statusCode == 429) {
      throw Exception('Zu viele Anfragen – bitte 1 Minute warten.');
    }
    if (response.statusCode != 200) {
      throw Exception('Track count failed (${response.statusCode})');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final total = data['total'];
    if (total is num) return total.toInt();
    return 0;
  }

  /// Returns track data at the given offset (0-based) from the playlist.
  Future<Map<String, dynamic>> getTrackFromPlaylist(String playlistId, int offset) async {
    await _ensureToken();
    // Use /items endpoint (newer, replaces /tracks)
    // Build URL as string to avoid Uri encoding parentheses in the fields param
    final uri = Uri.parse(
      'https://api.spotify.com/v1/playlists/$playlistId/items'
      '?limit=1&offset=$offset'
      '&fields=items(track(id,name,artists(name),album(images)))',
    );
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $_accessToken'});
    if (response.statusCode == 401) {
      _accessToken = null;
      await _ensureToken();
      return getTrackFromPlaylist(playlistId, offset);
    }
    if (response.statusCode != 200) {
      throw Exception('Playlist track fetch failed: ${response.body}');
    }
    final data = jsonDecode(response.body);
    final items = data['items'] as List;
    if (items.isEmpty || items.first['track'] == null) {
      throw Exception('Kein Track an Position $offset gefunden.');
    }
    final track = items.first['track'] as Map<String, dynamic>;
    final artists = (track['artists'] as List).map((a) => a['name'] as String).join(', ');
    final images = track['album']['images'] as List;
    final coverUrl = images.isNotEmpty ? images.first['url'] as String : null;
    return {
      'id': track['id'] as String,
      'name': track['name'] as String,
      'artistName': artists,
      'albumCoverUrl': coverUrl,
      'spotifyUri': 'spotify:track:${track['id']}',
    };
  }

  /// Picks a random track from the playlist that isn't in [usedTrackIds].
  /// Tries up to [maxAttempts] times before giving up.
  Future<Map<String, dynamic>> getRandomUnusedTrackFromPlaylist(
    String playlistId,
    List<String> usedTrackIds, {
    int maxAttempts = 5,
  }) async {
    final total = await getPlaylistTrackCount(playlistId);
    if (total == 0) throw Exception('Playlist ist leer.');
    final rng = Random();
    for (int i = 0; i < maxAttempts; i++) {
      final offset = rng.nextInt(total);
      final track = await getTrackFromPlaylist(playlistId, offset);
      if (!usedTrackIds.contains(track['id'] as String)) {
        return track;
      }
    }
    // All attempts hit duplicates – just return the last one anyway
    return getTrackFromPlaylist(playlistId, rng.nextInt(total));
  }

}
