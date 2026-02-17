import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final spotifyServiceProvider = Provider((ref) => SpotifyService());

class SpotifyService {
  final String _clientId = dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  final String _clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? ''; // Optional, depends on flow
  final String _redirectUri = dotenv.env['SPOTIFY_REDIRECT_URI'] ?? '';

  String? _accessToken;

  bool get isAuthenticated => _accessToken != null;

  /// Get the authorization URL for Spotify OAuth.
  /// Standard "Authorization Code Flow" or "Implicit Grant".
  /// For MVP, we might start with "Client Credentials" just for searching,
  /// but "Authorization Code" is needed for track playback/user context.
  Uri getAuthUrl() {
    final scopes = [
      'user-read-private',
      'user-read-email',
      'streaming',
      'user-modify-playback-state',
      'user-read-playback-state',
    ].join(' ');

    return Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': scopes,
      'show_dialog': 'true',
    });
  }

  /// Exchange code for token (if using Authorization Code Flow).
  Future<void> handleAuthCode(String code) async {
    final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$_clientId:$_clientSecret'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
    } else {
      throw Exception('Failed to get access token: ${response.body}');
    }
  }

  /// Client Credentials Flow (Alternative for search without login).
  Future<void> authenticateWithClientCredentials() async {
     final response = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$_clientId:$_clientSecret'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'grant_type': 'client_credentials',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
    } else {
      throw Exception('Failed to authenticate with Spotify: ${response.body}');
    }
  }

  /// Search for tracks.
  Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    if (_accessToken == null) await authenticateWithClientCredentials();

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/search?q=${Uri.encodeComponent(query)}&type=track&limit=10'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final tracks = data['tracks']['items'] as List;
      return tracks.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to search tracks: ${response.body}');
    }
  }

  /// Get track info by ID.
  Future<Map<String, dynamic>> getTrack(String trackId) async {
    if (_accessToken == null) await authenticateWithClientCredentials();

    // Remove spotify:track: prefix if present
    final cleanId = trackId.replaceAll('spotify:track:', '');

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/tracks/$cleanId'),
      headers: {
        'Authorization': 'Bearer $_accessToken',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch track: ${response.body}');
    }
  }
}
