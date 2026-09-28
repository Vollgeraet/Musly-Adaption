import 'package:flutter/material.dart';
import '../media/song_collection_screen.dart';

/// Position 1 in der Navigationsleiste ("Alle Songs" / Startseite).
/// Nutzt SongCollectionScreen.allSongs(), das Navidrome- und lokale
/// Songs bereits selbst zusammenführt (LibraryProvider.cachedAllSongs)
/// und die vollständige Kopfzeile (Anzahl/Dauer, Sortieren, Mehr,
/// Such-Zeile) mitbringt.
class AllSongsTab extends StatelessWidget {
  const AllSongsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SongCollectionScreen.allSongs();
  }
}
