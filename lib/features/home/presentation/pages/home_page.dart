import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/gamification_widgets.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../profile/presentation/widgets/current_user_avatar_button.dart';
import '../../../squad/domain/entities/streak_tier.dart';
import '../bloc/home_cubit.dart';
import '../bloc/home_state.dart';
import '../widgets/achievements_row.dart';
import '../widgets/greeting_text.dart';
import '../widgets/home_skeletons.dart';
import '../widgets/next_alarm_card.dart';
import '../widgets/quick_actions_pill.dart';
import '../widgets/recent_activity_section.dart';
import '../widgets/section_label.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.onOpenAlarms,
    required this.onOpenTerritory,
    required this.onOpenSquad,
    super.key,
  });

  final VoidCallback onOpenAlarms;
  final VoidCallback onOpenTerritory;
  final VoidCallback onOpenSquad;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return BlocProvider<HomeCubit>(
      create: (_) => getIt<HomeCubit>(),
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: BlocBuilder<HomeCubit, HomeState>(
            builder: (context, home) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: AppleGlassContainer(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const RepaintBoundary(child: GreetingText()),
                              Text(
                                'Awaken',
                                style:
                                    Theme.of(context).textTheme.titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          color: scheme.onSurface,
                                        ) ??
                                    TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: scheme.onSurface,
                                    ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                // A hard `height:` forces the child Row
                                // into that exact cross-axis size — at
                                // large system text scale the Text
                                // below needs more than 30dp and
                                // overflows (`RenderFlex`) instead of
                                // the pill growing. `constraints` with
                                // only a minimum lets it grow.
                                constraints: const BoxConstraints(
                                  minHeight: 30,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.semanticColors.streakFlame
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department,
                                      size: 14,
                                      color: context.semanticColors.streakFlame,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${home.streak}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            context.semanticColors.streakFlame,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              StreakTierAvatarRing(
                                tier: streakTierForDays(home.streak),
                                // 44 (the avatar's own tap target) + ring
                                // width/padding so the ring wraps around the
                                // button instead of clipping it down.
                                size: 53,
                                child: const CurrentUserAvatarButton(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => context.read<HomeCubit>().refresh(),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NextAlarmCardBloc(onViewAlarms: onOpenAlarms),
                            const SizedBox(height: 12),
                            if (home.wakeUpTaxMultiplier > 1.0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: WakeUpTaxMeter(
                                  multiplier: home.wakeUpTaxMultiplier,
                                ),
                              ),
                            if (home.streak == 0 &&
                                home.ownedAreaSqm == 0 &&
                                !home.streakError &&
                                !home.ownedAreaError &&
                                !home.streakLoading &&
                                !home.ownedAreaLoading)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  "Dismiss an alarm or capture territory to build your stats.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryLabelColor(context),
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: home.streakLoading
                                      ? const SkeletonStatTile(
                                          radius: BorderRadius.horizontal(
                                            left: Radius.circular(14),
                                          ),
                                        )
                                      : StatTile(
                                          bg: scheme.surfaceContainer,
                                          fg: scheme.primary,
                                          icon: Icons.local_fire_department,
                                          value: '${home.streak}',
                                          label: 'Day streak',
                                          hasError: home.streakError,
                                          radius: const BorderRadius.horizontal(
                                            left: Radius.circular(14),
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: home.ownedAreaLoading
                                      ? const SkeletonStatTile()
                                      : StatTile(
                                          bg: scheme.surfaceContainer,
                                          fg: context
                                              .semanticColors
                                              .territoryOwned,
                                          icon: Icons.landscape,
                                          value: (home.ownedAreaSqm / 1000000)
                                              .toStringAsFixed(2),
                                          label: 'km² owned',
                                          hasError: home.ownedAreaError,
                                        ),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: StatTile(
                                    bg: scheme.surfaceContainer,
                                    fg: context.semanticColors.success,
                                    icon: Icons.emoji_events,
                                    value: home.squadRank == null
                                        ? '—'
                                        : '#${home.squadRank}',
                                    label: 'Squad rank',
                                    hasError: home.squadRankError,
                                    radius: const BorderRadius.horizontal(
                                      right: Radius.circular(14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            QuickActionsPill(
                              onOpenTerritory: onOpenTerritory,
                              onOpenSquad: onOpenSquad,
                            ),
                            const SizedBox(height: 14),
                            Semantics(
                              header: true,
                              child: const SectionLabel('ACHIEVEMENTS'),
                            ),
                            AchievementsRow(
                              streak: home.streak,
                              ownedAreaSqm: home.ownedAreaSqm,
                              hasSquad: home.squad != null,
                            ),
                            const SizedBox(height: 14),
                            Semantics(
                              header: true,
                              child: const SectionLabel('RECENT ACTIVITY'),
                            ),
                            RepaintBoundary(
                              child: RecentActivitySection(
                                activity: home.recentActivity,
                                hasError: home.recentActivityError,
                                loading: home.recentActivityLoading,
                                onRetry: () => context
                                    .read<HomeCubit>()
                                    .retryRecentActivity(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
