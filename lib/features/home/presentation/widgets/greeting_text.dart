import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';

/// Previously computed once per `HomePage.build()` and never re-evaluated —
/// a user who opened the app just before a morning/afternoon/evening
/// rollover and left it foregrounded (this tab stays mounted via the shell's
/// `IndexedStack`) would keep seeing the stale greeting indefinitely. Ticks
/// on a coarse timer rather than depending on some other rebuild happening
/// to occur near the rollover.
class GreetingText extends StatefulWidget {
  const GreetingText({super.key});

  @override
  State<GreetingText> createState() => _GreetingTextState();
}

class _GreetingTextState extends State<GreetingText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _greeting,
      style: TextStyle(fontSize: 11, color: secondaryLabelColor(context)),
    );
  }
}
