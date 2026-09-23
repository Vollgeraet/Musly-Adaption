import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/player_provider.dart';
import '../../widgets/widgets.dart';

class AllSongsScreen extends StatelessWidget {
  final String title;
  final List<Song> songs;
  final bool sortByRecentlyAdded;

  const AllSongsScreen({
    super.key,
    required this.title,
    required this.songs,
    this.sortByRecentlyAdded = false,
  });

  List<Song> get _displaySongs {
    if (!sortByRecentlyAdded) return songs;
    final sorted = List<Song>.from(songs);
    sorted.sort((a, b) {
      if (a.created == null && b.created == null) return 0;
      if (a.created == null) return 1;
      if (b.created == null) return -1;
      return b.created!.compareTo(a.created!); // neueste zuerst
    });
    return sorted;
  }

  void _playAll(BuildContext context, {bool shuffle = false}) {
    final list = _displaySongs;
    if (list.isEmpty) return;
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final playlist = List<Song>.from(list);
    if (shuffle) playlist.shuffle();
    player.playSong(playlist.first, playlist: playlist, startIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    final displaySongs = _displaySongs;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: displaySongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.music_note_list,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Keine Songs gefunden'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 150),
              itemCount: displaySongs.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _playAll(context),
                            icon: const Icon(CupertinoIcons.play_fill, size: 16),
                            label: const Text('Alle abspielen'),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _playAll(context, shuffle: true),
                            icon: const Icon(CupertinoIcons.shuffle, size: 16),
                            label: const Text('Zufällig'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final song = displaySongs[index - 1];
                return SongTile(
                  song: song,
                  playlist: displaySongs,
                  index: index - 1,
                  showAlbum: true,
                );
              },
            ),
    );
  }
}
