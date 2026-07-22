import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../profile/presentation/pages/profile_page.dart';

/// Squad leaderboard (Claude Design handoff — `isSquad`). No Squad feature
/// exists anywhere in this codebase or its Supabase schema — this is
/// presentation-only concept UI, mocked exactly like the design prototype
/// (fake member names, static ranks).
class SquadPage extends StatelessWidget {
  const SquadPage({super.key});

  static const _liveMembers = [
    (initial: 'P', name: 'Priya K.', activity: 'Running · 2.1 km'),
    (initial: 'M', name: 'Marcus T.', activity: 'Workout · 14/20 squats'),
  ];

  static const _leaderboard = [
    (rank: 1, name: 'Priya K.', tier: 'Gold', area: '1.84 km²', isYou: false),
    (rank: 2, name: 'Marcus T.', tier: 'Gold', area: '1.61 km²', isYou: false),
    (rank: 3, name: 'You', tier: 'Silver', area: '1.42 km²', isYou: true),
    (rank: 4, name: 'Elena R.', tier: 'Silver', area: '0.98 km²', isYou: false),
    (rank: 5, name: 'Devon W.', tier: 'Bronze', area: '0.71 km²', isYou: false),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Squad',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: scheme.onSurface),
                      ),
                      Text(
                        'Sunrise Runners · 5 members',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  Material(
                    color: scheme.secondaryContainer,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Text('G', style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live now', style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface)),
                    const SizedBox(height: 10),
                    Column(
                      children: List.generate(_liveMembers.length, (i) {
                        final m = _liveMembers[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: groupedItemRadius(index: i, count: _liveMembers.length, outer: 20),
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: scheme.tertiaryContainer,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Text(
                                          m.initial,
                                          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onTertiaryContainer),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -2,
                                      right: -2,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: scheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: scheme.surfaceContainerHigh, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.name, style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface)),
                                      Text(
                                        m.activity,
                                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: scheme.secondaryContainer,
                                    foregroundColor: scheme.onSecondaryContainer,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                  ),
                                  onPressed: () {},
                                  child: const Text('Cheer'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurface)),
                    const SizedBox(height: 10),
                    Column(
                      children: List.generate(_leaderboard.length, (i) {
                        final row = _leaderboard[i];
                        final radius = row.isYou
                            ? BorderRadius.circular(999)
                            : groupedItemRadius(index: i, count: _leaderboard.length, outer: 20);
                        final bg = row.isYou ? scheme.primaryContainer : scheme.surfaceContainerLow;
                        final fg = row.isYou ? scheme.onPrimaryContainer : scheme.onSurface;
                        final rankBg = row.rank == 1
                            ? scheme.tertiaryContainer
                            : row.isYou
                            ? scheme.onPrimaryContainer
                            : scheme.surfaceContainerHigh;
                        final rankFg = row.rank == 1
                            ? scheme.onTertiaryContainer
                            : row.isYou
                            ? scheme.primaryContainer
                            : scheme.onSurfaceVariant;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            decoration: BoxDecoration(color: bg, borderRadius: radius),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(color: rankBg, shape: BoxShape.circle),
                                  child: Center(
                                    child: Text(
                                      '${row.rank}',
                                      style: TextStyle(fontWeight: FontWeight.w800, color: rankFg),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(row.name, style: TextStyle(fontWeight: FontWeight.bold, color: fg)),
                                      Text(
                                        '${row.tier} streak',
                                        style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.75)),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  row.area,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: fg,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
