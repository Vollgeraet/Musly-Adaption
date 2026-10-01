import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/subsonic_service.dart';
import '../../services/offline_service.dart';
import '../../services/recommendation_service.dart';
import '../../providers/player_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/navigation_helper.dart';
import '../../utils/song_menu_actions.dart';
import '../../utils/song_sorting.dart';
import '../../widgets/common/floating_panel.dart';
import '../../widgets/common/song_list_header.dart';
import '../../widgets/widgets.dart';
import '../../l10n/app_localizations.dart';
import '../detail/album_screen.dart';
import 'package:flutter/cupertino.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Song> _favoriteSongs = [];
  List<Album> _favoriteAlbums = [];
  bool _isLoading = true;
  int _selectedTab = 0;
  SongSortOption _currentSort = SongSortOption.titleAsc;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);

    try {
      final subsonic = Provider.of<SubsonicService>(context, listen: false);
      final starred = await subsonic.getStarred();

      if (mounted) {
        setState(() {
          _favoriteSongs = starred.songs;
          _favoriteAlbums = starred.albums;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  void _playAll(List<Song> songs, {bool shuffle = false}) {
    if (songs.isEmpty) return;
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final list = List<Song>.from(songs);
    if (shuffle) list.shuffle();
    player.playSong(list.first, playlist: list, startIndex: 0);
  }

  void _playRandomSong(List<Song> songs) {
    if (songs.isEmpty) return;
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final index = DateTime.now().millisecondsSinceEpoch % songs.length;
    final song = songs[index];
    player.playSong(song, playlist: songs, startIndex: index);
  }

  Future<void> _downloadAllFavorites() async {
    if (_favoriteSongs.isEmpty) return;

    final offlineService = Provider.of<OfflineService>(context, listen: false);
    final subsonic = Provider.of<SubsonicService>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    await offlineService.initialize();

    for (final song in _favoriteSongs) {
      await offlineService.downloadSong(song, subsonic);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.queuedSongsForDownload(_favoriteSongs.length)),
        ),
      );
    }
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
                        icon: Icons.play_arrow_rounded,
                        title: 'Abspielen',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _playAll(songs, shuffle: false);
                        },
                      ),
                      ListMenuTile(
                        icon: CupertinoIcons.arrow_down_circle,
                        title: AppLocalizations.of(context)!.downloadAll,
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _downloadAllFavorites();
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.favorites),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: PillTabBar(
            tabs: [l10n.songs, l10n.albums],
            selectedIndex: _selectedTab,
            onTabSelected: (idx) => setState(() => _selectedTab = idx),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedTab == 0
              ? _buildSongsList()
              : _buildAlbumsList(),
    );
  }

  Widget _buildSongsList() {
    final l10n = AppLocalizations.of(context)!;
    final recProfiles =
        Provider.of<RecommendationService>(context, listen: false).profiles;
    final searchedSongs = _searchQuery.isEmpty
        ? _favoriteSongs
        : _favoriteSongs
            .where((s) =>
                s.title.toLowerCase().contains(_searchQuery) ||
                (s.artist?.toLowerCase().contains(_searchQuery) ?? false))
            .toList();
    final displaySongs = sortSongs(searchedSongs, _currentSort, recProfiles);
    final totalDuration = Duration(
      seconds:
          _favoriteSongs.fold<int>(0, (sum, s) => sum + (s.duration ?? 0)),
    );

    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: SongListHeader(
                  title: l10n.favorites,
                  songCount: _favoriteSongs.length,
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
              if (_favoriteSongs.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite_border_rounded,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(l10n.noFavoriteSongsYet),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverFixedExtentList(
                  itemExtent: 68.0,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final song = displaySongs[index];
                      final tile = SongTile(
                        key: ValueKey(song.id),
                        song: song,
                        playlist: displaySongs,
                        index: index,
                        showAlbum: true,
                      );
                      return Dismissible(
                        key: ValueKey('fav_${song.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(CupertinoIcons.heart_slash,
                              color: Colors.white),
                        ),
                        onDismissed: (_) {
                          final originalIndex =
                              _favoriteSongs.indexOf(song);
                          if (originalIndex != -1) {
                            _removeFavorite(context, song, originalIndex);
                          }
                        },
                        child: tile,
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
    );
  }

  void _removeFavorite(
    BuildContext context,
    Song song,
    int index,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeFromFavoritesTitle),
        content: Text(l10n.removeFromFavoritesConfirm(song.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final subsonic = Provider.of<SubsonicService>(
                context,
                listen: false,
              );
              try {
                await subsonic.unstar(id: song.id);
                setState(() {
                  _favoriteSongs.removeAt(index);
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.removedFromFavorites)),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.failedToRemove(e.toString()))),
                  );
                }
              }
            },
            child: Text(l10n.remove, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumsList() {
    final l10n = AppLocalizations.of(context)!;
    if (_favoriteAlbums.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.album_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(l10n.noFavoriteAlbumsYet),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 5;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _favoriteAlbums.length,
          itemBuilder: (context, index) {
            final album = _favoriteAlbums[index];
            return AlbumCard(
              album: album,
              size: double.infinity,
              onTap: () => NavigationHelper.push(
                context,
                AlbumScreen(albumId: album.id),
              ),
            );
          },
        );
      },
    );
  }
}
