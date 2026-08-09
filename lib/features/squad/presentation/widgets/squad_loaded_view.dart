import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../bloc/squad_state.dart';
import 'conquest_ticker.dart';
import 'invite_code_card.dart';
import 'leaderboard_row.dart';
import 'member_avatar.dart';
import 'squad_page_shared.dart';
import '../../../../core/theme/shape_tokens.dart';

class SquadLoadedView extends StatelessWidget {
  const SquadLoadedView({super.key, required this.state});

  final SquadState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final squad = state.squad!;
    final live = state.presence.where((m) => m.activity != null).toList();

    // Vertical centering (previously `MainAxisAlignment.center`) pushed
    // real content — invite card, leaderboard rows — down behind a large
    // blank gap instead of anchoring to the top like every other tab. Top-
    // aligned matches Home/Alarms/Territory; still scrolls normally once
    // there's enough content to need it.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InviteCodeCard(inviteCode: squad.inviteCode),
            const SizedBox(height: 14),
            const ConquestTicker(),
            const SizedBox(height: 18),
            if (live.isNotEmpty) ...[
              Text(
                'Live now',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: List.generate(live.length, (i) {
                  final m = live[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: groupedItemRadius(
                          index: i,
                          count: live.length,
                          outer: 20,
                        ),
                      ),
                      child: Semantics(
                        label:
                            '${m.displayName}, live now'
                            '${m.activity == null || m.activity!.isEmpty ? '' : ', ${m.activity}'}',
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  MemberAvatar(
                                    displayName: m.displayName,
                                    avatarUrl: m.avatarUrl,
                                    size: 44,
                                    borderRadius: ShapeTokens.r16,
                                    background: scheme.tertiaryContainer,
                                    foreground: scheme.onTertiaryContainer,
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
                                        border: Border.all(
                                          color: scheme.surfaceContainerHigh,
                                          width: 2,
                                        ),
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
                                    Text(
                                      m.displayName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      m.activity ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 22),
            ],
            Text(
              'Leaderboard',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            if (state.leaderboard.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No squad activity yet — capture territory to appear here.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              )
            else
              Column(
                children: List.generate(state.leaderboard.length, (i) {
                  final row = state.leaderboard[i];
                  return LeaderboardRow(
                    row: row,
                    index: i,
                    count: state.leaderboard.length,
                    isTied: isLeaderboardRowTied(state.leaderboard, i),
                  );
                }),
              ),
            const SizedBox(height: 22),
            Center(
              child: TextButton(
                // Reversible (rejoin with the invite code) — no longer
                // styled identically to Profile's irreversible
                // "Delete account".
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurfaceVariant,
                ),
                onPressed: state.isLeavingSquad
                    ? null
                    : () => confirmLeaveSquad(context),
                child: state.isLeavingSquad
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Leave squad'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
