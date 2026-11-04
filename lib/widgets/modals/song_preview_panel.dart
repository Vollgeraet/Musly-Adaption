import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../models/song.dart';
import '../../providers/player_provider.dart';
import '../../services/subsonic_service.dart';
import '../../theme/app_theme.dart';
import '../common/floating_panel.dart';

/// Spielt einen Song kurz probehalber ab, in einem komplett eigenen,
/// vom Haupt-Player unabhängigen AudioPlayer:
/// - fügt NICHT zur Warteschlange hinzu
/// - wechselt NICHT in die Player-Ansicht
/// - ersetzt NICHT den aktuell laufenden Song
///
/// Läuft gerade ein Song, wird er beim Öffnen der Vorschau pausiert und
/// bleibt pausiert - auch wenn die Vorschau selbst pausiert wird - bis das
/// Fenster geschlossen ist (X, Zurück-Taste oder Ende der Vorschau). Erst
/// dann läuft der Song an der gleichen Stelle weiter.
class SongPreviewPanel extends StatefulWidget {
  final Song song;

  const SongPreviewPanel({super.key, required this.song});

  static Future<void> show(BuildContext context, Song song) {
    return showFloatingPanel(
      context,
      alignment: Alignment.center,
      builder: (ctx) => SongPreviewPanel(song: song),
    );
  }

  @override
  State<SongPreviewPanel> createState() => _SongPreviewPanelState();
}

class _SongPreviewPanelState extends State<SongPreviewPanel> {
  // Eigener Player ohne Audiofokus-/Sitzungsverwaltung: Der Haupt-Player
  // läuft genauso und die Sitzung wird unten einmal manuell aktiviert.
  // So löst die Vorschau (Play/Pause) keine Audiofokus-Ereignisse aus, die
  // den Hauptsong versehentlich fortsetzen würden.
  final AudioPlayer _previewPlayer = AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: false,
  );
  late final PlayerProvider _player =
      Provider.of<PlayerProvider>(context, listen: false);

  StreamSubscription<PlayerState>? _stateSub;
  bool _holdReady = false;
  bool _wasMainPlaying = false;
  bool _released = false;
  bool _closing = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _wasMainPlaying = await _player.beginPreviewHold();
    _holdReady = true;

    // Wurde das Fenster schon geschlossen, bevor der Haltemodus stand:
    // sofort wieder freigeben.
    if (_released) {
      await _player.endPreviewHold(resume: _wasMainPlaying);
      return;
    }

    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}

    try {
      final source = await _player.buildAudioSourceForSong(widget.song);
      await _previewPlayer.setAudioSource(source);
      if (!mounted || _released) return;
      setState(() => _isLoading = false);

      // Listener VOR dem Start registrieren; play() liefert sein Future
      // erst, wenn die Wiedergabe endet, darf also nicht abgewartet werden.
      _stateSub = _previewPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _close();
        }
      });
      unawaited(_previewPlayer.play());
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Schließt das Fenster sofort und räumt danach im Hintergrund auf.
  void _close() {
    if (_closing) return;
    _closing = true;
    final navigator = Navigator.of(context);
    navigator.pop();
    _release();
  }

  /// Stoppt die Vorschau und gibt die Hauptwiedergabe wieder frei
  /// (genau einmal, egal auf welchem Weg das Fenster verschwindet).
  void _release() {
    if (_released) return;
    _released = true;
    _stateSub?.cancel();
    unawaited(_previewPlayer.stop());
    if (_holdReady) {
      unawaited(_player.endPreviewHold(resume: _wasMainPlaying));
    }
  }

  @override
  void dispose() {
    _release();
    _previewPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _togglePlay(bool playing) {
    if (playing) {
      _previewPlayer.pause();
    } else {
      unawaited(_previewPlayer.play());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subsonic = Provider.of<SubsonicService>(context, listen: false);
    final coverUrl = widget.song.coverArt != null
        ? subsonic.getCoverArtUrl(widget.song.coverArt, size: 120)
        : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevated : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  StreamBuilder<PlayerState>(
                    stream: _previewPlayer.playerStateStream,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return IconButton(
                        icon: Icon(
                          playing
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_fill_rounded,
                          size: 28,
                        ),
                        onPressed:
                            _isLoading ? null : () => _togglePlay(playing),
                      );
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Vorschau',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _close,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: coverUrl != null
                        ? Image.network(coverUrl,
                            width: 48, height: 48, fit: BoxFit.cover)
                        : Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.song.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (widget.song.artist != null)
                          Text(widget.song.artist!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white60)),
                        if (widget.song.album != null)
                          Text(widget.song.album!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.white60)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<Duration?>(
                stream: _previewPlayer.durationStream,
                builder: (context, durationSnap) {
                  final duration = durationSnap.data ?? Duration.zero;
                  return StreamBuilder<Duration>(
                    stream: _previewPlayer.positionStream,
                    builder: (context, posSnap) {
                      final position = posSnap.data ?? Duration.zero;
                      final maxMs = duration.inMilliseconds == 0
                          ? 1
                          : duration.inMilliseconds;
                      return Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${_formatDuration(position)}/${_formatDuration(duration)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white60),
                            ),
                          ),
                          Row(
                            children: [
                              StreamBuilder<PlayerState>(
                                stream: _previewPlayer.playerStateStream,
                                builder: (context, snapshot) {
                                  final playing =
                                      snapshot.data?.playing ?? false;
                                  return IconButton(
                                    icon: Icon(playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded),
                                    onPressed: _isLoading
                                        ? null
                                        : () => _togglePlay(playing),
                                  );
                                },
                              ),
                              Expanded(
                                child: Slider(
                                  value: position.inMilliseconds
                                      .clamp(0, maxMs)
                                      .toDouble(),
                                  max: maxMs.toDouble(),
                                  onChanged: _isLoading
                                      ? null
                                      : (val) => _previewPlayer.seek(
                                          Duration(milliseconds: val.round())),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
