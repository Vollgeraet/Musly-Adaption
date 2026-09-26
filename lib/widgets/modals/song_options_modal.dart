import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/subsonic_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/song_menu_actions.dart';
import 'song_info_modal.dart';

class SongOptionsModal extends StatefulWidget {
  static Future<void> show(BuildContext context, Song song) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // Lässt oben etwas Hintergrund sichtbar (wie ein schwebendes
      // Panel statt einer Vollbild-Fläche), analog zu Musicolet.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      builder: (context) => SongOptionsModal(song: song),
    );
  }

  final Song song;

  const SongOptionsModal({super.key, required this.song});

  @override
  State<SongOptionsModal> createState() => _SongOptionsModalState();
}

class _SongOptionsModalState extends State<SongOptionsModal> {
  late bool _isStarred;

  @override
  void initState() {
    super.initState();
    _isStarred = widget.song.starred ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final dividerColor = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;
    final canDelete = SongMenuActions.canDeletePermanently(widget.song);

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
            const SizedBox(height: 16),
            // Kopfzeile: nur Titel + Herz-Icon, kein Cover mehr hier.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.song.title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isStarred ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                      color: _isStarred ? theme.colorScheme.primary : null,
                    ),
                    onPressed: () => _toggleFavorite(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    _OptionTile(
                      icon: CupertinoIcons.info,
                      title: 'Titel-Infos',
                      onTap: () {
                        Navigator.pop(context);
                        SongInfoModal.show(context, widget.song);
                      },
                    ),
                    Divider(height: 17, indent: 16, endIndent: 16, color: dividerColor),
                    _OptionTile(
                      icon: Icons.playlist_play_rounded,
                      title: 'Nach dem aktuellen Titel spielen',
                      onTap: () {
                        playerProvider.addToQueueNext(widget.song);
                        Navigator.pop(context);
                      },
                    ),
                    _OptionTile(
                      icon: Icons.queue_music_rounded,
                      title: 'Zur aktuellen Warteschlange hinzufügen',
                      onTap: () {
                        playerProvider.addToQueue(widget.song);
                        Navigator.pop(context);
                      },
                    ),
                    const _OptionTile(
                      icon: Icons.playlist_add_rounded,
                      title: 'Zu Warteschlange hinzufügen',
                      enabled: false,
                    ),
                    _OptionTile(
                      icon: Icons.library_add_rounded,
                      title: 'Zu Wiedergabelisten hinzufügen',
                      onTap: () {
                        Navigator.pop(context);
                        SongMenuActions.showPlaylistPicker(context, widget.song);
                      },
                    ),
                    Divider(height: 17, indent: 16, endIndent: 16, color: dividerColor),
                    const _OptionTile(
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Vorschau',
                      enabled: false,
                    ),
                    const _OptionTile(
                      icon: Icons.edit_note_rounded,
                      title: 'Tags bearbeiten',
                      enabled: false,
                    ),
                    const _OptionTile(
                      icon: Icons.drive_file_move_rounded,
                      title: 'In Ordner verschieben',
                      enabled: false,
                    ),
                    const _OptionTile(
                      icon: Icons.content_cut_rounded,
                      title: 'Audio-Cutter',
                      enabled: false,
                    ),
                    const _OptionTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Als Klingelton verwenden',
                      enabled: false,
                    ),
                    _OptionTile(
                      icon: Icons.speed_rounded,
                      title: 'Wiedergabegeschwindigkeit und Tonhöhe',
                      onTap: () {
                        Navigator.pop(context);
                        SongMenuActions.showSpeedPitchDialog(context, playerProvider);
                      },
                    ),
                    const _OptionTile(
                      icon: Icons.share_rounded,
                      title: 'Teilen',
                      enabled: false,
                    ),
                    _OptionTile(
                      icon: Icons.delete_forever_rounded,
                      title: 'Dauerhaft löschen',
                      enabled: canDelete,
                      iconColor: canDelete ? Colors.redAccent : null,
                      onTap: canDelete
                          ? () {
                              Navigator.pop(context);
                              SongMenuActions.deleteLocalSongPermanently(
                                  context, widget.song);
                            }
                          : null,
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

  Future<void> _toggleFavorite(BuildContext context) async {
    final subsonicService = Provider.of<SubsonicService>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (_isStarred) {
        await subsonicService.unstar(id: widget.song.id);
        setState(() => _isStarred = false);
        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(l10n.removedFromLikedSongs),
            duration: const Duration(seconds: 2),
          ));
        }
      } else {
        await subsonicService.star(id: widget.song.id);
        setState(() => _isStarred = true);
        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(l10n.addedToLikedSongs),
            duration: const Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text('${l10n.error}: ${e.toString()}'),
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool enabled;

  const _OptionTile({
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
        leading: Icon(
          icon,
          color: enabled ? (iconColor ?? theme.colorScheme.primary) : disabledColor,
        ),
        title: Text(title, style: TextStyle(color: enabled ? null : disabledColor)),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
