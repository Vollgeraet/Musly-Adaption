import 'package:flutter/material.dart';
import '../../services/player_ui_settings_service.dart';
import '../../theme/app_theme.dart';

/// Einstellungen für die "Alle Titel"-Ansicht. Aktuell genau ein
/// Punkt: Ob die Such-Zeile direkt über der Navigationsleiste
/// angezeigt wird.
class AllSongsSettingsScreen extends StatelessWidget {
  const AllSongsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = PlayerUiSettingsService();

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ValueListenableBuilder<bool>(
        valueListenable: settings.showListSearchBarNotifier,
        builder: (context, showSearchBar, _) {
          return SwitchListTile(
            title: const Text('Suchleiste anzeigen'),
            subtitle: const Text(
              'Zeigt die Suchleiste direkt über der Navigationsleiste an.',
            ),
            value: showSearchBar,
            onChanged: (value) => settings.setShowListSearchBar(value),
          );
        },
      ),
    );
  }
}
