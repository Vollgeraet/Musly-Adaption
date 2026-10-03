import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/recommendation_service.dart';
import '../../services/subsonic_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/song_menu_actions.dart';
import '../../utils/song_sorting.dart';
import '../../widgets/common/floating_panel.dart';
import '../../widgets/common/song_list_header.dart';
import '../../widgets/widgets.dart';

enum SongCollectionType {
  allSongs,
  madeForYou,
  history,
  custom,
}

class SongCollectionScreen extends StatefulWidget {
  final SongCollectionType type;
  final String? customTitle;
  final List<Song>? initialSongs;
  final Future<List<Song>> Function(BuildContext context)? customFetcher;

  const SongCollectionScreen({
    super.key,
    required this.type,
    this.customTitle,
    this.initialSongs,
    this.customFetcher,
  });

  const SongCollectionScreen.allSongs({super.key})
      : type = SongCollectionType.allSongs,
        customTitle = null,
        initialSongs = null,
        customFetcher = null;

  const SongCollectionScreen.madeForYou({super.key})
      : type = SongCollectionType.madeForYou,
        customTitle = null,
        initialSongs = null,
        customFetcher = null;

  const SongCollectionScreen.history({super.key})
      : type = SongCollectionType.history,
        customTitle = null,
        initialSongs = null,
        customFetcher = null;

  @override
  State<SongCollectionScreen> createState() => _SongCollectionScreenState();
}

