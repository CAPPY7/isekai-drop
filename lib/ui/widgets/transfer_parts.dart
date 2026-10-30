// 0.11.0 (spec C11/C13/C14): pieces of the transfer screen. UI only; all
// numbers come from the job (measured bytes over time).
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/direct/direct_link.dart' show LinkRoute;
import '../../engine/platform_engine.dart' show readConnectionInfo;
import '../theme/design_tokens.dart';
import 'wifi_band.dart';

/// "Router · 5 GHz", "Fast direct · 5 GHz", "Router · Ethernet", "Router".
/// [localLink] is this device's own link ("5 GHz", "Ethernet") for the
/// router route; a Fast direct link brings its band in [routeDetail]
/// (e.g. "5 GHz (5180 MHz), 866 Mbps").
String? routeChipText(
  LinkRoute? route,
  String? routeDetail,
  String? localLink,
) {
  if (route == null) return null;
  final direct = route != LinkRoute.router;
  String? band;
  if (direct) {
    final m = RegExp(r'(2\.4|5|6) GHz').firstMatch(routeDetail ?? '');
    band = m?.group(0);
  } else {
    band = localLink;
  }
  return [direct ? 'Fast direct' : 'Router', ?band].join(' · ');
}

/// This device's own link for the route chip: "5 GHz", "2.4 GHz",
/// "Ethernet" or null (unknown). Android and Windows report it.
Future<String?> localLinkLabel() async {
  if (!(Platform.isAndroid || Platform.isWindows)) return null;
  try {
    final i = await readConnectionInfo();
    if (i.ethernet) return 'Ethernet';
    return wifiBandLabel(i.frequencyMhz);
  } catch (_) {
    return null;
  }
}

/// Shows the route as a chip with an icon (not colour alone, spec D19).
class RouteChip extends StatelessWidget {
  const RouteChip({super.key, required this.text, required this.direct});

  final String text;
  final bool direct;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Route: $text',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('route-chip'),
        padding: const EdgeInsets.symmetric(
          horizontal: IdSpacing.md,
          vertical: IdSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(IdRadii.pill),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              direct ? Icons.bolt : Icons.router_outlined,
              size: 16,
              color: scheme.primary,
            ),
            const SizedBox(width: IdSpacing.xs),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small speed chart of the last ~30 s (one value per second, bytes/s).
class SpeedSparkline extends StatelessWidget {
  const SpeedSparkline({super.key, required this.values, this.height = 48});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Speed chart of the last ${values.length} seconds',
      excludeSemantics: true,
      child: SizedBox(
        key: const ValueKey('speed-sparkline'),
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SparkPainter(values, scheme.primary)),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final top = values.reduce(math.max);
    if (top <= 0) return;
    // Always 30 slots, so the line grows from the left during the first 30 s.
    const slots = 30;
    final dx = size.width / (slots - 1);
    final start = slots - values.length;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (start + i) * dx;
      final y = size.height - (values[i] / top) * (size.height - 2) - 1;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    final fill = Path.from(path)
      ..lineTo((start + values.length - 1) * dx, size.height)
      ..lineTo(start * dx, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.color != color;
}

/// Success check that pops in (static when animations are off).
class SuccessCheck extends StatelessWidget {
  const SuccessCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final color = idStatus(context).success;
    final still = MediaQuery.maybeDisableAnimationsOf(context) == true;
    final icon = Icon(
      Icons.check_circle,
      size: 72,
      color: color,
      semanticLabel: 'Finished',
    );
    if (still) return icon;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(
        scale: v,
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: icon,
    );
  }
}

/// Splits an engine message into the problem (first sentence) and the
/// suggested fix (the rest), e.g. "The connection was lost." /
/// "When the sender taps Retry, it continues where it stopped."
(String, String?) splitProblem(String msg) {
  final m = RegExp(
    r'^(.+?[.!?])\s+(\S.*)$',
    dotAll: true,
  ).firstMatch(msg.trim());
  if (m == null) return (msg.trim(), null);
  return (m.group(1)!, m.group(2));
}

/// "holiday.jpg", "holiday.jpg + 3 more", or "4 files".
String jobTitle(List<String> names, int count) {
  if (names.isEmpty) return count == 1 ? '1 file' : '$count files';
  final first = names.first.split(RegExp(r'[\\/]')).last;
  return count > 1 ? '$first + ${count - 1} more' : first;
}
