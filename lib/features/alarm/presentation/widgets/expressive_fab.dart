import 'package:flutter/material.dart';

import '../../../../core/theme/shape_tokens.dart';

class ExpressiveFab extends StatefulWidget {
  const ExpressiveFab({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<ExpressiveFab> createState() => ExpressiveFabState();
}

class ExpressiveFabState extends State<ExpressiveFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Add alarm',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          width: 68,
          height: 68,
          transform: Matrix4.diagonal3Values(
            _pressed ? 1.06 : 1,
            _pressed ? 1.06 : 1,
            1,
          ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: _pressed ? ShapeTokens.pill : ShapeTokens.r22,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(Icons.add, size: 30, color: scheme.onPrimary),
        ),
      ),
    );
  }
}
