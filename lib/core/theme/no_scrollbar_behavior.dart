import 'package:flutter/material.dart';

/// The Claude Design handoff's scrollable regions (`overflow-y:auto`) never
/// show a visible scrollbar/thumb — matched here by suppressing Flutter's
/// default Material scrollbar overlay app-wide (see `MaterialApp.scrollBehavior`
/// in `app.dart`). Overscroll glow/physics are untouched.
class NoScrollbarBehavior extends MaterialScrollBehavior {
  const NoScrollbarBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}
