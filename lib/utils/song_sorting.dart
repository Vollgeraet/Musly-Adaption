import 'package:path/path.dart' as p;
import '../models/models.dart';
import '../services/recommendation_service.dart';

/// Sortieroptionen für Titellisten ("Alle Titel", Wiedergabelisten, ...).
enum SongSortOption {
  titleAsc,
  titleDesc,
  filenameAsc,
  filenameDesc,
  filepathAsc,
  filepathDesc,
  folderNameAsc,
  folderNameDesc,
  folderPathAsc,
  folderPathDesc,
  albumAsc,
  albumDesc,
  artistAsc,
  artistDesc,
  albumArtistAsc,
  albumArtistDesc,
  composerAsc,
  composerDesc,
  genreAsc,
  genreDesc,
  trackAsc,
  trackDesc,
  durationAsc,
  durationDesc,
  yearAsc,
  yearDesc,
  modifiedAsc,
  modifiedDesc,
  addedAsc,
  addedDesc,
  lastPlayedAsc,
  lastPlayedDesc,
  mostPlayed,
  leastPlayed,
}

const Map<SongSortOption, String> kSongSortLabels = {
  SongSortOption.titleAsc: 'Titelname - aufsteigend',
  SongSortOption.titleDesc: 'Titelname - absteigend',
  SongSortOption.filenameAsc: 'Dateiname - aufsteigend',
  SongSortOption.filenameDesc: 'Dateiname - absteigend',
  SongSortOption.filepathAsc: 'Dateiadresse - aufsteigend',
  SongSortOption.filepathDesc: 'Dateiadresse - absteigend',
  SongSortOption.folderNameAsc: 'Ordnername - aufsteigend',
  SongSortOption.folderNameDesc: 'Ordnername - absteigend',
  SongSortOption.folderPathAsc: 'Ordnerpfad - aufsteigend',
  SongSortOption.folderPathDesc: 'Ordnerpfad - absteigend',
  SongSortOption.albumAsc: 'Album - aufsteigend',
  SongSortOption.albumDesc: 'Album - absteigend',
  SongSortOption.artistAsc: 'Interpret - aufsteigend',
  SongSortOption.artistDesc: 'Interpret - absteigend',
  SongSortOption.albumArtistAsc: 'Album-Künstler - aufsteigend',
  SongSortOption.albumArtistDesc: 'Album-Künstler - absteigend',
  SongSortOption.composerAsc: 'Komponist - aufsteigend',
  SongSortOption.composerDesc: 'Komponist - absteigend',
  SongSortOption.genreAsc: 'Genre - aufsteigend',
  SongSortOption.genreDesc: 'Genre - absteigend',
  SongSortOption.trackAsc: 'Titelnummer - aufsteigend',
  SongSortOption.trackDesc: 'Titelnummer - absteigend',
  SongSortOption.durationAsc: 'Spieldauer - aufsteigend',
  SongSortOption.durationDesc: 'Spieldauer - absteigend',
  SongSortOption.yearAsc: 'Jahr - aufsteigend',
  SongSortOption.yearDesc: 'Jahr - absteigend',
  SongSortOption.modifiedAsc: 'Änderungsdatum - aufsteigend',
  SongSortOption.modifiedDesc: 'Änderungsdatum - absteigend',
  SongSortOption.addedAsc: 'Hinzufügedatum - aufsteigend',
  SongSortOption.addedDesc: 'Hinzufügedatum - absteigend',
  SongSortOption.lastPlayedAsc: 'Zuletzt gespielt - aufsteigend',
  SongSortOption.lastPlayedDesc: 'Zuletzt gespielt - absteigend',
  SongSortOption.mostPlayed: 'Am meisten gespielt',
  SongSortOption.leastPlayed: 'Am wenigsten gespielt',
};

