import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:volume_controller/volume_controller.dart';
import '../../providers/player_provider.dart';

/// Kompakte Lautstärkeanzeige, die kurzzeitig anstelle der
/// Fortschrittsleiste eingeblendet wird, wenn das Lautstärke-Icon in
/// den Wiedergabe-Steuerelementen angetippt wird (Musicolet-Vorbild).
///
/// Hinweis: Android liefert die Systemlautstärke normiert (0.0-1.0);
/// die angezeigte Stufenzahl ist eine Annäherung auf einer üblichen
/// 15-stufigen Skala, da die exakte Stufenzahl des Geräts ohne
/// zusätzlichen nativen Code nicht auslesbar ist.
class VolumeQuickPopup extends StatefulWidget {
  const VolumeQuickPopup({super.key});

  @override
  State<VolumeQuickPopup> createState() => _VolumeQuickPopupState();
}

class _VolumeQuickPopupState extends State<VolumeQuickPopup> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  double _systemVolume = 0.0;

  static const int _steps = 15;

  @override
  void initState() {
    super.initState();
    VolumeController.instance.showSystemUI = false;
    VolumeController.instance.getVolume().then((volume) {
      if (mounted) setState(() => _systemVolume = volume);
    });
    VolumeController.instance.addListener((volume) {
      if (mounted && !_isDragging) {
        setState(() => _systemVolume = volume);
      }
    });
  }

  @override
  void dispose() {
    VolumeController.instance.removeListener();
    super.dispose();
  }

  void _onVolumeChanged(double val, PlayerProvider player) {
    if (player.isRemotePlayback) {
      player.setVolume(val);
    } else {
      VolumeController.instance.setVolume(val);
      player.setVolume(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isRemote = player.isRemotePlayback;
    final baseVolume = isRemote ? player.volume : _systemVolume;
    final currentVolume = _isDragging ? _dragValue : baseVolume;
    final stepLabel = (currentVolume.clamp(0.0, 1.0) * _steps).round().toString();
    final duration = player.duration;
    final durationLabel = duration == Duration.zero
        ? '--:--'
        : '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_down_rounded, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 16,
            child: Text(
              stepLabel,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) {
                setState(() {
                  _isDragging = true;
                  _dragValue = baseVolume;
                });
              },
              onHorizontalDragUpdate: (details) {
                final box = context.findRenderObject() as RenderBox;
                final dx = details.localPosition.dx.clamp(0.0, box.size.width);
                final val = (dx / box.size.width).clamp(0.0, 1.0);
                setState(() => _dragValue = val);
                _onVolumeChanged(val, player);
              },
              onHorizontalDragEnd: (details) => setState(() => _isDragging = false),
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox;
                final dx = details.localPosition.dx.clamp(0.0, box.size.width);
                final val = (dx / box.size.width).clamp(0.0, 1.0);
                setState(() => _dragValue = val);
                _onVolumeChanged(val, player);
              },
              child: SizedBox(
                height: 20,
                child: CustomPaint(
                  size: const Size(double.infinity, 20),
                  painter: _RedDotSliderPainter(volume: currentVolume),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            durationLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RedDotSliderPainter extends CustomPainter {
  final double volume;
  _RedDotSliderPainter({required this.volume});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = Colors.white24;
    final activePaint = Paint()..color = Colors.white70;
    final dotPaint = Paint()..color = Colors.redAccent;

    final y = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, y - 2, size.width, 4), const Radius.circular(2)),
      trackPaint,
    );
    final activeWidth = size.width * volume.clamp(0.0, 1.0);
    if (activeWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, y - 2, activeWidth, 4), const Radius.circular(2)),
        activePaint,
      );
    }
    canvas.drawCircle(Offset(activeWidth, y), 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RedDotSliderPainter oldDelegate) =>
      oldDelegate.volume != volume;
}
