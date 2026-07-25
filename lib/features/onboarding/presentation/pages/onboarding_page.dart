import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/expressive_widgets.dart';
import 'battery_exemption_page.dart';

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
    body:
        'Team up, watch each other train live, and climb the leaderboard together.',
    bg: (s) => s.secondaryContainer,
    fg: (s) => s.onSecondaryContainer,
    flower: (s) => s.secondary,
  ),
];

/// Concept-stage onboarding carousel (Claude Design handoff — `isOnboarding`
/// state in the flow prototype) + the permission-setup steps that used to
/// fire bluntly from `main_common.dart`'s bootstrap with no rationale
/// screen at all (Phase 3 finding). Not gated behind any persisted
/// "has-seen-onboarding" flag beyond what `AwakenApp`/`HasSeenOnboarding`
/// already do — shown once per cold start until finished.
///
/// Flow: [3 marketing cards] → notification-permission rationale → battery
/// exemption. "Skip" only skips the marketing cards (jumps to the
/// notification-rationale step) — it deliberately cannot skip the
/// permission-setup steps themselves, since those are functionally
/// necessary for the alarm to actually fire, not just narrative. The
/// alarm-reliability *self-test* (`AlarmReliabilityTestPage`, reachable
/// from Profile → "Alarm reliability") is deliberately NOT included here:
/// it schedules a real ~90s test alarm and expects the user to lock/
/// background the device, which is a fine opt-in diagnostic but a poor
/// mandatory first-run step — the closing card below just points at it.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

enum _OnboardingStep { marketing, notificationRationale, batteryExemption }

class _OnboardingPageState extends State<OnboardingPage> {
  var _cardIndex = 0;
  var _step = _OnboardingStep.marketing;
  var _requestingNotificationPermission = false;

  void _skipToPermissionSetup() =>
      setState(() => _step = _OnboardingStep.notificationRationale);

  Future<void> _continueFromNotificationRationale() async {
    if (_requestingNotificationPermission) return;
    setState(() => _requestingNotificationPermission = true);
    try {
      // Android 13+ blocks ALL notifications — including the alarm's
      // full-screen-intent one — until this is granted at runtime; a
      // manifest declaration alone does nothing. Previously fired bluntly
      // from bootstrap with zero explanation before the OS dialog; this
      // rationale card is that missing context. Never blocks onboarding on
      // the outcome — denying here doesn't trap the user, it just means
      // the alarm may not surface reliably until they grant it later (via
      // OS settings).
      if (Platform.isAndroid || Platform.isIOS) {
        await Permission.notification.request();
      }
    } finally {
      if (mounted) {
        setState(() {
          _requestingNotificationPermission = false;
          _step = _OnboardingStep.batteryExemption;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _OnboardingStep.marketing => _MarketingCarousel(
        cardIndex: _cardIndex,
        onCardIndexChanged: (i) => setState(() => _cardIndex = i),
        onSkip: _skipToPermissionSetup,
        onFinishedMarketing: _skipToPermissionSetup,
      ),
      _OnboardingStep.notificationRationale => _NotificationRationaleCard(
        requesting: _requestingNotificationPermission,
        onContinue: _continueFromNotificationRationale,
      ),
      _OnboardingStep.batteryExemption => BatteryExemptionPage(
        onContinue: widget.onFinished,
      ),
    };
  }
}

class _MarketingCarousel extends StatelessWidget {
  const _MarketingCarousel({
    required this.cardIndex,
    required this.onCardIndexChanged,
    required this.onSkip,
    required this.onFinishedMarketing,
  });

  final int cardIndex;
  final ValueChanged<int> onCardIndexChanged;
  final VoidCallback onSkip;
  final VoidCallback onFinishedMarketing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final card = _cards[cardIndex];
    final isLast = cardIndex == _cards.length - 1;

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
                        style: TextStyle(
                          fontSize: 16,
                          color: card.fg(scheme).withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 12,
                ),
                child: Row(
                  children: List.generate(_cards.length, (i) {
                    final active = i == cardIndex;
                    return Expanded(
                      flex: active ? 3 : 1,
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 500),
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
                      style: TextButton.styleFrom(
                        foregroundColor: card.fg(scheme).withValues(alpha: 0.7),
                      ),
                      onPressed: onSkip,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: isLast
                          ? onFinishedMarketing
                          : () => onCardIndexChanged(
                              (cardIndex + 1).clamp(0, _cards.length - 1),
                            ),
                      child: isLast
                          ? const Text('Continue')
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

class _NotificationRationaleCard extends StatelessWidget {
  const _NotificationRationaleCard({
    required this.requesting,
    required this.onContinue,
  });

  final bool requesting;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExpressiveFlower(
                    size: 64,
                    color: scheme.secondaryContainer,
                    child: Icon(
                      Icons.notifications_active,
                      size: 30,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'One more thing',
                    style: TextStyle(
                      fontSize: 30,
                      height: 36 / 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.4,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text(
                  "Awaken's alarm needs notification permission to show its wake-up "
                  "screen — without it, Android silently blocks the alarm from "
                  "appearing at all, even though it's still scheduled. You'll see "
                  "the system permission prompt next.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: requesting ? null : onContinue,
                  child: requesting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
