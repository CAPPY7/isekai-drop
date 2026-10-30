import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

const _slides = [
  _Slide(
    Icons.devices,
    'Open Isekai Drop on both devices',
    'Phones and PCs. No account and no cloud.',
  ),
  _Slide(
    Icons.wifi,
    'Use the same Wi-Fi',
    'Both devices on one network (or one shares a hotspot). The first '
        'time, connect them once with a QR code.',
  ),
  _Slide(
    Icons.send_rounded,
    'Pick files and send',
    'Files go straight between your devices, encrypted and checked.',
  ),
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

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _slides.length - 1) {
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
    final last = _page == _slides.length - 1;
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
                      child: const Text('Skip'),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pages,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: [
                      for (final s in _slides)
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
                  label: 'Step ${_page + 1} of ${_slides.length}',
                  excludeSemantics: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _slides.length; i++)
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
                    child: Text(last ? 'Get started' : 'Next'),
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
