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
      DisplayTrust.verified => (idStatus(context).success, Icons.verified_user),
      DisplayTrust.trusted => (
        idStatus(context).success,
        Icons.shield_outlined,
      ),
      DisplayTrust.revoked => (
        idStatus(context).danger,
        Icons.remove_moderator_outlined,
      ),
      DisplayTrust.unknown => (IdColors.darkOnSurfaceMuted, Icons.help_outline),
      DisplayTrust.identityChanged => (
        idStatus(context).danger,
        Icons.gpp_bad_outlined,
      ),
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
        // 0.11.0 (spec D21): content at most 600dp wide, centred.
        constraints: const BoxConstraints(maxWidth: IdLayout.maxContentWidth),
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

/// 0.11.0: a one-line empty state (icon + short text), so the actions
/// below it stay high on the screen. [leading] replaces the icon (for
/// example the searching radar).
class EmptyLine extends StatelessWidget {
  const EmptyLine({
    super.key,
    required this.text,
    this.icon,
    this.leading,
    this.info,
  });

  final String text;
  final IconData? icon;
  final Widget? leading;

  /// Longer explanation behind an info icon (tap to read).
  final String? info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IdSpacing.xs),
      child: Row(
        children: [
          leading ??
              Icon(
                icon ?? Icons.info_outline,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          const SizedBox(width: IdSpacing.sm),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (info != null) InfoTip(title: text, text: info!),
        ],
      ),
    );
  }
}

/// 0.11.0: small info icon; tap opens a bottom sheet with the full text.
class InfoTip extends StatelessWidget {
  const InfoTip({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'More about: $title',
      constraints: const BoxConstraints(
        minWidth: IdLayout.minTouchTarget,
        minHeight: IdLayout.minTouchTarget,
      ),
      icon: const Icon(Icons.info_outline, size: 20),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              IdSpacing.lg,
              0,
              IdSpacing.lg,
              IdSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(c).textTheme.titleMedium),
                const SizedBox(height: IdSpacing.sm),
                Text(text, style: Theme.of(c).textTheme.bodyMedium),
                const SizedBox(height: IdSpacing.md),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
                  ),
                  onPressed: () => Navigator.pop(c),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 0.11.0: a setting with a title, ONE short line, an info icon for the
/// long text, and [control] (a Switch, a dropdown...). [extra] sits right
/// before the control (e.g. an "Allow" button).
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    required this.summary,
    required this.info,
    required this.control,
    this.extra,
    this.onTap,
    this.wideControl = false,
  });

  final String title;
  final String summary;
  final String info;
  final Widget control;
  final Widget? extra;

  /// Tapping the text toggles the setting (switch rows).
  final VoidCallback? onTap;

  /// A wide control (dropdown): moves under the text when space is short
  /// (narrow phones, big font sizes) instead of squeezing the title.
  final bool wideControl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.bodyLarge),
        Text(summary, style: theme.textTheme.bodySmall),
      ],
    );
    return LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
        final stack = wideControl && (box.maxWidth < 420 || scale > 1.3);
        final head = Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(IdRadii.sm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: IdLayout.minTouchTarget,
                  ),
                  child: Align(alignment: Alignment.centerLeft, child: text),
                ),
              ),
            ),
            InfoTip(title: title, text: info),
            if (!stack) ...[
              if (extra != null) ...[
                extra!,
                const SizedBox(width: IdSpacing.sm),
              ],
              control,
            ],
          ],
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: IdSpacing.xs),
          child: stack
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    head,
                    Wrap(
                      spacing: IdSpacing.sm,
                      runSpacing: IdSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [control, ?extra],
                    ),
                  ],
                )
              : head,
        );
      },
    );
  }
}

/// A [SettingRow] with a switch (labelled for TalkBack).
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.title,
    required this.summary,
    required this.info,
    required this.value,
    required this.onChanged,
    this.extra,
  });

  final String title;
  final String summary;
  final String info;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => SettingRow(
    title: title,
    summary: summary,
    info: info,
    extra: extra,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    control: Semantics(
      label: title,
      child: Switch(value: value, onChanged: onChanged),
    ),
  );
}
