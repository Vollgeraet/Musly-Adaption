import 'package:flutter/material.dart' hide RepeatMode;
import '../../providers/player_provider.dart';
import '../../theme/app_theme.dart';
import '../common/floating_panel.dart';

/// Das Wiederholungs-Menü aus der Now-Playing-Ansicht (links vom
/// Zufallswiedergabe-Umschalter). "Einfach" bildet 1:1 unseren
/// bestehenden RepeatMode ab (off/all/one) und ist voll funktional.
/// "Erweitert" zeigt Musicolets granularere Aufteilung; die Punkte,
/// die über unser einfaches RepeatMode-Modell hinausgehen, sind
/// ausgegraut (siehe Kommentare unten).
class RepeatModeMenu extends StatefulWidget {
  final PlayerProvider player;

  const RepeatModeMenu({super.key, required this.player});

  static Future<void> show(BuildContext context, PlayerProvider player) {
    return showFloatingPanel(
      context,
      alignment: Alignment.center,
      builder: (ctx) => RepeatModeMenu(player: player),
    );
  }

  @override
  State<RepeatModeMenu> createState() => _RepeatModeMenuState();
}

enum _Tab { einfach, erweitert }

class _RepeatModeMenuState extends State<RepeatModeMenu> {
  _Tab _tab = _Tab.einfach;
  // Rein visueller Platzhalter für "Warteschlange neu mischen" -
  // ist (noch) nicht mit echtem Engine-Verhalten verknüpft.
  bool _reshuffleOnLoop = true;

  Color _red(BuildContext context) => Theme.of(context).colorScheme.primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: _tab == _Tab.einfach
                    ? _buildEinfach(context)
                    : _buildErweitert(context, dividerColor),
              ),
            ),
          ),
          Divider(height: 1, color: dividerColor),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                _TabChip(
                  label: 'Einfach',
                  active: _tab == _Tab.einfach,
                  onTap: () => setState(() => _tab = _Tab.einfach),
                ),
                const SizedBox(width: 8),
                _TabChip(
                  label: 'Erweitert',
                  active: _tab == _Tab.erweitert,
                  onTap: () => setState(() => _tab = _Tab.erweitert),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Zurücksetzen',
                  icon: const Icon(Icons.restore_rounded),
                  onPressed: () {
                    widget.player.setRepeatMode(RepeatMode.off);
                    setState(() => _reshuffleOnLoop = true);
                  },
                ),
                IconButton(
                  tooltip: 'Fertig',
                  icon: Icon(Icons.check_rounded, color: _red(context)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEinfach(BuildContext context) {
    final mode = widget.player.repeatMode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RadioListTile<RepeatMode>(
          value: RepeatMode.off,
          groupValue: mode,
          activeColor: _red(context),
          secondary: const Icon(Icons.trending_flat_rounded),
          title: const Text('Nächsten Titel spielen'),
          onChanged: (v) => setState(() => widget.player.setRepeatMode(v!)),
        ),
        RadioListTile<RepeatMode>(
          value: RepeatMode.all,
          groupValue: mode,
          activeColor: _red(context),
          secondary: const Icon(Icons.repeat_rounded),
          title: const Text('Warteschlange wiederholen'),
          onChanged: (v) => setState(() => widget.player.setRepeatMode(v!)),
        ),
        RadioListTile<RepeatMode>(
          value: RepeatMode.one,
          groupValue: mode,
          activeColor: _red(context),
          secondary: const Icon(Icons.repeat_one_rounded),
          title: const Text('Titel wiederholen'),
          onChanged: (v) => setState(() => widget.player.setRepeatMode(v!)),
        ),
      ],
    );
  }

  Widget _buildErweitert(BuildContext context, Color dividerColor) {
    final mode = widget.player.repeatMode;
    // "Wenn ein Titel endet": off->Nächsten Titel spielen, one->Titel
    // wiederholen. "all" gehört konzeptionell zur Warteschlangen-Gruppe
    // unten, daher hier keine Auswahl.
    final songEndValue =
        mode == RepeatMode.off ? 'next' : (mode == RepeatMode.one ? 'repeatSong' : null);
    final queueEndValue = mode == RepeatMode.all ? 'repeatQueue' : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('Wenn ein Titel endet...',
              style: TextStyle(color: _red(context), fontWeight: FontWeight.bold)),
        ),
        RadioListTile<String>(
          value: 'stop',
          groupValue: songEndValue,
          activeColor: _red(context),
          dense: true,
          title: const Text('Wiedergabe beenden'),
          onChanged: null,
        ),
        RadioListTile<String>(
          value: 'loadPause',
          groupValue: songEndValue,
          activeColor: _red(context),
          dense: true,
          title: const Text('Laden Sie das nächste Lied und Pause'),
          onChanged: null,
        ),
        RadioListTile<String>(
          value: 'next',
          groupValue: songEndValue,
          activeColor: _red(context),
          dense: true,
          title: const Text('Nächsten Titel spielen'),
          onChanged: (_) =>
              setState(() => widget.player.setRepeatMode(RepeatMode.off)),
        ),
        RadioListTile<String>(
          value: 'repeatSong',
          groupValue: songEndValue,
          activeColor: _red(context),
          dense: true,
          title: const Text('Titel wiederholen'),
          onChanged: (_) =>
              setState(() => widget.player.setRepeatMode(RepeatMode.one)),
        ),
        Divider(height: 17, indent: 16, endIndent: 16, color: dividerColor),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('Wenn die aktuelle Warteschlange endet...',
              style: TextStyle(color: _red(context), fontWeight: FontWeight.bold)),
        ),
        CheckboxListTile(
          value: _reshuffleOnLoop,
          activeColor: _red(context),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
              'Die Warteschlange neu mischen (wenn Zufallswiedergabe aktiviert ist)'),
          // Noch nicht mit echtem Engine-Verhalten verknüpft.
          onChanged: null,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text('Und dann...'),
        ),
        RadioListTile<String>(
          value: 'stopQueue',
          groupValue: queueEndValue,
          activeColor: _red(context),
          dense: true,
          title: const Text('Wiedergabe beenden'),
          onChanged: null,
        ),
        RadioListTile<String>(
          value: 'nextQueue',
          groupValue: queueEndValue,
          activeColor: _red(context),
          dense: true,
          title: const Text('Die nächste Warteschlange abspielen'),
          onChanged: null,
        ),
        RadioListTile<String>(
          value: 'repeatQueue',
          groupValue: queueEndValue,
          activeColor: _red(context),
          dense: true,
          title: const Text('Warteschlange wiederholen'),
          onChanged: (_) =>
              setState(() => widget.player.setRepeatMode(RepeatMode.all)),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: active ? color : Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(color: active ? color : null, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
