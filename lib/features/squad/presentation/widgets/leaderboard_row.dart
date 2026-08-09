import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/gamification_widgets.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../domain/entities/leaderboard_entry.dart';
import 'member_avatar.dart';
import 'squad_page_shared.dart';
import '../../../../core/theme/shape_tokens.dart';

class LeaderboardRow extends StatelessWidget {
  const LeaderboardRow({
    super.key,
    required this.row,
    required this.index,
    required this.count,
    this.isTied = false,
  });

  final LeaderboardEntry row;
  final int index;
  final int count;

  /// See [isLeaderboardRowTied] — renders as "T-N" instead of "N" so a
  /// shared rank never implies a false ordering between tied rows.
  final bool isTied;

  /// Ranks 1-3 get gold/silver/bronze podium styling (distinct background
  /// tint, taller row, bigger avatar) instead of the flat row every other
  /// rank uses — matches ranks, not list position, so a page 2+ of the
  /// paginated leaderboard sheet never podium-styles anything (no rank <= 3
  /// row can appear there).
  int? get _podiumPlace => row.rank <= 3 ? row.rank : null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.semanticColors;
    final podiumPlace = _podiumPlace;

    // Bronze/silver reuse `StreakTierAvatarRing`'s fixed "metal" hues so the
    // podium and the streak-tier ring share one visual language; gold reuses
    // the semantic bounty-gold role per the audit's design-system guidance.
    final podiumColor = switch (podiumPlace) {
      1 => colors.bountyGold,
      2 => const Color(0xFFA8AEB8),
      3 => const Color(0xFFB08D57),
      _ => null,
    };

    final radius = row.isYou
        ? ShapeTokens.r14
        : groupedItemRadius(index: index, count: count, outer: 14);
    final bg = podiumColor != null
        ? podiumColor.withValues(alpha: 0.16)
        : row.isYou
        ? scheme.primary.withValues(alpha: 0.18)
        : scheme.surfaceContainer;
    final fg = row.isYou ? scheme.primary : scheme.onSurface;
    final rankBg = podiumColor != null
        ? podiumColor.withValues(alpha: 0.24)
        : row.isYou
        ? scheme.primary.withValues(alpha: 0.25)
        : scheme.surfaceContainerHigh;
    final rankFg =
        podiumColor ??
        (row.isYou ? scheme.primary : secondaryLabelColor(context));

    // Height variation: 1st place tallest, 2nd/3rd a step down, everything
    // else flat.
    final verticalPadding = switch (podiumPlace) {
      1 => 18.0,
      2 => 15.0,
      3 => 14.0,
      _ => 13.0,
    };
    final avatarSize = switch (podiumPlace) {
      1 => 40.0,
      2 => 36.0,
      3 => 34.0,
      _ => 32.0,
    };
    final rankLabel = isTied ? 'T-${row.rank}' : '${row.rank}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(
            color: podiumColor != null
                ? podiumColor.withValues(alpha: 0.5)
                : row.isYou
                ? scheme.primary.withValues(alpha: 0.4)
                : scheme.outline,
            width: row.isYou || podiumColor != null ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label:
                    '${isTied ? 'Tied rank' : 'Rank'} ${row.rank}, ${row.displayName}'
                    '${row.isYou ? ', you' : ''}, '
                    '${row.streakTier.label}, '
                    '${(row.areaSqm / 1000000).toStringAsFixed(2)} square kilometers',
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: rankBg,
                          shape: BoxShape.circle,
                        ),
                        // `FittedBox` shrinks the rank number to fit the
                        // fixed 32x32 circle at large system text scale
                        // instead of painting outside it — `Center` alone
                        // doesn't constrain an oversized child, only
                        // positions it.
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Text(
                                rankLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: rankFg,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StreakTierAvatarRing(
                        tier: row.streakTier,
                        size: avatarSize,
                        child: MemberAvatar(
                          displayName: row.displayName,
                          avatarUrl: row.avatarUrl,
                          size: avatarSize,
                          borderRadius: BorderRadius.circular(avatarSize / 2),
                          background: scheme.tertiaryContainer,
                          foreground: scheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.displayName,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: fg,
                              ),
                            ),
                            Text(
                              row.streakTier.label,
                              style: TextStyle(
                                fontSize: 12,
                                color: fg.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(row.areaSqm / 1000000).toStringAsFixed(2)} km²',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: fg,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!row.isYou) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Report member',
                icon: Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: fg.withValues(alpha: 0.6),
                ),
                onPressed: () => showReportMemberDialog(
                  context,
                  userId: row.userId,
                  displayName: row.displayName,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
