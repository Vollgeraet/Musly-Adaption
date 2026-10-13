import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/auth_provider.dart';
import '../../providers/library_provider.dart';
import '../../services/subsonic_service.dart';
import '../../theme/app_theme.dart';

/// Vollbild-Tag-Editor (Musicolet-Vorbild).
///
/// Server-Songs (Navidrome): Navidrome selbst kann keine Tags schreiben.
/// Gespeichert wird deshalb über den eigenen Tag-Editor-Dienst auf dem
/// Server (api_server.py): Musly schickt nur die geänderten Felder als
/// JSON, der Dienst ändert die Datei direkt auf dem Server - die
/// Audiodatei wird nie übertragen.
///
/// Lokale Dateien: Hierfür fehlt noch ein Tag-Schreib-Paket in
/// pubspec.yaml, daher wird dort ehrlich nichts gespeichert.
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

  /// Ausgangswerte beim Öffnen, je Schlüssel des Tag-Dienstes. Nur Felder,
  /// die sich dagegen geändert haben, werden gesendet - sonst würden leere
  /// Felder (z. B. Album-Künstler, die Musly nicht kennt) vorhandene Tags
  /// in der Datei löschen.
  late final Map<String, String> _initial;

  bool _saving = false;

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
    _initial = _currentValues();
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

  Map<String, String> _currentValues() => {
        'title': _title.text.trim(),
        'album': _album.text.trim(),
        'artist': _artist.text.trim(),
        'albumartist': _albumArtist.text.trim(),
        'composer': _composer.text.trim(),
        'genre': _genre.text.trim(),
        'tracknumber': _track.text.trim(),
        'discnumber': _discNumber.text.trim(),
        'date': _year.text.trim(),
      };

  Map<String, String> _changedTags() {
    final current = _currentValues();
    final changed = <String, String>{};
    current.forEach((key, value) {
      if (value != (_initial[key] ?? '')) changed[key] = value;
    });
    return changed;
  }

  Future<void> _showInfo(String title, String message) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  /// Fragt URL und API-Key des Tag-Editor-Dienstes ab und speichert sie
  /// für den aktuellen Server. Gibt true zurück, wenn gespeichert wurde.
  Future<bool> _askForTagEditorSettings() async {
    final urlController = TextEditingController(text: 'https://');
    final keyController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tag-Editor einrichten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Für diesen Server ist noch kein Tag-Editor-Dienst hinterlegt.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Tag-Editor-URL',
                hintText: 'https://tag-api.internal',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'API-Key'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    final url = urlController.text.trim();
    final key = keyController.text.trim();
    urlController.dispose();
    keyController.dispose();

    if (saved != true || url.length <= 8 || key.isEmpty) return false;
    if (!mounted) return false;

    await Provider.of<AuthProvider>(context, listen: false)
        .updateTagEditorSettings(url: url, apiKey: key);
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    final song = widget.song;

    if (song.isLocal) {
      await _showInfo(
        'Nicht gespeichert',
        'Für lokale Dateien fehlt noch ein Paket zum Schreiben von Tags '
            '(z. B. audiotags) in diesem Projekt. Ohne dieses Paket kann '
            'Musly die Datei nicht verändern.',
      );
      return;
    }

    final changed = _changedTags();
    if (changed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Änderungen vorgenommen.')),
      );
      return;
    }

    final subsonic = Provider.of<SubsonicService>(context, listen: false);
    if (subsonic.config?.hasTagEditor != true) {
      final configured = await _askForTagEditorSettings();
      if (!configured || !mounted) return;
    }

    // Pfad frisch vom Server holen statt aus dem Cache: so greift eine
    // Änderung der Navidrome-Einstellung "Report Real Path" sofort.
    String? path = song.path;
    try {
      final fresh = await subsonic.fetchSongPath(song.id);
      if (fresh != null && fresh.isNotEmpty) path = fresh;
    } catch (_) {}
    if (!mounted) return;
    if (path == null || path.isEmpty) {
      await _showInfo(
        'Dateipfad unbekannt',
        'Der Server hat für diesen Song keinen Dateipfad geliefert, daher '
            'weiß der Tag-Editor nicht, welche Datei er ändern soll.',
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final library = Provider.of<LibraryProvider>(context, listen: false);

    setState(() => _saving = true);
    try {
      await subsonic.editTags(relativePath: path, tags: changed);

      // Best effort: Navidrome die Änderung zeitnah einlesen lassen
      // (braucht Admin-Rechte; sonst greift der geplante Scan).
      try {
        await subsonic.startScan();
      } catch (_) {}
      Future.delayed(const Duration(seconds: 4), () {
        library.refresh();
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Tags gespeichert. Navidrome liest die Änderung beim nächsten '
            'Scan ein.',
          ),
        ),
      );
      navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        await _showInfo(
          'Speichern fehlgeschlagen',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Widget _field(String label, TextEditingController controller,
      {String? helper}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: label,
          helperText: helper,
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
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.check,
                  color: Theme.of(context).colorScheme.primary),
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
                        icon: const Icon(Icons.edit,
                            color: Colors.white, size: 18),
                        onPressed: null,
                        tooltip: 'Noch nicht verfügbar',
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.white, size: 18),
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
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.5),
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
          _field('Songtexter', _lyricist,
              helper: 'Wird vom Tag-Dienst noch nicht gespeichert'),
          _field('Titel-Nummer', _track),
          _field('CD-Nummer', _discNumber),
          _field('Jahr', _year),
          _field('Kommentar', _comment,
              helper: 'Wird vom Tag-Dienst noch nicht gespeichert'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
