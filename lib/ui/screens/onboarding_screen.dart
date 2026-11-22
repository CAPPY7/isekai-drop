import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../../l10n/l10n.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

List<_Slide> _slidesFor(AppLocalizations l) => [
  _Slide(Icons.devices, l.slide1Title, l.slide1Text),
  _Slide(Icons.wifi, l.slide2Title, l.slide2Text),
  _Slide(Icons.send_rounded, l.slide3Title, l.slide3Text),
];

/// 0.11.0 (spec A8): three short slides, shown once, skippable.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  static const _count = 3;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _count - 1) {
      widget.onDone();
      return;
    }
    final still = MediaQuery.maybeDisableAnimationsOf(context) == true;
    if (still) {
      _pages.jumpToPage(_page + 1);
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = _page == _count - 1;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: IdLayout.maxContentWidth,
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.all(IdSpacing.sm),
                    child: TextButton(
                      key: const ValueKey('onboarding-skip'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(
                          IdLayout.minTouchTarget,
                          IdLayout.minTouchTarget,
                        ),
                      ),
                      onPressed: widget.onDone,
                      child: Text(tr(context).skip),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      for (final s in _slidesFor(tr(context)))
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(IdSpacing.lg),
                          child: Column(
                            children: [
                              const SizedBox(height: IdSpacing.xl),
                              Icon(
                                s.icon,
                                size: 96,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: IdSpacing.lg),
                              Text(
                                s.title,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: IdSpacing.md),
                              Text(
                                s.text,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Semantics(
                  container: true,
                  label: tr(context).stepOf('${_page + 1}', '$_count'),
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _count; i++)
                        Container(
                          margin: const EdgeInsets.all(IdSpacing.xs),
                          // Size, not only colour, shows the current step.
                          width: i == _page ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                            borderRadius: BorderRadius.circular(IdRadii.pill),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(IdSpacing.lg),
                  child: FilledButton(
                    key: const ValueKey('onboarding-next'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    onPressed: _next,
                    child: Text(
                      last ? tr(context).getStarted : tr(context).next,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
