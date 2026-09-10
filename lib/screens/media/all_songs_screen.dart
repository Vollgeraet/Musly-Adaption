import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/player_provider.dart';
import '../../widgets/widgets.dart';

class AllSongsScreen extends StatelessWidget {
  final String title;
  final List<Song> songs;

  const AllSongsScreen({
    super.key,
    required this.title,
    required this.songs,
  });

  void _playAll(BuildContext context, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final list = List<Song>.from(songs);
    if (shuffle) list.shuffle();
    player.playSong(list.first, playlist: list, startIndex: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: songs.isEmpty
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
              itemCount: songs.length + 1,
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
                final song = songs[index - 1];
                return SongTile(
                  song: song,
                  playlist: songs,
                  index: index - 1,
                  showAlbum: true,
                );
              },
            ),
    );
  }
}
