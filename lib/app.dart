import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/router/navigator_key.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/no_scrollbar_behavior.dart';
import 'core/theme/theme_mode_cubit.dart';
import 'core/usecase/usecase.dart';
import 'features/alarm/presentation/bloc/alarm_cubit.dart';
import 'features/alarm/presentation/bloc/alarm_state.dart';
import 'features/alarm/presentation/pages/alarm_ring_page.dart';
import 'features/onboarding/domain/usecases/has_seen_onboarding.dart';
import 'features/onboarding/domain/usecases/mark_onboarding_seen.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/shell/presentation/pages/app_shell_page.dart';

class AwakenApp extends StatelessWidget {
  const AwakenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AlarmCubit>(create: (_) => getIt<AlarmCubit>()),
        BlocProvider<ThemeModeCubit>(create: (_) => getIt<ThemeModeCubit>()),
      ],
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          return BlocBuilder<ThemeModeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return MaterialApp(
                navigatorKey: navigatorKey,
                title: 'Awaken',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(lightDynamic),
                darkTheme: AppTheme.dark(darkDynamic),
                themeMode: themeMode,
                // The handoff's scrollable regions never show a scrollbar thumb.
                scrollBehavior: const NoScrollbarBehavior(),
                home: const _StartupFlow(),
                // A ringing alarm must take over the screen regardless of how
                // deep the user has navigated (settings, the reliability
                // self-test, etc. — plan C6: the ring screen is what greets
                // the user when the FSI/HUN brings the app to the foreground,
                // not buried under back-stack state). Switching this inside a
                // single route (e.g. only the `home` widget) does NOT achieve
                // that — this was verified wrong empirically (see Phase 1
                // reliability self-test notes) when a ringing alarm failed to
                // surface while a pushed route was on top. `builder` wraps
                // every route the Navigator ever shows, so this overlay always
                // wins.
                builder: (context, child) {
                  return _AlarmRingOverlay(
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Shows the onboarding carousel once per cold start unless the user has
/// already seen it (persisted via `HasSeenOnboarding`/`MarkOnboardingSeen`),
/// then the adaptive app shell.
class _StartupFlow extends StatefulWidget {
  const _StartupFlow();

  @override
  State<_StartupFlow> createState() => _StartupFlowState();
}

class _StartupFlowState extends State<_StartupFlow> {
  var _loading = true;
  var _onboarded = false;

  @override
  void initState() {
    super.initState();
    getIt<HasSeenOnboarding>()(const NoParams()).then((seen) {
      if (mounted) {
        setState(() {
          _onboarded = seen;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (!_onboarded) {
      return OnboardingPage(
        onFinished: () {
          unawaited(getIt<MarkOnboardingSeen>()(const NoParams()));
          setState(() => _onboarded = true);
        },
      );
    }
    return const AppShellPage();
  }
}

class _AlarmRingOverlay extends StatelessWidget {
  const _AlarmRingOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlarmCubit, AlarmState>(
      buildWhen: (previous, current) =>
          previous.ringingAlarm != current.ringingAlarm ||
          previous.verificationInProgress != current.verificationInProgress,
      builder: (context, state) {
        final ringing = state.ringingAlarm;
        // Real bug found live: this overlay used to paint AlarmRingPage
        // unconditionally whenever `ringing != null`, with no regard for
        // what the Navigator underneath was doing. When AlarmRingPage's own
        // "Start workout" pushed VerificationPage onto that Navigator, the
        // pushed screen ran successfully (camera + ML Kit both confirmed
        // active via logcat) but was permanently invisible — this overlay
        // kept repainting itself on top forever, since `ringing` doesn't
        // change just because a route got pushed below it. That trapped the
        // user on a frozen "Opening camera…" placeholder with the real
        // camera screen running, unreachable, right underneath. Stepping
        // aside while `verificationInProgress` is true lets the pushed
        // VerificationPage actually become visible and interactive.
        final showOverlay = ringing != null && !state.verificationInProgress;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Found via live accessibility-tree inspection: without this,
            // whatever route sits underneath (onboarding, a settings page,
            // etc.) stays reachable to screen readers — and in principle
            // to touch, since nothing else blocked it — while the ring
            // page is visually on top. The whole point of this overlay is
            // that nothing else is reachable while an alarm rings.
            if (showOverlay)
              ExcludeSemantics(child: IgnorePointer(child: child))
            else
              child,
            if (showOverlay) AlarmRingPage(alarm: ringing),
          ],
        );
      },
    );
  }
}
