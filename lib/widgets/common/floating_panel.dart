import 'package:flutter/material.dart';

/// Zeigt ein "schwebendes Panel": erscheint sofort ohne Slide-/Fade-
/// Animation, hat auf allen vier Seiten etwas Rand zum Bildschirmrand
/// (Hintergrund bleibt sichtbar), lässt sich NICHT durch Wischen oder
/// Antippen des Hintergrunds schließen - nur über die System-Zurück-
/// Geste/-Taste (die jede Route unabhängig von barrierDismissible
/// schließt) oder einen expliziten Schließen-Button im Inhalt selbst.
///
/// Wird für alle "Einstellungen"-artigen Overlays verwendet (Titel-
/// Infos, Song-Optionsmenü, Now-Playing "..."-Menü, Sortieren, usw.) -
/// mit Ausnahme reiner Einstellungs-Screens wie den Alle-Titel-
/// Sucheinstellungen, die als normaler Vollbild-Screen bleiben.
Future<T?> showFloatingPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxHeightFraction = 0.82,
  bool useRootNavigator = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierLabel: 'Panel',
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: Duration.zero,
    pageBuilder: (dialogContext, anim1, anim2) {
      final screenSize = MediaQuery.of(dialogContext).size;
      return Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * maxHeightFraction,
              maxWidth: screenSize.width - 32,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: Colors.transparent,
                child: builder(dialogContext),
              ),
            ),
          ),
        ),
      );
    },
  );
}
