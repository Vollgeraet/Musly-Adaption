import 'package:flutter/material.dart';

/// Seitenabstand links/rechts in Bruchteilen der Bildschirmbreite
/// (0.075 => Panel ist 85 % so breit wie der Bildschirm). Zentral
/// einstellbar, falls die Panels breiter/schmaler wirken sollen.
const double kFloatingPanelSideMargin = 0.075;

/// Oberer und unterer Abstand in Bruchteilen der Bildschirmhöhe. Der
/// untere Abstand ist so gewählt, dass die Navigationsleiste ungefähr zur
/// Hälfte unter dem Panel sichtbar bleibt.
const double kFloatingPanelTopMargin = 0.09;
const double kFloatingPanelBottomMargin = 0.045;

/// Zeigt ein "schwebendes Panel": erscheint sofort ohne Slide-/Fade-
/// Animation, hat auf allen vier Seiten Rand zum Bildschirmrand
/// (Hintergrund und Navigationsleiste bleiben teilweise sichtbar), lässt
/// sich NICHT durch Wischen oder Antippen des Hintergrunds schließen -
/// nur über die System-Zurück-Geste/-Taste oder einen expliziten
/// Schließen-Button im Inhalt selbst.
///
/// [alignment] bestimmt die vertikale Position: unten (Standard) oder
/// z. B. [Alignment.center] für kleine Auswahl-Dialoge.
Future<T?> showFloatingPanel<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Alignment alignment = Alignment.bottomCenter,
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
      final size = MediaQuery.of(dialogContext).size;
      final sideMargin = size.width * kFloatingPanelSideMargin;
      final topMargin = size.height * kFloatingPanelTopMargin;
      final bottomMargin = size.height * kFloatingPanelBottomMargin;
      return Align(
        alignment: alignment,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              sideMargin, topMargin, sideMargin, bottomMargin),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: size.height - topMargin - bottomMargin,
              maxWidth: size.width - 2 * sideMargin,
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
