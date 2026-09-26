import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/song_menu_actions.dart';

/// Das ausführliche "..."-Menü aus der Now-Playing-Ansicht (Musicolet-
/// Vorbild). Wie das Song-Optionsmenü ein schwebendes Panel, das nicht
/// den ganzen Bildschirm verdeckt.
class NowPlayingMoreOverlay extends StatelessWidget {
  static Future<void> show(
    BuildContext context,
    Song song, {
    required VoidCallback onShowLyrics,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      builder: (context) =>
          NowPlayingMoreOverlay(song: song, onShowLyrics: onShowLyrics),
    );
  }

  final Song song;
  final VoidCallback onShowLyrics;

  const NowPlayingMoreOverlay({
    super.key,
    required this.song,
    required this.onShowLyrics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final canDelete = SongMenuActions.canDeletePermanently(song);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: dividerColor,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    _Tile(
                      icon: Icons.subtitles_outlined,
                      title: 'Songtext anzeigen',
                      onTap: () {
                        Navigator.pop(context);
                        onShowLyrics();
                      },
                    ),
                    const _Tile(
                      icon: Icons.bookmark_border_rounded,
                      title: 'Lesezeichen/Notizen',
                      enabled: false,
                    ),
                    const _Tile(
                      icon: Icons.repeat_on_rounded,
                      title: 'A-B Wiederholung',
                      enabled: false,
                    ),
                    _Tile(
                      icon: Icons.speed_rounded,
                      title: 'Wiedergabegeschwindigkeit und Tonhöhe',
                      onTap: () {
                        Navigator.pop(context);
                        SongMenuActions.showSpeedPitchDialog(context, playerProvider);
                      },
                    ),
                    Divider(height: 17, indent: 16, endIndent: 16, color: dividerColor),
                    const _Tile(
                      icon: Icons.playlist_add_rounded,
                      title: 'Zu Warteschlange hinzufügen',
                      enabled: false,
                    ),
                    _Tile(
                      icon: Icons.library_add_rounded,
                      title: 'Zu Wiedergabelisten hinzufügen',
                      onTap: () {
                        Navigator.pop(context);
                        SongMenuActions.showPlaylistPicker(context, song);
                      },
                    ),
                    Divider(height: 17, indent: 16, endIndent: 16, color: dividerColor),
                    const _Tile(
                      icon: Icons.edit_note_rounded,
                      title: 'Tags bearbeiten',
                      enabled: false,
                    ),
                    const _Tile(
                      icon: Icons.drive_file_move_rounded,
                      title: 'In Ordner verschieben',
                      enabled: false,
                    ),
                    const _Tile(
                      icon: Icons.content_cut_rounded,
                      title: 'Audio-Cutter',
                      enabled: false,
                    ),
                    const _Tile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Als Klingelton verwenden',
                      enabled: false,
                    ),
                    const _Tile(
                      icon: Icons.share_rounded,
                      title: 'Titel teilen',
                      enabled: false,
                    ),
                    _Tile(
                      icon: Icons.delete_forever_rounded,
                      title: 'Dauerhaft löschen',
                      enabled: canDelete,
                      iconColor: canDelete ? Colors.redAccent : null,
                      onTap: canDelete
                          ? () {
                              Navigator.pop(context);
                              SongMenuActions.deleteLocalSongPermanently(context, song);
                            }
                          : null,
                    ),
                    Divider(height: 17, indent: 16, endIndent: 16, color: dividerColor),
                    const _Tile(
                      icon: Icons.tune_rounded,
                      title: 'Anzeigen/verstecken/anpassen',
                      enabled: false,
                    ),
                    const _Tile(
                      icon: Icons.more_horiz_rounded,
                      title: '"Schnellzugriff"-Kürzel',
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
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool enabled;

  const _Tile({
    required this.icon,
    required this.title,
    this.onTap,
    this.iconColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledColor = theme.disabledColor;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: ListTile(
        leading: Icon(icon, color: enabled ? (iconColor ?? theme.colorScheme.primary) : disabledColor),
        title: Text(title, style: TextStyle(color: enabled ? null : disabledColor)),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
