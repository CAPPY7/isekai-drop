import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../theme/design_tokens.dart';

/// The single Phase 1 screen. Proves the app builds and runs.
class Phase1Screen extends StatelessWidget {
  const Phase1Screen({super.key, required this.engine});

  final TransferEngine engine;

  static const String headline = 'Isekai Drop - Phase 1 works';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engineText = engine.status == EngineStatus.notImplemented
        ? 'File sending is not built yet. It arrives in Phase 2.'
        : 'Engine ready.';
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= IdLayout.desktopBreakpoint;
          final card = _Card(
            headline: headline,
            engineText: engineText,
            engineVersion: engine.version,
            large: isDesktop,
          );
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, -0.8),
                radius: 1.4,
                colors: [
                  IdColors.accentPurple.withValues(alpha: 0.18),
                  theme.scaffoldBackgroundColor,
                ],
              ),
            ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    isDesktop ? IdSpacing.xxl : IdSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 640 : 480,
                    ),
                    child: card,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.headline,
    required this.engineText,
    required this.engineVersion,
    required this.large,
  });

  final String headline;
  final String engineText;
  final String engineVersion;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(large ? IdSpacing.xxl : IdSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Isekai Drop logo',
              child: Container(
                width: large ? 96 : 72,
                height: large ? 96 : 72,
                decoration: BoxDecoration(
                  gradient: IdColors.brandGradient,
                  borderRadius: BorderRadius.circular(IdRadii.lg),
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: Colors.white,
                  size: large ? 52 : 40,
                ),
              ),
            ),
            const SizedBox(height: IdSpacing.lg),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: large
                  ? theme.textTheme.displaySmall
                  : theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: IdSpacing.md),
            Text(
              engineText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: IdSpacing.sm),
            Text(
              'Engine: $engineVersion',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
