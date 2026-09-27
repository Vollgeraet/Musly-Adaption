import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../utils/song_menu_actions.dart';
import '../modals/song_info_modal.dart';
import 'now_playing_more_overlay.dart';
import 'repeat_mode_menu.dart';

/// Reihe unterhalb von Titel/Interpret: links geclustert Herz, Info,
/// Playlist+, "..."; rechts Wiederholung (öffnet Musicolet-artiges
/// Wiederholungs-Menü) und Zufallswiedergabe-Umschalter.
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
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: isStarred
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: isStarred
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white70,
                onTap:
                    song == null ? null : () => playerProvider.toggleFavorite(),
              ),
              _ActionButton(
                icon: Icons.info_outline_rounded,
                onTap: song == null
                    ? null
                    : () => SongInfoModal.show(context, song!),
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
          Consumer<PlayerProvider>(
            builder: (context, provider, _) {
              final repeatActive = provider.repeatMode != RepeatMode.off;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: Icons.repeat_rounded,
                    color: repeatActive
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white70,
                    onTap: () => RepeatModeMenu.show(context, provider),
                  ),
                  _ActionButton(
                    icon: provider.shuffleEnabled
                        ? Icons.shuffle_on_rounded
                        : Icons.shuffle_rounded,
                    color: provider.shuffleEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white70,
                    onTap: () => provider.toggleShuffle(),
                  ),
                ],
              );
            },
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
