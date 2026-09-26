import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../utils/song_menu_actions.dart';
import '../modals/song_info_modal.dart';
import 'now_playing_more_overlay.dart';

/// Reihe unterhalb der Wiedergabe-Steuerung: Herz (Favorit), Titel-Infos,
/// zu Wiedergabelisten hinzufügen und "..." (öffnet das ausführliche
/// Musicolet-artige Menü). Ersetzt die frühere Connect-to-device /
/// Lyrics / Warteschlange-Reihe.
class NowPlayingBottomActions extends StatelessWidget {
  final Song? song;
  final VoidCallback onShowLyrics;

  const NowPlayingBottomActions({
    super.key,
    required this.song,
    required this.onShowLyrics,
  });

  @override
  Widget build(BuildContext context) {
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    final isStarred = song?.starred ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: isStarred ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isStarred ? Theme.of(context).colorScheme.primary : Colors.white70,
            onTap: song == null ? null : () => playerProvider.toggleFavorite(),
          ),
          _ActionButton(
            icon: Icons.info_outline_rounded,
            onTap: song == null ? null : () => SongInfoModal.show(context, song!),
          ),
          _ActionButton(
            icon: Icons.playlist_add_rounded,
            onTap: song == null
                ? null
                : () => SongMenuActions.showPlaylistPicker(context, song!),
          ),
          _ActionButton(
            icon: Icons.more_horiz_rounded,
            onTap: song == null
                ? null
                : () => NowPlayingMoreOverlay.show(
                      context,
                      song!,
                      onShowLyrics: onShowLyrics,
                    ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _ActionButton({
    required this.icon,
    this.onTap,
    this.color = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, color: onTap == null ? Colors.white24 : color, size: 24),
      onPressed: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
    );
  }
}
