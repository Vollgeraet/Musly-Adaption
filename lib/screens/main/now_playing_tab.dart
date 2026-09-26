import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:musly/models/song.dart';
import 'package:musly/providers/player_provider.dart';
import 'package:musly/services/subsonic_service.dart';
import 'package:musly/theme/app_theme.dart';
import 'package:musly/screens/player/now_playing_screen.dart';

/// Wraps [NowPlayingScreen] so it can live as a permanent bottom-nav
/// tab (position 2 in the nav bar) instead of only being reachable
/// via the mini-player's modal sheet. Shows an empty state when
/// nothing is currently playing.
class NowPlayingTab extends StatelessWidget {
  const NowPlayingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PlayerProvider, Song?>(
      selector: (_, p) => p.currentSong,
      builder: (context, currentSong, _) {
        if (currentSong == null) {
          return const _EmptyNowPlaying();
        }

        final subsonic = Provider.of<SubsonicService>(context, listen: false);
        final coverUrl = currentSong.coverArt != null
            ? subsonic.getCoverArtUrl(currentSong.coverArt, size: 600)
            : null;
        final imageProvider = (coverUrl != null && coverUrl.isNotEmpty)
            ? CachedNetworkImageProvider(coverUrl) as ImageProvider
            : const AssetImage('assets/logo.png') as ImageProvider;
        final topPadding = MediaQuery.of(context).padding.top;

        return NowPlayingScreen(
          embedded: true,
          topPadding: topPadding,
          image: imageProvider,
          title: currentSong.title,
          artist: (currentSong.artistParticipants?.isNotEmpty == true
                  ? currentSong.artistParticipants!
                      .map((a) => a.name)
                      .join(', ')
                  : currentSong.artist) ??
              '',
          heroTag: 'cover_${currentSong.id}',
          song: currentSong,
        );
      },
    );
  }
}

class _EmptyNowPlaying extends StatelessWidget {
  const _EmptyNowPlaying({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.music_note,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'Gerade läuft nichts',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
