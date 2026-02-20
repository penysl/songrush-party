import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:songrush_party/core/constants/playlists.dart';
import 'package:songrush_party/core/theme/app_theme.dart';
import 'package:songrush_party/features/party/party_controller.dart';
import 'package:songrush_party/services/playlist_storage_service.dart';
import 'package:songrush_party/services/spotify_service.dart';

class PlaylistSelector extends ConsumerStatefulWidget {
  final String partyId;

  const PlaylistSelector({super.key, required this.partyId});

  @override
  ConsumerState<PlaylistSelector> createState() => _PlaylistSelectorState();
}

class _PlaylistSelectorState extends ConsumerState<PlaylistSelector>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _urlController = TextEditingController();

  bool _loadingPreview = false;
  bool _savingImport = false;
  String? _previewName;
  int? _previewTrackCount;
  String? _previewId;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PLAYLIST WÄHLEN',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.neonPink,
                  labelColor: AppTheme.neonPink,
                  unselectedLabelColor: Colors.white54,
                  tabs: const [
                    Tab(text: 'Auswahl'),
                    Tab(text: 'Importieren'),
                  ],
                ),
                SizedBox(
                  height: 280,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _SelectionTab(partyId: widget.partyId),
                      _ImportTab(
                        urlController: _urlController,
                        loadingPreview: _loadingPreview,
                        savingImport: _savingImport,
                        previewName: _previewName,
                        previewTrackCount: _previewTrackCount,
                        previewError: _previewError,
                        onPreview: _loadPreview,
                        onSave: _saveImportedPlaylist,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadPreview() async {
    final input = _urlController.text.trim();
    if (input.isEmpty) return;

    final id = SpotifyService.extractPlaylistId(input);
    if (id == null) {
      setState(() {
        _previewError = 'Ungültige Spotify-URL oder -ID.';
        _previewName = null;
        _previewTrackCount = null;
        _previewId = null;
      });
      return;
    }

    setState(() {
      _loadingPreview = true;
      _previewError = null;
      _previewName = null;
      _previewTrackCount = null;
      _previewId = null;
    });

    try {
      final info = await ref.read(spotifyServiceProvider).getPlaylistInfo(id);
      if (mounted) {
        setState(() {
          _previewId = id;
          _previewName = info['name'] as String;
          _previewTrackCount = info['trackCount'] as int;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _previewError = 'Fehler: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _saveImportedPlaylist() async {
    if (_previewId == null || _previewName == null) return;
    setState(() => _savingImport = true);
    try {
      await ref.read(playlistStorageProvider).savePlaylist(
            SpotifyPlaylist(
              id: _previewId!,
              name: _previewName!,
              category: 'Import',
            ),
          );
      if (mounted) {
        _urlController.clear();
        setState(() {
          _previewId = null;
          _previewName = null;
          _previewTrackCount = null;
        });
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Playlist gespeichert!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingImport = false);
    }
  }
}

// ──────────────────────────────────────────
// Selection Tab
// ──────────────────────────────────────────

class _SelectionTab extends ConsumerWidget {
  final String partyId;

  const _SelectionTab({required this.partyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<SpotifyPlaylist>>(
      future: ref.read(playlistStorageProvider).getSavedPlaylists(),
      builder: (context, savedSnapshot) {
        final savedPlaylists = savedSnapshot.data ?? [];
        final allPlaylists = [
          ...kPredefinedPlaylists,
          ...savedPlaylists.where(
            (s) => !kPredefinedPlaylists.any((p) => p.id == s.id),
          ),
        ];

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: ref.watch(supabaseServiceProvider).streamParty(partyId),
          builder: (context, partySnap) {
            final currentPlaylistId = partySnap.hasData && partySnap.data!.isNotEmpty
                ? partySnap.data!.first['playlist_id'] as String?
                : null;

            // Group by category
            final Map<String, List<SpotifyPlaylist>> grouped = {};
            for (final p in allPlaylists) {
              grouped.putIfAbsent(p.category, () => []).add(p);
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: grouped.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    ...entry.value.map((playlist) {
                      final isSelected = playlist.id == currentPlaylistId;
                      return _PlaylistTile(
                        playlist: playlist,
                        isSelected: isSelected,
                        isSaved: savedPlaylists.any((s) => s.id == playlist.id),
                        partyId: partyId,
                        onRemove: playlist.category == 'Import'
                            ? () async {
                                await ref
                                    .read(playlistStorageProvider)
                                    .removePlaylist(playlist.id);
                                if (context.mounted) {
                                  // Rebuild by triggering a setState on parent
                                  // ignore: invalid_use_of_protected_member
                                  (context as Element).markNeedsBuild();
                                }
                              }
                            : null,
                      );
                    }),
                  ],
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _PlaylistTile extends ConsumerWidget {
  final SpotifyPlaylist playlist;
  final bool isSelected;
  final bool isSaved;
  final String partyId;
  final VoidCallback? onRemove;

  const _PlaylistTile({
    required this.playlist,
    required this.isSelected,
    required this.isSaved,
    required this.partyId,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        await ref.read(supabaseServiceProvider).parties.update({
          'playlist_id': playlist.id,
          'playlist_name': playlist.name,
        }).eq('id', partyId);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.neonPink.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.neonPink : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.queue_music,
              color: isSelected ? AppTheme.neonPink : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                playlist.name,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: const Icon(Icons.delete_outline, size: 16, color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// Import Tab
// ──────────────────────────────────────────

class _ImportTab extends StatelessWidget {
  final TextEditingController urlController;
  final bool loadingPreview;
  final bool savingImport;
  final String? previewName;
  final int? previewTrackCount;
  final String? previewError;
  final VoidCallback onPreview;
  final VoidCallback onSave;

  const _ImportTab({
    required this.urlController,
    required this.loadingPreview,
    required this.savingImport,
    required this.previewName,
    required this.previewTrackCount,
    required this.previewError,
    required this.onPreview,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spotify-Playlist-URL einfügen:',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://open.spotify.com/playlist/...',
                    hintStyle:
                        const TextStyle(color: Colors.white30, fontSize: 12),
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: loadingPreview ? null : onPreview,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: AppTheme.neonBlue,
                  ),
                  child: loadingPreview
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Vorschau',
                          style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Preview result
          if (previewError != null)
            Text(previewError!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          if (previewName != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.queue_music, color: AppTheme.neonBlue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          previewName!,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '$previewTrackCount Tracks',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: savingImport ? null : onSave,
                icon: savingImport
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_alt, size: 16),
                label: const Text('Playlist speichern'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonPink,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
