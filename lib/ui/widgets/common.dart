import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Rounded card with a title.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: IdSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(IdSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: IdSpacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

/// Empty / loading / error helpers.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(IdSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: IdSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: IdSpacing.xs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: IdSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}

/// Loads data and shows loading, error (with Retry), empty or the content.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.future,
    required this.onRetry,
    required this.isEmpty,
    required this.empty,
    required this.builder,
  });

  final Future<T> future;
  final VoidCallback onRetry;
  final bool Function(T data) isEmpty;
  final Widget empty;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(IdSpacing.lg),
            child: Center(
              child: CircularProgressIndicator(semanticsLabel: 'Loading'),
            ),
          );
        }
        if (snap.hasError) {
          return StateMessage(
            icon: Icons.error_outline,
            title: 'Could not load this',
            message: 'Something went wrong. Tap Retry to try again.',
            action: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          );
        }
        final data = snap.data as T;
        return isEmpty(data) ? empty : builder(data);
      },
    );
  }
}

enum DisplayTrust { verified, trusted, unknown, identityChanged, revoked }

extension DisplayTrustLabel on DisplayTrust {
  String get label => switch (this) {
    DisplayTrust.verified => 'Verified (code compared)',
    DisplayTrust.trusted => 'Paired (code not checked)',
    DisplayTrust.unknown => 'Unknown - not paired',
    DisplayTrust.identityChanged => 'Identity changed - blocked',
    DisplayTrust.revoked => 'Revoked - blocked',
  };

  bool get canSend =>
      this == DisplayTrust.verified || this == DisplayTrust.trusted;
}

class TrustBadge extends StatelessWidget {
  const TrustBadge({super.key, required this.trust});

  final DisplayTrust trust;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (trust) {
      DisplayTrust.verified => (IdColors.success, Icons.verified_user),
      DisplayTrust.trusted => (IdColors.success, Icons.shield_outlined),
      DisplayTrust.revoked => (
        IdColors.danger,
        Icons.remove_moderator_outlined,
      ),
      DisplayTrust.unknown => (IdColors.darkOnSurfaceMuted, Icons.help_outline),
      DisplayTrust.identityChanged => (IdColors.danger, Icons.gpp_bad_outlined),
    };
    return Semantics(
      label: 'Trust: ${trust.label}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              trust.label,
              style: TextStyle(color: color, fontSize: IdTypeSizes.caption),
            ),
          ),
        ],
      ),
    );
  }
}

IconData platformIcon(String p) => switch (p) {
  'android' => Icons.phone_android,
  'ios' => Icons.phone_iphone,
  'windows' => Icons.desktop_windows,
  'macos' => Icons.laptop_mac,
  _ => Icons.computer,
};

/// Standard page body: scrolls, max width, padding.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(IdSpacing.md),
          children: children,
        ),
      ),
    );
  }
}

/// A "not built yet" disabled button with the reason written on it.
class NotYetButton extends StatelessWidget {
  const NotYetButton({super.key, required this.label, required this.reason});

  final String label;
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label. Disabled. $reason',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(onPressed: null, child: Text(label)),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: IdSpacing.sm),
            child: Text(
              reason,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

String formatTime(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}
