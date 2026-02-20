class SpotifyPlaylist {
  final String id;
  final String name;
  final String category;

  const SpotifyPlaylist({
    required this.id,
    required this.name,
    required this.category,
  });

  Map<String, String> toJson() => {'id': id, 'name': name, 'category': category};

  factory SpotifyPlaylist.fromJson(Map<String, dynamic> json) => SpotifyPlaylist(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
      );
}

const List<SpotifyPlaylist> kPredefinedPlaylists = [
  SpotifyPlaylist(id: '37i9dQZF1DXcBWIGoYBM5M', name: 'Hot Hits Deutschland', category: 'Charts'),
  SpotifyPlaylist(id: '37i9dQZF1DX0iXIODSoeBp', name: 'Heiße Hits', category: 'Charts'),
  SpotifyPlaylist(id: '37i9dQZF1DX1HCSbPPGC4d', name: '80er Hits', category: 'Jahrzehnte'),
  SpotifyPlaylist(id: '37i9dQZF1DX4o1uurqeBaT', name: '90er Hits', category: 'Jahrzehnte'),
  SpotifyPlaylist(id: '37i9dQZF1DX4UkKv329iMv', name: '2000er Hits', category: 'Jahrzehnte'),
  SpotifyPlaylist(id: '37i9dQZF1DWXRqgorJj26U', name: 'Rock Classics', category: 'Genre'),
  SpotifyPlaylist(id: '37i9dQZF1DX0XUsuxWHRQd', name: 'Hip-Hop Central', category: 'Genre'),
  SpotifyPlaylist(id: '37i9dQZF1DX4jAr4n7zGDH', name: 'Dance Hits', category: 'Genre'),
  SpotifyPlaylist(id: '37i9dQZF1DX1g0iEXLFycr', name: 'Party Hits', category: 'Party'),
  SpotifyPlaylist(id: '37i9dQZF1DXaXB8fQg7xof', name: 'Deutschrap Brandneu', category: 'Genre'),
];
