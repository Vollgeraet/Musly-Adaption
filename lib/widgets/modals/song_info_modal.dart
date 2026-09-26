import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../../models/song.dart';
import '../../services/recommendation_service.dart';
import '../../theme/app_theme.dart';

/// Zeigt die Metadaten eines Songs an ("Titel-Infos" im Song-Optionsmenü).
///
/// Felder, die Musly aktuell nicht für einen Song erfasst (z. B.
/// Album-Künstler, Komponist, Samplingrate, Bits pro Sample, Kodierung,
/// Kanäle, "Zuletzt geändert") werden ehrlich als "[unbekannt]"
/// dargestellt, statt erfundene Werte anzuzeigen.
class SongInfoModal extends StatelessWidget {
  static const String _unknown = '[unbekannt]';

  static Future<void> show(BuildContext context, Song song) {
    // Öffnet sich sofort ohne Slide-Up-Animation (wie gewünscht),
    // behält aber das Bottom-Sheet-artige Layout per DraggableScrollableSheet.
    return showGeneralDialog(
      context: context,
      barrierLabel: 'Titel-Infos',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, anim1, anim2) => SongInfoModal(song: song),
    );
  }

  final Song song;

  const SongInfoModal({super.key, required this.song});

  String _formatSize(int? bytes) {
    if (bytes == null) return _unknown;
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  String _formatDate(DateTime? d) {
    if (d == null) return _unknown;
    const months = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day}. ${months[d.month - 1]} ${d.year} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final recommendation =
        Provider.of<RecommendationService>(context, listen: false);
    final profile = recommendation.profiles[song.id];

    final fileName = song.path != null && song.path!.isNotEmpty
        ? p.basename(song.path!)
        : '${song.title}.${song.suffix ?? "mp3"}';
    final pathDisplay = song.isLocal
        ? (song.path != null && song.path!.isNotEmpty ? song.path! : _unknown)
        : 'Navidrome-Stream';

    final rows = <_InfoRowData?>[
      _InfoRowData('Dateiname', fileName),
      _InfoRowData('Pfad', pathDisplay, editable: true),
      _InfoRowData('Titel', song.title),
      _InfoRowData('Album', song.album ?? _unknown, editable: true),
      _InfoRowData('Interpret', song.artist ?? _unknown),
      const _InfoRowData('Album-Künstler', _unknown, editable: true),
      const _InfoRowData('Komponist', _unknown, editable: true),
      _InfoRowData('Genre', song.genre ?? _unknown, editable: true),
      const _InfoRowData('Songtexter', _unknown),
      _InfoRowData('Titel-Nummer', song.track?.toString() ?? '0'),
      const _InfoRowData('CD-Nummer', _unknown),
      _InfoRowData('Jahr', song.year?.toString() ?? _unknown),
      const _InfoRowData('Kommentar', _unknown),
      null,
      _InfoRowData('Spieldauer', song.formattedDuration),
      _InfoRowData(
          'Bitrate', song.bitRate != null ? '~${song.bitRate} kbps' : _unknown),
      const _InfoRowData('Samplingrate', _unknown),
      const _InfoRowData('Bits pro Sample', _unknown),
      _InfoRowData(
          'Format', (song.suffix ?? song.contentType ?? _unknown).toUpperCase()),
      const _InfoRowData('Kodierung', _unknown),
      const _InfoRowData('Kanäle', _unknown),
      _InfoRowData('Größe', _formatSize(song.size)),
      null,
      _InfoRowData('Hinzugefügt-Datum', _formatDate(song.created)),
      const _InfoRowData('Zuletzt geändert', _unknown),
      _InfoRowData(
        'Zuletzt gespielt',
        profile != null ? _formatDate(profile.lastPlayed) : 'Noch nie',
      ),
      _InfoRowData(
        'Gespielt',
        (profile?.playCount ?? 0) > 0
            ? '${profile!.playCount}-mal vorher'
            : 'Noch nie gespielt',
      ),
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.info),
                    const SizedBox(width: 8),
                    Text(
                      'Titel-Infos',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    if (row == null) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      );
                    }
                    return _InfoRow(data: row);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _InfoRowData {
  final String label;
  final String value;
  final bool editable;
  const _InfoRowData(this.label, this.value, {this.editable = false});
}

class _InfoRow extends StatelessWidget {
  final _InfoRowData data;
  const _InfoRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              if (data.editable) ...[
                const SizedBox(width: 6),
                // Rein visueller Hinweis, dass dieses Feld über "Tags
                // bearbeiten" editierbar wäre, sobald diese Funktion
                // verfügbar ist (siehe Song-Optionsmenü).
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 9, color: Colors.white),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(data.value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
