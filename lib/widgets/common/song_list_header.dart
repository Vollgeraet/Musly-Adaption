import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../screens/media/all_songs_settings_screen.dart';
import '../../services/player_ui_settings_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/song_sorting.dart';
import 'floating_panel.dart';

/// Gemeinsame Kopfzeile für alle Titellisten ("Alle Titel", Wiedergabe-
/// listen, ...): Titel links + Einstellungen-Zahnrad (schaltet die
/// Suchleiste), darunter Titelanzahl + Gesamtdauer, Trennstrich, darunter
/// rechtsbündig Zufall / Sortieren / Mehr.
class SongListHeader extends StatelessWidget {
  final String title;
  final int songCount;
  final Duration totalDuration;
  final VoidCallback onRandom;
  final VoidCallback onSort;
  final VoidCallback onMore;

  /// Optionale zusätzliche Icons links neben "Zufall" (z. B. Download).
  final List<Widget> extraActions;

  /// Wenn gesetzt, ersetzt diese Leiste die Aktions-Icons (z. B. im
  /// Auswahlmodus einer Playlist).
  final Widget? replacementActionBar;

  const SongListHeader({
    super.key,
    required this.title,
    required this.songCount,
    required this.totalDuration,
    required this.onRandom,
    required this.onSort,
    required this.onMore,
    this.extraActions = const [],
    this.replacementActionBar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => const AllSongsSettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '${AppLocalizations.of(context)!.songsCount(songCount)} • ${FormatUtils.formatDurationSummary(totalDuration)}',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkSecondaryText
                    : AppTheme.lightSecondaryText,
              ),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            ),
            const SizedBox(height: 4),
            replacementActionBar ??
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ...extraActions,
                    IconButton(
                      icon: const Icon(Icons.shuffle_rounded),
                      tooltip: 'Zufälligen Titel abspielen',
                      onPressed: onRandom,
                    ),
                    IconButton(
                      icon: const Icon(Icons.sort_rounded),
                      tooltip: 'Sortieren',
                      onPressed: onSort,
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      tooltip: 'Mehr',
                      onPressed: onMore,
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

/// Such-Zeile direkt über der Navigationsleiste. Ein-/ausblendbar über
/// die Einstellung (Zahnrad in [SongListHeader]).
class SongListSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// Standardmäßig false: Jeder Screen, der diese Suchleiste verwendet
  /// (Tabs wie auch per NavigationHelper.push/pushInstant gepushte
  /// Screens wie Playlists/Favoriten), läuft über denselben
  /// "mobileNavigatorKey"-Navigator, der innerhalb von MainScreens
  /// Spalte OBERHALB der immer sichtbaren Navigationsleiste sitzt - nie
  /// am echten unteren Bildschirmrand. Eine eigene SafeArea hier würde
  /// daher nur einen zusätzlichen Leerraum in Höhe der Suchleiste
  /// selbst erzeugen. Nur auf true setzen, wenn ein Screen nachweislich
  /// über einen anderen, echten Vollbild-Navigator angezeigt wird.
  final bool applySafeArea;

  const SongListSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.applySafeArea = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<bool>(
      valueListenable: PlayerUiSettingsService().showListSearchBarNotifier,
      builder: (context, showSearchBar, _) {
        if (!showSearchBar) return const SizedBox.shrink();
        final field = Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'In dieser Liste suchen...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? AppTheme.darkSurface
                    : Colors.grey.withValues(alpha: 0.1),
              ),
            ),
          );
        return applySafeArea ? SafeArea(top: false, child: field) : field;
      },
    );
  }
}

/// Sortier-Panel mit allen Optionen. Auswahl wird sofort übernommen und
/// das Panel geschlossen.
Future<void> showSongSortPanel(
  BuildContext context, {
  required SongSortOption? current,
  required ValueChanged<SongSortOption> onSelected,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showFloatingPanel(
    context,
    builder: (panelContext) {
      final primary = Theme.of(panelContext).colorScheme.primary;
      return Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkElevated : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Titel sortieren nach...',
                      style: Theme.of(panelContext).textTheme.titleMedium),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: kSongSortLabels.entries.map((entry) {
                  final selected = current == entry.key;
                  return RadioListTile<SongSortOption>(
                    value: entry.key,
                    groupValue: current,
                    dense: true,
                    activeColor: primary,
                    title: Text(
                      entry.value,
                      style: TextStyle(color: selected ? primary : null),
                    ),
                    onChanged: (opt) {
                      if (opt == null) return;
                      onSelected(opt);
                      Navigator.pop(panelContext);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Menüeintrag für die "..."-Menüs; ausgegraut, wenn [enabled] false ist.
class ListMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool enabled;

  const ListMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: ListTile(
        leading: Icon(
          icon,
          color: enabled ? theme.colorScheme.primary : theme.disabledColor,
        ),
        title: Text(
          title,
          style: TextStyle(color: enabled ? null : theme.disabledColor),
        ),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
