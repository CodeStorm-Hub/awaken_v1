import 'package:flutter/material.dart';

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key, required this.color});

  final Color color;

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _startedAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Reduce motion" — same crash/fix pattern as `_RingingBellState` in
    // `alarm_ring_page.dart` and `_StatusBannerState` in
    // `verification_page.dart`: `MediaQuery.disableAnimationsOf` can't be
    // called from `initState`, and the `_startedAnimating` latch keeps a
    // later dependency change from restarting an already-running loop.
    if (!_startedAnimating && !MediaQuery.disableAnimationsOf(context)) {
      _startedAnimating = true;
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 1.0).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