const Set<SongSortOption> _descendingOptions = {
  SongSortOption.titleDesc,
  SongSortOption.filenameDesc,
  SongSortOption.filepathDesc,
  SongSortOption.folderNameDesc,
  SongSortOption.folderPathDesc,
  SongSortOption.albumDesc,
  SongSortOption.artistDesc,
  SongSortOption.albumArtistDesc,
  SongSortOption.composerDesc,
  SongSortOption.genreDesc,
  SongSortOption.trackDesc,
  SongSortOption.durationDesc,
  SongSortOption.yearDesc,
  SongSortOption.modifiedDesc,
  SongSortOption.addedDesc,
  SongSortOption.lastPlayedDesc,
  SongSortOption.mostPlayed,
};

String _folderPath(Song s) {
  if (s.path == null || s.path!.isEmpty) return '';
  return p.dirname(s.path!);
}

/// Sortier-Schlüssel je Option. Felder, die Musly aktuell nicht pro Song
/// erfasst (Album-Künstler, Komponist, Änderungsdatum), liefern einen
/// neutralen Wert - die Sortierung ist dafür ein stabiler No-op.
Comparable _sortKey(
  Song s,
  SongSortOption option,
  Map<String, SongProfile> profiles,
) {
  switch (option) {
    case SongSortOption.titleAsc:
    case SongSortOption.titleDesc:
      return s.title.toLowerCase();
    case SongSortOption.filenameAsc:
    case SongSortOption.filenameDesc:
      return (s.path != null && s.path!.isNotEmpty
              ? p.basename(s.path!)
              : s.title)
          .toLowerCase();
    case SongSortOption.filepathAsc:
    case SongSortOption.filepathDesc:
      return (s.path ?? '').toLowerCase();
    case SongSortOption.folderNameAsc:
    case SongSortOption.folderNameDesc:
      final folder = _folderPath(s);
      return folder.isEmpty ? '' : p.basename(folder).toLowerCase();
    case SongSortOption.folderPathAsc:
    case SongSortOption.folderPathDesc:
      return _folderPath(s).toLowerCase();
    case SongSortOption.albumAsc:
    case SongSortOption.albumDesc:
      return (s.album ?? '').toLowerCase();
    case SongSortOption.artistAsc:
    case SongSortOption.artistDesc:
      return (s.artist ?? '').toLowerCase();
    case SongSortOption.albumArtistAsc:
    case SongSortOption.albumArtistDesc:
    case SongSortOption.composerAsc:
    case SongSortOption.composerDesc:
      return '';
    case SongSortOption.genreAsc:
    case SongSortOption.genreDesc:
      return (s.genre ?? '').toLowerCase();
    case SongSortOption.trackAsc:
    case SongSortOption.trackDesc:
      return s.track ?? 0;
    case SongSortOption.durationAsc:
    case SongSortOption.durationDesc:
      return s.duration ?? 0;
    case SongSortOption.yearAsc:
    case SongSortOption.yearDesc:
      return s.year ?? 0;
    case SongSortOption.modifiedAsc:
    case SongSortOption.modifiedDesc:
      return 0;
    case SongSortOption.addedAsc:
    case SongSortOption.addedDesc:
      return s.created?.millisecondsSinceEpoch ?? 0;
    case SongSortOption.lastPlayedAsc:
    case SongSortOption.lastPlayedDesc:
      return profiles[s.id]?.lastPlayed.millisecondsSinceEpoch ?? 0;
    case SongSortOption.mostPlayed:
    case SongSortOption.leastPlayed:
      return profiles[s.id]?.playCount ?? 0;
  }
}

/// Liefert eine sortierte Kopie von [songs].
List<Song> sortSongs(
  List<Song> songs,
  SongSortOption option,
  Map<String, SongProfile> profiles,
) {
  final result = List<Song>.from(songs);
  final descending = _descendingOptions.contains(option);
  result.sort((a, b) {
    final cmp = Comparable.compare(
      _sortKey(a, option, profiles),
      _sortKey(b, option, profiles),
    );
    return descending ? -cmp : cmp;
  });
  return result;
}
