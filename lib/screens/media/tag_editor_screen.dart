import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../services/subsonic_service.dart';
import '../../theme/app_theme.dart';

/// Vollbild-Tag-Editor (Musicolet-Vorbild). Die Oberfläche ist komplett
/// nutzbar, aber ehrlich begrenzt beim Speichern:
/// - Navidrome/Subsonic unterstützt das Schreiben von Metadaten über die
///   Standard-API nicht - für Server-Songs wird nichts gespeichert.
/// - Für lokale Dateien fehlt aktuell noch ein Tag-Schreib-Paket
///   (z. B. audiotags) in pubspec.yaml; auch hier wird noch nichts
///   dauerhaft gespeichert, um keine falschen Erfolgsmeldungen zu zeigen.
class TagEditorScreen extends StatefulWidget {
  final Song song;

  const TagEditorScreen({super.key, required this.song});

  @override
  State<TagEditorScreen> createState() => _TagEditorScreenState();
}

class _TagEditorScreenState extends State<TagEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _album;
  late final TextEditingController _artist;
  late final TextEditingController _albumArtist;
  late final TextEditingController _composer;
  late final TextEditingController _genre;
  late final TextEditingController _lyricist;
  late final TextEditingController _track;
  late final TextEditingController _discNumber;
  late final TextEditingController _year;
  late final TextEditingController _comment;

  @override
  void initState() {
    super.initState();
    final s = widget.song;
    _title = TextEditingController(text: s.title);
    _album = TextEditingController(text: s.album ?? '');
    _artist = TextEditingController(text: s.artist ?? '');
    _albumArtist = TextEditingController();
    _composer = TextEditingController();
    _genre = TextEditingController(text: s.genre ?? '');
    _lyricist = TextEditingController();
    _track = TextEditingController(text: (s.track ?? 0).toString());
    _discNumber = TextEditingController();
    _year = TextEditingController(text: s.year?.toString() ?? '');
    _comment = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _album,
      _artist,
      _albumArtist,
      _composer,
      _genre,
      _lyricist,
      _track,
      _discNumber,
      _year,
      _comment,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final isLocal = widget.song.isLocal;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nicht gespeichert'),
        content: Text(
          isLocal
              ? 'Für lokale Dateien fehlt noch ein Paket zum Schreiben von '
                  'Tags (z. B. audiotags) in diesem Projekt. Die Oberfläche '
                  'ist fertig, aber ohne dieses Paket kann ich die Datei '
                  'nicht wirklich verändern.'
              : 'Dieser Song liegt auf deinem Navidrome-Server. Navidrome '
                  'unterstützt das Bearbeiten von Metadaten über die '
                  'normale Subsonic-API nicht, daher kann Musly hier keine '
                  'Änderungen speichern.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: label,
          border: const UnderlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subsonic = Provider.of<SubsonicService>(context, listen: false);
    final coverUrl = widget.song.coverArt != null
        ? subsonic.getCoverArtUrl(widget.song.coverArt, size: 300)
        : null;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        title: const Text('Tag-Editor'),
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: coverUrl != null
                      ? Image.network(coverUrl,
                          width: 180, height: 180, fit: BoxFit.cover)
                      : Container(
                          width: 180,
                          height: 180,
                          color: Colors.grey.withValues(alpha: 0.3),
                        ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                        onPressed: null,
                        tooltip: 'Noch nicht verfügbar',
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                        onPressed: null,
                        tooltip: 'Noch nicht verfügbar',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: null,
              child: Text(
                'EINGEBETTETEN SONGTEXT BEARBEITEN',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _field('Titel', _title),
          _field('Album', _album),
          _field('Interpret', _artist),
          _field('Album-Künstler', _albumArtist),
          _field('Komponist', _composer),
          _field('Genre', _genre),
          _field('Songtexter', _lyricist),
          _field('Titel-Nummer', _track),
          _field('CD-Nummer', _discNumber),
          _field('Jahr', _year),
          _field('Kommentar', _comment),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
