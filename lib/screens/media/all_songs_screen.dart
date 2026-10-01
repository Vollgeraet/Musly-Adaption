import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/player_provider.dart';
import '../../services/recommendation_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/song_menu_actions.dart';
import '../../utils/song_sorting.dart';
import '../../widgets/common/floating_panel.dart';
import '../../widgets/common/song_list_header.dart';
import '../../widgets/widgets.dart';

/// Zeigt eine feste Liste von Songs (aktuell für "Alle Titel" und
/// "Zuletzt hinzugefügt" aus der Bibliothek) mit demselben Layout wie
/// Wiedergabelisten: Kopfzeile mit Anzahl/Dauer, Zufall/Sortieren/Mehr,
/// und der ein-/ausblendbaren Suchleiste am unteren Rand.
class AllSongsScreen extends StatefulWidget {
  final String title;
  final List<Song> songs;
  final bool sortByRecentlyAdded;

  const AllSongsScreen({
    super.key,
    required this.title,
    required this.songs,
    this.sortByRecentlyAdded = false,
  });

  @override
  State<AllSongsScreen> createState() => _AllSongsScreenState();
}

class _AllSongsScreenState extends State<AllSongsScreen> {
  late SongSortOption _currentSort;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentSort = widget.sortByRecentlyAdded
        ? SongSortOption.addedDesc
        : SongSortOption.titleAsc;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  void _playAll(List<Song> songs, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final playlist = List<Song>.from(songs);
    if (shuffle) playlist.shuffle();
    player.playSong(playlist.first, playlist: playlist, startIndex: 0);
  }

  void _playRandomSong(List<Song> songs) {
    if (songs.isEmpty) return;
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final index = DateTime.now().millisecondsSinceEpoch % songs.length;
    final song = songs[index];
    player.playSong(song, playlist: songs, startIndex: index);
  }

  void _showMoreMenu(BuildContext context, List<Song> songs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;
    final player = Provider.of<PlayerProvider>(context, listen: false);

    showFloatingPanel(
      context,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevated : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListMenuTile(
                        icon: Icons.add_to_home_screen_rounded,
                        title: 'Verknüpfung auf Homescreen',
                        enabled: false,
                      ),
                      ListMenuTile(
                        icon: Icons.shuffle_on_rounded,
                        title: 'Erweitertes Mischen',
                        enabled: false,
                      ),
                      ListMenuTile(
                        icon: Icons.play_arrow_rounded,
                        title: 'Abspielen',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _playAll(songs, shuffle: false);
                        },
                      ),
                      Divider(
                          height: 17,
                          indent: 16,
                          endIndent: 16,
                          color: dividerColor),
                      ListMenuTile(
                        icon: Icons.playlist_play_rounded,
                        title: 'Nach dem aktuellen Titel spielen',
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          for (final s in songs.reversed) {
                            await player.addToQueueNext(s);
                          }
                        },
                      ),
                      ListMenuTile(
                        icon: Icons.queue_music_rounded,
                        title: 'Zur aktuellen Warteschlange hinzufügen',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          player.addAllToQueue(songs);
                        },
                      ),
                      ListMenuTile(
                        icon: Icons.playlist_add_rounded,
                        title: 'Zu Warteschlange hinzufügen',
                        enabled: false,
                      ),
                      ListMenuTile(
                        icon: Icons.library_add_rounded,
                        title: 'Zu Wiedergabelisten hinzufügen',
                        enabled: false,
                      ),
                      Divider(
                          height: 17,
                          indent: 16,
                          endIndent: 16,
                          color: dividerColor),
                      ListMenuTile(
                        icon: Icons.edit_note_rounded,
                        title: 'Tags bearbeiten',
                        enabled: false,
                      ),
                      ListMenuTile(
                        icon: Icons.speed_rounded,
                        title: 'Wiedergabegeschwindigkeit und Tonhöhe',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          SongMenuActions.showSpeedPitchDialog(context, player);
                        },
                      ),
                      ListMenuTile(
                        icon: Icons.share_rounded,
                        title: 'Teilen',
                        enabled: false,
                      ),
                      Divider(
                          height: 17,
                          indent: 16,
                          endIndent: 16,
                          color: dividerColor),
                      ListMenuTile(
                        icon: Icons.checklist_rounded,
                        title: 'Wählen Sie mehrere aus',
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recProfiles =
        Provider.of<RecommendationService>(context, listen: false).profiles;
    final baseSongs = widget.songs;
    final searchedSongs = _searchQuery.isEmpty
        ? baseSongs
        : baseSongs
            .where((s) =>
                s.title.toLowerCase().contains(_searchQuery) ||
                (s.artist?.toLowerCase().contains(_searchQuery) ?? false))
            .toList();
    final displaySongs = sortSongs(searchedSongs, _currentSort, recProfiles);
    final totalDuration = Duration(
      seconds: baseSongs.fold<int>(0, (sum, s) => sum + (s.duration ?? 0)),
    );

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SongListHeader(
                    title: widget.title,
                    songCount: baseSongs.length,
                    totalDuration: totalDuration,
                    onRandom: () => _playRandomSong(displaySongs),
                    onSort: () => showSongSortPanel(
                      context,
                      current: _currentSort,
                      onSelected: (opt) => setState(() => _currentSort = opt),
                    ),
                    onMore: () => _showMoreMenu(context, displaySongs),
                  ),
                ),
                if (displaySongs.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: Text('Keine Songs gefunden')),
                    ),
                  )
                else
                  SliverFixedExtentList(
                    itemExtent: 68.0,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final song = displaySongs[index];
                        return SongTile(
                          key: ValueKey(song.id),
                          song: song,
                          playlist: displaySongs,
                          index: index,
                          showAlbum: true,
                          showArtist: true,
                        );
                      },
                      childCount: displaySongs.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
          SongListSearchBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
          ),
        ],
      ),
    );
  }
}