class _SongCollectionScreenState extends State<SongCollectionScreen> {
  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  SongSortOption _currentSort = SongSortOption.titleAsc;
  final TextEditingController _searchController = TextEditingController();
  Map<String, SongProfile> _profiles = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialSongs != null) {
      _songs = widget.initialSongs!;
      _filteredSongs = List.from(_songs);
      _isLoading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSongs();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSongs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Song> songs = [];
      if (widget.customFetcher != null) {
        songs = await widget.customFetcher!(context);
      } else {
        switch (widget.type) {
          case SongCollectionType.allSongs:
            final library =
                Provider.of<LibraryProvider>(context, listen: false);
            await library.ensureLibraryLoaded();
            songs = List.from(library.cachedAllSongs);
            break;

          case SongCollectionType.madeForYou:
            final subsonic =
                Provider.of<SubsonicService>(context, listen: false);
            songs = await subsonic.getRandomSongs(size: 50);
            break;

          case SongCollectionType.history:
            final recService =
                Provider.of<RecommendationService>(context, listen: false);
            final library =
                Provider.of<LibraryProvider>(context, listen: false);
            final profiles = recService.profiles;
            final allSongs = library.cachedAllSongs;
            final songMap = {for (var s in allSongs) s.id: s};

            final playedSongs = profiles.entries
                .where(
                    (e) => e.value.playCount > 0 && songMap.containsKey(e.key))
                .map((e) => MapEntry(songMap[e.key]!, e.value.lastPlayed))
                .toList();

            playedSongs.sort((a, b) => b.value.compareTo(a.value));
            songs = playedSongs.map((e) => e.key).take(100).toList();
            break;

          case SongCollectionType.custom:
            songs = widget.initialSongs ?? [];
            break;
        }
      }

      if (mounted) {
        final recService =
            Provider.of<RecommendationService>(context, listen: false);
        setState(() {
          _songs = songs;
          _profiles = recService.profiles;
          _applySortAndFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applySortAndFilter();
    });
  }

  void _applySortAndFilter() {
    List<Song> result = List.from(_songs);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) {
        return s.title.toLowerCase().contains(q) ||
            (s.artist?.toLowerCase().contains(q) ?? false) ||
            (s.album?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (widget.type == SongCollectionType.allSongs ||
        widget.type == SongCollectionType.custom) {
      result = sortSongs(result, _currentSort, _profiles);
    }

    _filteredSongs = result;
  }

  String _getTitle(BuildContext context) {
    if (widget.customTitle != null && widget.customTitle!.isNotEmpty) {
      return widget.customTitle!;
    }
    final l10n = AppLocalizations.of(context);
    switch (widget.type) {
      case SongCollectionType.allSongs:
        return l10n?.songs ?? 'All Songs';
      case SongCollectionType.madeForYou:
        return 'Made For You';
      case SongCollectionType.history:
        return 'Listening History';
      case SongCollectionType.custom:
        return 'Songs';
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_filteredSongs.isEmpty) return;
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final playlist = List<Song>.from(_filteredSongs);
    if (shuffle) playlist.shuffle();
    player.playSong(playlist.first, playlist: playlist, startIndex: 0);
  }

  /// Spielt EINEN zufälligen Titel aus der aktuellen (gefilterten) Liste,
  /// ohne die restliche Wiedergabeliste/-reihenfolge zu verändern.
  void _playRandomSong() {
    if (_filteredSongs.isEmpty) return;
    final player = Provider.of<PlayerProvider>(context, listen: false);
    final index =
        DateTime.now().millisecondsSinceEpoch % _filteredSongs.length;
    final random = _filteredSongs[index];
    player.playSong(random, playlist: _filteredSongs, startIndex: index);
  }

  Duration _calculateTotalDuration() {
    int totalSeconds = 0;
    for (var s in _filteredSongs) {
      totalSeconds += s.duration ?? 0;
    }
    return Duration(seconds: totalSeconds);
  }

  void _showSortSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showFloatingPanel(
      context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Text('Titel sortieren nach...',
                              style:
                                  Theme.of(sheetContext).textTheme.titleMedium),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: kSongSortLabels.entries.map((entry) {
                          final selected = _currentSort == entry.key;
                          return RadioListTile<SongSortOption>(
                            value: entry.key,
                            groupValue: _currentSort,
                            dense: true,
                            title: Text(entry.value,
                                style: TextStyle(
                                    color: selected
                                        ? Theme.of(sheetContext)
                                            .colorScheme
                                            .primary
                                        : null)),
                            onChanged: (opt) {
                              if (opt == null) return;
                              setState(() {
                                _currentSort = opt;
                                _applySortAndFilter();
                              });
                              setSheetState(() {});
                              Navigator.pop(sheetContext);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMoreMenu(BuildContext context) {
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
                      const SizedBox(height: 8),
                      _MenuTile(
                        icon: Icons.add_to_home_screen_rounded,
                        title: 'Verknüpfung auf Homescreen',
                        enabled: false,
                      ),
                      _MenuTile(
                        icon: Icons.shuffle_on_rounded,
                        title: 'Erweitertes Mischen',
                        enabled: false,
                      ),
                      _MenuTile(
                        icon: Icons.play_arrow_rounded,
                        title: 'Abspielen',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _playAll(shuffle: false);
                        },
                      ),
                      Divider(
                          height: 17,
                          indent: 16,
                          endIndent: 16,
                          color: dividerColor),
                      _MenuTile(
                        icon: Icons.playlist_play_rounded,
                        title: 'Nach dem aktuellen Titel spielen',
                        onTap: () async {
                          Navigator.pop(sheetContext);
                          for (final s in _filteredSongs.reversed) {
                            await player.addToQueueNext(s);
                          }
                        },
                      ),
                      _MenuTile(
                        icon: Icons.queue_music_rounded,
                        title: 'Zur aktuellen Warteschlange hinzufügen',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          player.addAllToQueue(_filteredSongs);
                        },
                      ),
                      _MenuTile(
                        icon: Icons.playlist_add_rounded,
                        title: 'Zu Warteschlange hinzufügen',
                        enabled: false,
                      ),
                      _MenuTile(
                        icon: Icons.library_add_rounded,
                        title: 'Zu Wiedergabelisten hinzufügen',
                        enabled: false,
                      ),
                      Divider(
                          height: 17,
                          indent: 16,
                          endIndent: 16,
                          color: dividerColor),
                      _MenuTile(
                        icon: Icons.edit_note_rounded,
                        title: 'Tags bearbeiten',
                        enabled: false,
                      ),
                      _MenuTile(
                        icon: Icons.speed_rounded,
                        title: 'Wiedergabegeschwindigkeit und Tonhöhe',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          SongMenuActions.showSpeedPitchDialog(context, player);
                        },
                      ),
                      _MenuTile(
                        icon: Icons.share_rounded,
                        title: 'Teilen',
                        enabled: false,
                      ),
                      Divider(
                          height: 17,
                          indent: 16,
                          endIndent: 16,
                          color: dividerColor),
                      _MenuTile(
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

  Widget _buildAllSongsHeaderSliver(
      BuildContext context, ThemeData theme, bool isDark) {
    final totalDuration = _calculateTotalDuration();
    return SliverToBoxAdapter(
      child: SongListHeader(
        title: 'Alle Titel',
        songCount: _filteredSongs.length,
        totalDuration: totalDuration,
        onRandom: _playRandomSong,
        onSort: () => _showSortSheet(context),
        onMore: () => _showMoreMenu(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = _getTitle(context);
    final totalDuration = _calculateTotalDuration();
    final isAllSongs = widget.type == SongCollectionType.allSongs;

    final listSlivers = <Widget>[
      if (_isLoading)
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error != null)
        _buildErrorState(theme)
      else if (_filteredSongs.isEmpty)
        _buildEmptyState(theme)
      else
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final song = _filteredSongs[index];
                return SongTile(
                  key: ValueKey(song.id),
                  song: song,
                  playlist: _filteredSongs,
                  index: index,
                  showAlbum: true,
                  showArtist: true,
                );
              },
              childCount: _filteredSongs.length,
            ),
          ),
        ),
    ];

    final scrollView = CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        if (isAllSongs)
          _buildAllSongsHeaderSliver(context, theme, isDark)
        else ...[
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: theme.appBarTheme.titleTextStyle ??
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              titlePadding: const EdgeInsets.only(left: 52, bottom: 16),
            ),
            actions: [
              if (widget.type == SongCollectionType.madeForYou)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: AppLocalizations.of(context)!.shuffleNewSelection,
                  onPressed: _loadSongs,
                ),
            ],
          ),
          if (!_isLoading && _error == null && _filteredSongs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    MediaPlayButton(
                      icon: Icons.play_arrow_rounded,
                      label: AppLocalizations.of(context)!.playAll,
                      onTap: () => _playAll(shuffle: false),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _playAll(shuffle: true),
                      icon: const Icon(Icons.shuffle_rounded, size: 20),
                      label: Text(AppLocalizations.of(context)!.shuffle),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${AppLocalizations.of(context)!.songsCount(_filteredSongs.length)} • ${FormatUtils.formatDurationSummary(totalDuration)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.darkSecondaryText
                            : AppTheme.lightSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        ...listSlivers,
      ],
    );

    if (!isAllSongs) {
      return Scaffold(
        body: RefreshIndicator(onRefresh: _loadSongs, child: scrollView),
      );
    }

    // "Alle Titel": zusätzlich eine ein-/ausblendbare Such-Zeile direkt
    // über der Navigationsleiste (siehe Einstellungen-Gear oben).
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(onRefresh: _loadSongs, child: scrollView),
          ),
          SongListSearchBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: AppTheme.lightSecondaryText),
            const SizedBox(height: 16),
            Text(l10n.errorLoadingSongs, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadSongs,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off_outlined,
                size: 64, color: AppTheme.lightSecondaryText),
            const SizedBox(height: 16),
            Text(l10n.noSongsAvailable, style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class AllSongsScreen extends StatelessWidget {
  const AllSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SongCollectionScreen.allSongs();
  }
}

class SongsScreen extends StatelessWidget {
  const SongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SongCollectionScreen.madeForYou();
  }
}

class MadeForYouScreen extends StatelessWidget {
  const MadeForYouScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SongCollectionScreen.madeForYou();
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SongCollectionScreen.history();
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool enabled;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledColor = theme.disabledColor;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: ListTile(
        leading: Icon(icon, color: enabled ? theme.colorScheme.primary : disabledColor),
        title: Text(title, style: TextStyle(color: enabled ? null : disabledColor)),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
