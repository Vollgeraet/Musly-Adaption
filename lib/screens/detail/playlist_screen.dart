import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:musly/models/models.dart';
import 'package:musly/providers/providers.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/services/offline_service.dart';
import 'package:musly/services/favorite_playlists_service.dart';
import 'package:musly/services/playlist_cover_service.dart';
import 'package:musly/services/recommendation_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/widgets/widgets.dart';
import 'package:musly/widgets/common/song_list_header.dart';
import 'package:musly/widgets/common/floating_panel.dart';
import 'package:musly/utils/song_sorting.dart';
import 'package:musly/utils/song_menu_actions.dart';
import 'package:musly/l10n/app_localizations.dart';
import 'package:musly/utils/screen_helper.dart';

class PlaylistScreen extends StatefulWidget {
  final String playlistId;
  final String? playlistName;

  const PlaylistScreen({
    super.key,
    required this.playlistId,
    this.playlistName,
  });

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  Playlist? _playlist;
  bool _isLoading = true;
  bool _isSelecting = false;
  bool _isReordering = false;
  String _searchQuery = '';
  SongSortOption _currentSort = SongSortOption.titleAsc;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedIndices = {};

  bool _allDownloaded = false;
  bool _isQueued = false;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
    OfflineService().downloadedPlaylistIds.addListener(_updateDownloadState);
    OfflineService().queuedPlaylistIds.addListener(_updateDownloadState);
  }

  @override
  void dispose() {
    OfflineService().downloadedPlaylistIds.removeListener(_updateDownloadState);
    OfflineService().queuedPlaylistIds.removeListener(_updateDownloadState);
    _searchController.dispose();
    super.dispose();
  }

  void _updateDownloadState() {
    if (!mounted) return;
    final offline = OfflineService();
    final allDown =
        offline.downloadedPlaylistIds.value.contains(widget.playlistId);
    final queued = offline.queuedPlaylistIds.value.contains(widget.playlistId);
    if (allDown != _allDownloaded || queued != _isQueued) {
      setState(() {
        _allDownloaded = allDown;
        _isQueued = queued;
      });
    }
  }

  Future<void> _loadPlaylist() async {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );

    try {
      final playlist = await libraryProvider.getPlaylist(widget.playlistId);
      if (mounted) {
        setState(() {
          _playlist = playlist;
          _isLoading = false;
        });
        _updateDownloadState();
      }
      if (playlist.songs != null && playlist.songs!.isNotEmpty) {
        PlaylistCoverService().checkAndGenerateCover(
          playlistId: widget.playlistId,
          songs: playlist.songs!,
          subsonicService: subsonicService,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _playAll({bool shuffle = false}) {
    if (_playlist?.songs == null || _playlist!.songs!.isEmpty) return;

    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);

    var songs = List.from(_playlist!.songs!);
    if (shuffle) {
      songs.shuffle();
    }

    playerProvider.playSong(songs.first, playlist: songs.cast(), startIndex: 0);
  }

  void _playRandomSong(List<Song> songs) {
    if (songs.isEmpty) return;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final index = DateTime.now().millisecondsSinceEpoch % songs.length;
    final song = songs[index];
    playerProvider.playSong(song, playlist: songs, startIndex: index);
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim().toLowerCase());
  }

  void _showPlaylistMoreMenu(BuildContext context, List<Song> displaySongs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final canReorder = (_playlist?.songs?.length ?? 0) > 1;

    showFloatingPanel(
      context,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
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
                          _playAll(shuffle: false);
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
                          for (final s in displaySongs.reversed) {
                            await playerProvider.addToQueueNext(s);
                          }
                        },
                      ),
                      ListMenuTile(
                        icon: Icons.queue_music_rounded,
                        title: 'Zur aktuellen Warteschlange hinzufügen',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          playerProvider.addAllToQueue(displaySongs);
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
                          SongMenuActions.showSpeedPitchDialog(
                              context, playerProvider);
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
                        icon: CupertinoIcons.arrow_up_arrow_down,
                        title: 'Titel manuell anordnen',
                        enabled: canReorder,
                        onTap: canReorder
                            ? () {
                                Navigator.pop(sheetContext);
                                _toggleReorderMode();
                              }
                            : null,
                      ),
                      ListMenuTile(
                        icon: CupertinoIcons.checkmark_circle,
                        title: 'Wählen Sie mehrere aus',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _toggleSelectMode();
                        },
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

  Future<void> _removeSongFromPlaylist(int index) async {
    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );
    try {
      final updatedSongs = List<Song>.from(_playlist!.songs!)..removeAt(index);
      await subsonicService.updatePlaylist(
        playlistId: widget.playlistId,
        songIndexesToRemove: [index],
      );
      setState(() {
        _playlist = _playlist!.copyWith(
          songCount: updatedSongs.length,
          songs: updatedSongs,
        );
      });
      PlaylistCoverService().checkAndGenerateCover(
        playlistId: widget.playlistId,
        songs: updatedSongs,
        subsonicService: subsonicService,
      );
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.songRemovedFromPlaylist),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorRemovingSong(e.toString())),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelecting = !_isSelecting;
      _isReordering = false;
      _selectedIndices.clear();
    });
  }

  void _toggleReorderMode() {
    setState(() {
      _isReordering = !_isReordering;
      _isSelecting = false;
      _selectedIndices.clear();
    });
  }

  Future<void> _onSongReorderedItem(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );

    final updatedSongs = List<Song>.from(_playlist!.songs!);
    final song = updatedSongs.removeAt(oldIndex);
    updatedSongs.insert(newIndex, song);

    setState(() {
      _playlist = _playlist!.copyWith(songs: updatedSongs);
    });

    PlaylistCoverService().checkAndGenerateCover(
      playlistId: widget.playlistId,
      songs: updatedSongs,
      subsonicService: subsonicService,
    );

    try {
      await subsonicService.updatePlaylist(
        playlistId: widget.playlistId,
        songIndexesToRemove: [oldIndex],
        songIdsToAdd: [
          _playlist!.songs![newIndex].id,
        ],
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorReorderingSong(e.toString())),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _loadPlaylist();
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _toggleSelectAll() {
    final songCount = _playlist?.songs?.length ?? 0;
    setState(() {
      if (_selectedIndices.length == songCount) {
        _selectedIndices.clear();
      } else {
        _selectedIndices.addAll(List.generate(songCount, (i) => i));
      }
    });
  }

  Future<void> _removeSelected() async {
    if (_selectedIndices.isEmpty) return;
    final count = _selectedIndices.length;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeSongsTitle),
        content: Text(
          l10n.removePlaylistSongsConfirm(count, _playlist!.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.remove, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final sortedIndices = List<int>.from(_selectedIndices)
      ..sort((a, b) => b.compareTo(a));

    final subsonicService = Provider.of<SubsonicService>(
      context,
      listen: false,
    );
    final updatedSongs = List<Song>.from(_playlist!.songs!);
    for (final index in sortedIndices) {
      if (index < updatedSongs.length) {
        updatedSongs.removeAt(index);
      }
    }

    try {
      await subsonicService.updatePlaylist(
        playlistId: widget.playlistId,
        songIndexesToRemove: sortedIndices,
      );

      setState(() {
        _playlist = _playlist!.copyWith(
          songs: updatedSongs,
        );
        _selectedIndices.clear();
        _isSelecting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.removedSongsFromPlaylist(count),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorRemovingSong(e.toString())),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_playlist == null) return;
    await FavoritePlaylistsService().toggleFavorite(widget.playlistId);
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FavoritePlaylistsService().isFavorite(widget.playlistId)
                ? l10n.addedToFavorites
                : l10n.removedFromFavorites,
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _downloadPlaylist() async {
    final songs = _playlist?.songs;
    if (songs == null || songs.isEmpty) return;
    final offlineService = OfflineService();
    final subsonicService =
        Provider.of<SubsonicService>(context, listen: false);
    await offlineService.initialize();
    offlineService.queuePlaylistDownload(
        widget.playlistId, songs, subsonicService);
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.queuedSongsForDownload(songs.length)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _cancelDownload() async {
    await OfflineService().cancelPlaylistDownload(widget.playlistId);
  }

  Future<void> _removeDownloads() async {
    final songs = _playlist?.songs ?? [];
    if (songs.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.removeDownloadsTitle),
        content: Text(
            l10n.removePlaylistDownloadsConfirm(songs.length, _playlist!.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.remove, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await OfflineService().cancelPlaylistDownload(widget.playlistId);
      await OfflineService().deletePlaylistDownloads(songs);
    }
  }

  Widget _buildDownloadButton(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_allDownloaded) {
      return IconButton(
        tooltip: l10n.downloadedTapToRemove,
        onPressed: _removeDownloads,
        icon: const Icon(Icons.cloud_done, color: Colors.green),
      );
    }
    if (_isQueued) {
      return IconButton(
        tooltip: l10n.downloadingTapToCancel,
        onPressed: _cancelDownload,
        icon: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: l10n.downloadPlaylist,
      onPressed: _downloadPlaylist,
      icon: const Icon(CupertinoIcons.cloud_download),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title:
              widget.playlistName != null ? Text(widget.playlistName!) : null,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body:
            Center(child: Text(AppLocalizations.of(context)!.playlistNotFound)),
      );
    }

    final isOffline = Provider.of<AuthProvider>(context, listen: false).state ==
        AuthState.offlineMode;

    if (_isReordering) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.reorderSongs),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.xmark),
            onPressed: _toggleReorderMode,
          ),
          actions: [
            IconButton(
              tooltip: AppLocalizations.of(context)!.doneReordering,
              icon: const Icon(CupertinoIcons.checkmark),
              onPressed: _toggleReorderMode,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ValueListenableBuilder<Set<String>>(
                    valueListenable: OfflineService().downloadedPlaylistIds,
                    builder: (context, downloaded, _) {
                      final allDownloaded =
                          downloaded.contains(widget.playlistId);
                      return Stack(
                        children: [
                          PlaylistArtwork(
                            playlist: _playlist,
                            songs: _playlist?.songs,
                            size: 150,
                            borderRadius: 12,
                          ),
                          if (allDownloaded)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 24,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _playlist!.name,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_playlist!.songs?.length ?? 0} songs • ${_playlist!.formattedDuration}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _PlayButton(
                          icon: CupertinoIcons.play_fill,
                          label: AppLocalizations.of(context)!.play,
                          onTap: () => _playAll(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlayButton(
                          icon: CupertinoIcons.shuffle,
                          label: AppLocalizations.of(context)!.shuffle,
                          onTap: () => _playAll(shuffle: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 150),
                itemCount: _playlist!.songs!.length,
                buildDefaultDragHandles: false,
                onReorder: _onSongReorderedItem,
                itemBuilder: (context, index) {
                  final song = _playlist!.songs![index];
                  return ListTile(
                    key: ValueKey('reorder_${song.id}_$index'),
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        CupertinoIcons.line_horizontal_3,
                        color: isDark
                            ? AppTheme.darkSecondaryText
                            : AppTheme.lightSecondaryText,
                      ),
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    final recProfiles =
        Provider.of<RecommendationService>(context, listen: false).profiles;
    final baseSongs = _playlist!.songs ?? [];
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
            child: RefreshIndicator(
              onRefresh: _loadPlaylist,
              child: CustomScrollView(
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: SongListHeader(
                      title: _playlist!.name,
                      songCount: baseSongs.length,
                      totalDuration: totalDuration,
                      onRandom: () => _playRandomSong(displaySongs),
                      onSort: () => showSongSortPanel(
                        context,
                        current: _currentSort,
                        onSelected: (opt) =>
                            setState(() => _currentSort = opt),
                      ),
                      onMore: () =>
                          _showPlaylistMoreMenu(context, displaySongs),
                      extraActions: [
                        AnimatedBuilder(
                          animation: FavoritePlaylistsService(),
                          builder: (context, child) {
                            final isFavorite = FavoritePlaylistsService()
                                .isFavorite(widget.playlistId);
                            return IconButton(
                              tooltip: isFavorite
                                  ? AppLocalizations.of(context)!
                                      .removeFromFavorites
                                  : AppLocalizations.of(context)!
                                      .addToFavorites,
                              icon: Icon(
                                isFavorite
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                color: isFavorite ? Colors.red : null,
                                size: 20,
                              ),
                              onPressed: _toggleFavorite,
                            );
                          },
                        ),
                        if (!isOffline) _buildDownloadButton(context),
                      ],
                      replacementActionBar: _isSelecting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: _selectedIndices.length ==
                                          baseSongs.length
                                      ? 'Deselect all'
                                      : 'Select all',
                                  icon: Icon(
                                    _selectedIndices.length ==
                                            baseSongs.length
                                        ? CupertinoIcons.checkmark_square
                                        : CupertinoIcons.square,
                                  ),
                                  onPressed: _toggleSelectAll,
                                ),
                                IconButton(
                                  tooltip: AppLocalizations.of(context)!
                                      .removeSelected,
                                  icon: const Icon(CupertinoIcons.trash),
                                  color: _selectedIndices.isNotEmpty
                                      ? Colors.red
                                      : null,
                                  onPressed: _selectedIndices.isNotEmpty
                                      ? _removeSelected
                                      : null,
                                ),
                                TextButton(
                                  onPressed: _toggleSelectMode,
                                  child: Text(
                                      AppLocalizations.of(context)!.done),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  if (baseSongs.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Center(
                          child: Text(
                            'No songs in this playlist',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.lightSecondaryText,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (_isSelecting)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = baseSongs[index];
                          final isSelected =
                              _selectedIndices.contains(index);
                          return CheckboxListTile(
                            key: ValueKey('sel_${song.id}_$index'),
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(index),
                            activeColor:
                                Theme.of(context).colorScheme.primary,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            contentPadding:
                                const EdgeInsets.only(left: 4, right: 16),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              song.artist ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            secondary: IconButton(
                              icon:
                                  const Icon(CupertinoIcons.trash, size: 20),
                              color: Colors.red,
                              tooltip: AppLocalizations.of(context)!
                                  .removeFromPlaylist,
                              onPressed: () async {
                                setState(
                                    () => _selectedIndices.remove(index));
                                await _removeSongFromPlaylist(index);
                              },
                            ),
                          );
                        },
                        childCount: baseSongs.length,
                      ),
                    )
                  else
                    SliverFixedExtentList(
                      itemExtent: 68.0,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = displaySongs[index];
                          final tile = SongTile(
                            song: song,
                            playlist: displaySongs,
                            index: index,
                            showArtist: true,
                          );
                          return Dismissible(
                            key: ValueKey('${song.id}_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(
                                CupertinoIcons.trash,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) {
                              final originalIndex =
                                  _playlist!.songs!.indexOf(song);
                              if (originalIndex != -1) {
                                _removeSongFromPlaylist(originalIndex);
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
          ),
          if (!_isSelecting)
            SongListSearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PlayButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Material(
      color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
