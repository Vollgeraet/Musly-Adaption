import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../models/song.dart';
import '../providers/player_provider.dart';
import '../providers/library_provider.dart';
import '../services/subsonic_service.dart';
import '../services/local_music_service.dart';

/// Aktionen, die sowohl aus dem Song-Optionsmenü (drei Punkte bei einem
/// Titel) als auch aus dem "..."-Menü der Now-Playing-Ansicht heraus
/// aufgerufen werden können, gebündelt an einer Stelle statt dupliziert.
class SongMenuActions {
  SongMenuActions._();

  static void showSpeedPitchDialog(
      BuildContext context, PlayerProvider playerProvider) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Text('Wiedergabegeschwindigkeit und Tonhöhe'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Geschwindigkeit: ${playerProvider.playbackSpeed.toStringAsFixed(2)}x'),
                Slider(
                  min: 0.25,
                  max: 2.0,
                  divisions: 35,
                  value: playerProvider.playbackSpeed.clamp(0.25, 2.0),
                  onChanged: (val) {
                    playerProvider.setPlaybackSpeed(val);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Text('Tonhöhe: ${playerProvider.pitch.toStringAsFixed(2)}x'),
                Slider(
                  min: 0.5,
                  max: 2.0,
                  divisions: 30,
                  value: playerProvider.pitch.clamp(0.5, 2.0),
                  onChanged: playerProvider.pitchCorrection
                      ? null
                      : (val) {
                          playerProvider.setPitch(val);
                          setDialogState(() {});
                        },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tonhöhe an Geschwindigkeit koppeln'),
                  value: playerProvider.pitchCorrection,
                  onChanged: (_) {
                    playerProvider.togglePitchCorrection();
                    setDialogState(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fertig'),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool canDeletePermanently(Song song) =>
      song.isLocal && (song.path?.isNotEmpty ?? false);

  static Future<void> deleteLocalSongPermanently(
    BuildContext context,
    Song song, {
    VoidCallback? onDeleted,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final localMusicService =
        Provider.of<LocalMusicService>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dauerhaft löschen'),
        content: Text(
          '"${song.title}" wird unwiderruflich von diesem Gerät gelöscht. Fortfahren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final path = song.path;
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await localMusicService.removeSongById(song.id);
      onDeleted?.call();

      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('"${song.title}" wurde gelöscht'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Löschen fehlgeschlagen: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  static void showPlaylistPicker(BuildContext context, Song song) {
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.addToPlaylist,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (libraryProvider.playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(AppLocalizations.of(context)!.noPlaylists),
              )
            else
              ...libraryProvider.playlists.map(
                (playlist) => ListTile(
                  leading: const Icon(Icons.queue_music_rounded),
                  title: Text(playlist.name),
                  subtitle: Text(AppLocalizations.of(context)!
                      .songsCount(playlist.songCount ?? 0)),
                  onTap: () async {
                    Navigator.pop(context);

                    final subsonicService = Provider.of<SubsonicService>(
                      context,
                      listen: false,
                    );
                    final l10n = AppLocalizations.of(context)!;
                    final messenger = ScaffoldMessenger.of(context);

                    bool isDuplicate = false;
                    try {
                      final fullPlaylist =
                          await subsonicService.getPlaylist(playlist.id);
                      final existingSongs =
                          fullPlaylist.songs ?? playlist.songs ?? [];
                      isDuplicate = existingSongs.any(
                        (s) =>
                            s.id == song.id ||
                            (s.title.trim().toLowerCase() ==
                                    song.title.trim().toLowerCase() &&
                                (s.artist ?? '').trim().toLowerCase() ==
                                    (song.artist ?? '').trim().toLowerCase()),
                      );
                    } catch (_) {
                      if (playlist.songs != null) {
                        isDuplicate =
                            playlist.songs!.any((s) => s.id == song.id);
                      }
                    }

                    if (isDuplicate) {
                      if (!context.mounted) return;
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(l10n.alreadyInPlaylist),
                          content: Text(
                            l10n.alreadyInPlaylistConfirm(
                                song.title, playlist.name),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(l10n.cancel),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l10n.addAnyway),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                    }

                    try {
                      await subsonicService.updatePlaylist(
                        playlistId: playlist.id,
                        songIdsToAdd: [song.id],
                      );
                      await libraryProvider.loadPlaylists();

                      messenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    'Added "${song.title}" to ${playlist.name}'),
                              ),
                            ],
                          ),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(child: Text(l10n.errorAddingToPlaylist(e))),
                            ],
                          ),
                          duration: const Duration(seconds: 3),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
