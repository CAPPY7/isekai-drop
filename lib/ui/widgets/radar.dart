import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 0.11.0: pulsing radar shown while looking for devices. Static icon when
/// the system asks for less motion (MediaQuery.disableAnimations, e.g.
/// Android "Remove animations", iOS "Reduce Motion").
class SearchingRadar extends StatefulWidget {
  const SearchingRadar({super.key, this.size = 28, this.animate});

  final double size;

  /// Null = animate unless reduced motion is on (and not under
  /// `flutter test`, where an endless animation would stop pumpAndSettle).
  final bool? animate;

  @override
  State<SearchingRadar> createState() => _SearchingRadarState();
}

final bool _underTest = Platform.environment.containsKey('FLUTTER_TEST');

class _SearchingRadarState extends State<SearchingRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  bool _wanted(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return !reduce && (widget.animate ?? !_underTest);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SearchingRadar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_wanted(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final moving = _wanted(context);
    return Semantics(
      label: 'Searching for devices',
      child: SizedBox.square(
        dimension: widget.size,
        child: moving
            ? AnimatedBuilder(
                animation: _c,
                builder: (_, _) => CustomPaint(
                  painter: _RadarPainter(_c.value, color),
                  child: Icon(
                    Icons.wifi_tethering,
                    size: widget.size * 0.55,
                    color: color,
                  ),
                ),
              )
            : Icon(Icons.wifi_find, size: widget.size * 0.8, color: color),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.color);
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = math.min(size.width, size.height) / 2;
    for (var i = 0; i < 2; i++) {
      final p = (t + i / 2) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - p) * 0.8);
      canvas.drawCircle(c, maxR * (0.35 + 0.65 * p), paint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}
