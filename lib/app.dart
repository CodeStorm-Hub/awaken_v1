import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/di/injection.dart';
import 'core/router/navigator_key.dart';
import 'core/theme/app_theme.dart';
import 'features/alarm/presentation/bloc/alarm_cubit.dart';
import 'features/alarm/presentation/bloc/alarm_state.dart';
import 'features/alarm/presentation/pages/alarm_list_page.dart';
import 'features/alarm/presentation/pages/alarm_ring_page.dart';

class AwakenApp extends StatelessWidget {
  const AwakenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AlarmCubit>(
      create: (_) => getIt<AlarmCubit>(),
      child: DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Awaken',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(lightDynamic),
            darkTheme: AppTheme.dark(darkDynamic),
            themeMode: ThemeMode.system,
            home: const AlarmListPage(),
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
              return _AlarmRingOverlay(child: child ?? const SizedBox.shrink());
            },
          );
        },
      ),
    );
  }
}

class _AlarmRingOverlay extends StatelessWidget {
  const _AlarmRingOverlay({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AlarmCubit, AlarmState>(
      buildWhen: (previous, current) => previous.ringingAlarm != current.ringingAlarm,
      builder: (context, state) {
        final ringing = state.ringingAlarm;
        return Stack(
          children: [
            child,
            if (ringing != null) AlarmRingPage(alarm: ringing),
          ],
        );
      },
    );
  }
}
