import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';

class AchievementsRow extends StatelessWidget {
  const AchievementsRow({
    super.key,
    required this.streak,
    required this.ownedAreaSqm,
    required this.hasSquad,
  });

  final int streak;
  final double ownedAreaSqm;
  final bool hasSquad;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final achievements = [
      (
        icon: Icons.local_fire_department,
        label: '4d Streak',
        unlocked: streak >= 4,
        requirement: 'Dismiss alarms 4 days in a row to unlock.',
      ),
      (
        icon: Icons.landscape,
        label: 'Territory',
        unlocked: ownedAreaSqm > 0,
        requirement: 'Complete a run that closes a loop to capture territory.',
      ),
      (
        icon: Icons.groups,
        label: 'Squad',
        unlocked: hasSquad,
        requirement: 'Join or create a squad to unlock.',
      ),
      (
        icon: Icons.emoji_events,
        label: '30d Streak',
        unlocked: streak >= 30,
        requirement: 'Dismiss alarms 30 days in a row to unlock.',
      ),
    ];
    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: achievements.map((a) {
          return Semantics(
            label: '${a.label}, ${a.unlocked ? 'unlocked' : 'locked'}',
            button: !a.unlocked,
            hint: a.unlocked ? null : a.requirement,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: a.unlocked
                    ? null
                    : () {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text('${a.label}: ${a.requirement}'),
                            ),
                          );
                      },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: a.unlocked
                            ? scheme.primary.withValues(alpha: 0.2)
                            : scheme.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        a.icon,
                        size: 18,
                        color: a.unlocked
                            ? scheme.primary
                            : secondaryLabelColor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: a.unlocked
                            ? scheme.onSurface
                            : secondaryLabelColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
