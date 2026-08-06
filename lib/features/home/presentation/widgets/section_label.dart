import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';

/// The small uppercase section header ("ACHIEVEMENTS", "RECENT ACTIVITY")
/// — extracted since its color depends on `context` (`secondaryLabelColor`),
/// so it's no longer expressible as a top-level `const` literal the way it
/// was before, and this keeps that at one definition instead of two.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: secondaryLabelColor(context),
        ),
      ),
    );
  }
}
