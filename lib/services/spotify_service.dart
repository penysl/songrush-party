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

  /// Connect to the Spotify app via Remote SDK (OAuth happens inside the SDK).
  /// The host must have Spotify Premium and the Spotify app installed.
  Future<bool> connectToSpotify() async {
    try {
      return await SpotifySdk.connectToSpotifyRemote(
        clientId: _clientId,
        redirectUrl: _redirectUri,
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

  /// Search tracks by query (kept for potential future use).
  Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    await _ensureToken();

    final response = await http.get(
      Uri.parse(
          'https://api.spotify.com/v1/search?q=${Uri.encodeComponent(query)}&type=track&limit=10'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['tracks']['items'] as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception('Track search failed: ${response.body}');
    }
  }

  /// Get track info by ID.
  Future<Map<String, dynamic>> getTrack(String trackId) async {
    await _ensureToken();
    final cleanId = trackId.replaceAll('spotify:track:', '');

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/tracks/$cleanId'),
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch track: ${response.body}');
    }
  }
}
