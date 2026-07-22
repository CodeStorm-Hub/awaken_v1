import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';

class _OnboardCard {
  const _OnboardCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.bg,
    required this.fg,
    required this.flower,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color Function(ColorScheme) bg;
  final Color Function(ColorScheme) fg;
  final Color Function(ColorScheme) flower;
}

final _cards = <_OnboardCard>[
  _OnboardCard(
    icon: Icons.alarm_on,
    title: 'Wake up. For real this time.',
    body:
        'Dismiss your alarm only by completing camera-verified squats or push-ups — '
        'no more snoozing through your goals.',
    bg: (s) => s.primaryContainer,
    fg: (s) => s.onPrimaryContainer,
    flower: (s) => s.primary,
  ),
  _OnboardCard(
    icon: Icons.map,
    title: 'Every run claims ground.',
    body:
        'Close the loop on an outdoor run and the ground you covered becomes your '
        'territory on a shared map.',
    bg: (s) => s.tertiaryContainer,
    fg: (s) => s.onTertiaryContainer,
    flower: (s) => s.tertiary,
  ),
  _OnboardCard(
    icon: Icons.groups,
    title: 'Bring your squad.',
    body: 'Team up, watch each other train live, and climb the leaderboard together.',
    bg: (s) => s.secondaryContainer,
    fg: (s) => s.onSecondaryContainer,
    flower: (s) => s.secondary,
  ),
];

/// Concept-stage onboarding carousel (Claude Design handoff — `isOnboarding`
/// state in the flow prototype). Not gated behind any persisted
/// "has-seen-onboarding" flag yet — this app has no onboarding domain/data
/// layer today, so this is presentation-only, shown once per cold start
/// from `AwakenApp`.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = _cards[_index];
    final isLast = _index == _cards.length - 1;

    return Scaffold(
      backgroundColor: card.bg(scheme),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ExpressiveFlower(
                      size: 150,
                      color: card.flower(scheme),
                      animatePop: true,
                      child: Icon(card.icon, size: 64, color: card.bg(scheme)),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 290,
                      child: Text(
                        card.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          height: 38 / 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: card.fg(scheme),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 290,
                      child: Text(
                        card.body,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: card.fg(scheme).withValues(alpha: 0.8)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                child: Row(
                  children: List.generate(_cards.length, (i) {
                    final active = i == _index;
                    return Expanded(
                      flex: active ? 3 : 1,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        height: 5,
                        decoration: BoxDecoration(
                          color: active
                              ? card.fg(scheme)
                              : card.fg(scheme).withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Row(
                children: [
                  if (!isLast) ...[
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: card.fg(scheme).withValues(alpha: 0.7)),
                      onPressed: widget.onFinished,
                      child: const Text('Skip'),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: card.fg(scheme),
                        foregroundColor: card.bg(scheme),
                        minimumSize: const Size.fromHeight(60),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      onPressed: isLast
                          ? widget.onFinished
                          : () => setState(() => _index = (_index + 1).clamp(0, _cards.length - 1)),
                      child: isLast
                          ? const Text('Get started')
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('Next'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
