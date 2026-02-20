import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songrush_party/core/constants/playlists.dart';

final playlistStorageProvider = Provider<PlaylistStorageService>((ref) {
  return PlaylistStorageService();
});

class PlaylistStorageService {
  static const _key = 'songrush_saved_playlists';

  Future<List<SpotifyPlaylist>> getSavedPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => SpotifyPlaylist.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> savePlaylist(SpotifyPlaylist playlist) async {
    final current = await getSavedPlaylists();
    if (current.any((p) => p.id == playlist.id)) return;
    current.add(playlist);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(current.map((p) => p.toJson()).toList()));
  }

  Future<void> removePlaylist(String id) async {
    final current = await getSavedPlaylists();
    current.removeWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(current.map((p) => p.toJson()).toList()));
  }
}
