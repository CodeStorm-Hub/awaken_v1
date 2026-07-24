import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../bloc/squad_cubit.dart';
import '../bloc/squad_state.dart';

/// Squad leaderboard (Claude Design handoff — `isSquad`), wired to real
/// Supabase-backed squad state (plan §6 Phase 6) instead of the original
/// mock's fake members/static leaderboard. Visual layout kept from the
/// handoff — this is a data-wiring change, not a redesign.
class SquadPage extends StatelessWidget {
  const SquadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SquadCubit>(
      create: (_) => getIt<SquadCubit>(),
      child: const _SquadView(),
    );
  }
}

class _SquadView extends StatelessWidget {
  const _SquadView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: BlocBuilder<SquadCubit, SquadState>(
          builder: (context, state) {
            return Column(
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
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: scheme.onSurface,
                            ),
                          ),
                          Text(
                            state.squad == null
                                ? 'Not in a squad yet'
                                : '${state.squad!.name} · ${state.leaderboard.length} members',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      ProfileAvatarButton(
                        initial: 'G',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfilePage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _SquadBody(state: state)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SquadBody extends StatelessWidget {
  const _SquadBody({required this.state});

  final SquadState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case SquadStatus.loading:
        return const Center(child: ExpressiveLoader());
      case SquadStatus.noSquad:
        return const _NoSquadView();
      case SquadStatus.error:
        return _SquadErrorView(
          message: state.errorMessage ?? 'Something went wrong.',
        );
      case SquadStatus.loaded:
        return _SquadLoadedView(state: state);
    }
  }
}

class _NoSquadView extends StatelessWidget {
  const _NoSquadView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExpressiveFlower(
              size: 84,
              color: scheme.secondaryContainer,
              child: Icon(
                Icons.groups,
                size: 36,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "You're not in a squad yet",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Create one to invite friends, or join with an invite code.',
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () => _showCreateSquadDialog(context),
                child: const Text('Create a squad'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () => _showJoinSquadDialog(context),
                child: const Text('Join with invite code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCreateSquadDialog(BuildContext context) async {
  final cubit = context.read<SquadCubit>();
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Create a squad'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Squad name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (name != null && name.isNotEmpty) {
    await cubit.createSquad(name);
  }
}

Future<void> _showJoinSquadDialog(BuildContext context) async {
  final cubit = context.read<SquadCubit>();
  final controller = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Join a squad'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'Invite code'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Join'),
        ),
      ],
    ),
  );
  if (code != null && code.isNotEmpty) {
    await cubit.joinSquad(code);
  }
}

class _SquadErrorView extends StatelessWidget {
  const _SquadErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _showCreateSquadDialog(context),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquadLoadedView extends StatelessWidget {
  const _SquadLoadedView({required this.state});

  final SquadState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final squad = state.squad!;
    final live = state.presence.where((m) => m.activity != null).toList();

    // A squad with one member and no live activity left ~65% of the screen
    // blank below the invite-code card — found in design critique. Same
    // fix as AlarmListPage: center the block vertically when it's short,
    // but this still scrolls normally once there's enough content.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InviteCodeCard(inviteCode: squad.inviteCode),
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
                                          m.displayName.isEmpty
                                              ? '?'
                                              : m.displayName[0].toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: scheme.onTertiaryContainer,
                                          ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                        return _LeaderboardRow(
                          row: row,
                          index: i,
                          count: state.leaderboard.length,
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
                      onPressed: () => context.read<SquadCubit>().leaveSquad(),
                      child: const Text('Leave squad'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite code',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  inviteCode,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 2,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: Icon(Icons.copy, color: scheme.onPrimaryContainer),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteCode));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.row,
    required this.index,
    required this.count,
  });

  final LeaderboardEntry row;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = row.isYou
        ? BorderRadius.circular(999)
        : groupedItemRadius(index: index, count: count, outer: 20);
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
                  Text(
                    row.displayName,
                    style: TextStyle(fontWeight: FontWeight.bold, color: fg),
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
            if (!row.isYou) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Report member',
                icon: Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: fg.withValues(alpha: 0.6),
                ),
                onPressed: () => _showReportMemberDialog(
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

Future<void> _showReportMemberDialog(
  BuildContext context, {
  required String userId,
  required String displayName,
}) async {
  final cubit = context.read<SquadCubit>();
  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Report $displayName'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'What happened?'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Submit report'),
        ),
      ],
    ),
  );
  if (reason == null || reason.isEmpty) return;

  try {
    await cubit.reportMember(reportedUserId: userId, reason: reason);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
