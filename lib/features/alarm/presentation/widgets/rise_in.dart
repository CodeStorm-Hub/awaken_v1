import 'dart:async';

import 'package:flutter/material.dart';

class RiseIn extends StatefulWidget {
  const RiseIn({required this.delay, required this.child, super.key});

  final Duration delay;
  final Widget child;

  @override
  State<RiseIn> createState() => RiseInState();
}

class RiseInState extends State<RiseIn> {
  bool _played = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _played = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _played ? Offset.zero : const Offset(0, 0.12),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: _played ? 1 : 0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
