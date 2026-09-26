import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:musly/providers/library_provider.dart';
import 'package:musly/screens/media/all_songs_screen.dart';
import 'package:musly/theme/app_theme.dart';

/// Position 1 in the bottom nav ("Alle Songs" / Startseite). Shows
/// every song from Navidrome and the local device library merged
/// into a single, always-up-to-date list, using the existing
/// [LibraryProvider.cachedAllSongs] getter which already performs
/// that merge.
class AllSongsTab extends StatelessWidget {
  const AllSongsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, libraryProvider, _) {
        if (libraryProvider.isLoading && !libraryProvider.isInitialized) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor:
                isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
            appBar: AppBar(title: const Text('Alle Songs')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return AllSongsScreen(
          title: 'Alle Songs',
          songs: libraryProvider.cachedAllSongs,
        );
      },
    );
  }
}
