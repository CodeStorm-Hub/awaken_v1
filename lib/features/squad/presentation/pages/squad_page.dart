import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/gamification_widgets.dart';
import '../../../../core/theme/motion_tokens.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/theme/shape_tokens.dart';
import '../../../profile/presentation/widgets/current_user_avatar_button.dart';
import '../../../territory/presentation/pages/territory_page.dart';
import '../../data/datasources/weekly_reset_local_datasource.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/territory_capture_feed_item.dart';
import '../../domain/usecases/get_global_leaderboard.dart';
import '../../domain/usecases/get_my_leaderboard_rank.dart';
import '../../domain/usecases/get_my_squad_rank.dart';
import '../../domain/usecases/get_nearby_leaderboard.dart';
import '../../domain/usecases/get_recent_territory_captures.dart';
import '../bloc/squad_cubit.dart';
import '../bloc/squad_state.dart';
import '../squad_error_message.dart';
import '../widgets/weekly_recap_sheet.dart';

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
      child: const _WeeklyResetCeremonyGate(child: _SquadView()),
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
                            Text(
                              'Squad',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              state.squad == null
                                  ? 'Not in a squad yet'
                                  // `leaderboard` only lists members who've
                                  // captured territory — a squad whose other
                                  // members haven't yet would misreport "0
                                  // members" while the user is standing in
                                  // one. Drop the count entirely rather than
                                  // show a number known to undercount.
                                  : state.squad!.name,
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryLabelColor(context),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Tooltip(
                              message: 'Leaderboards',
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => showModalBottomSheet<void>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: scheme.surfaceContainerLow,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    builder: (_) => const _LeaderboardsSheet(),
                                  ),
                                  // Was 36x36 — below WCAG 2.5.5's 44x44
                                  // minimum; icon stays the same visual
                                  // size.
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Icon(
                                      Icons.leaderboard,
                                      size: 18,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const CurrentUserAvatarButton(),
                          ],
                        ),
                      ],
                    ),
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
          onRetry: () => context.read<SquadCubit>().retry(),
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
              // See `alarm_list_page.dart`'s identical fix — light theme's
              // `secondaryContainer` is nearly invisible against the page
              // surface without a border.
              borderColor: scheme.outline,
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
            const SizedBox(height: 20),
            const _ConquestTicker(),
            const SizedBox(height: 4),
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
            const SizedBox(height: 20),
            // No squad yet still leaves "capture territory to appear on a
            // leaderboard" reachable — previously only the loaded-and-empty
            // squad leaderboard (below) carried this hint, so a brand new
            // user had no path from here to Territory at all.
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TerritoryPage()),
              ),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Capture territory to start earning a rank'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showCreateSquadDialog(BuildContext context) async {
  final cubit = context.read<SquadCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: 'Create a squad',
      hintText: 'Squad name',
      submitLabel: 'Create',
      textCapitalization: TextCapitalization.words,
      onSubmit: cubit.createSquad,
    ),
  );
  if (created == true) {
    // Squad join/create previously only got a SnackBar, while territory
    // capture gives a haptic — this brings squad creation up to the same
    // celebratory feedback bar (2026-07-29 UI/UX audit item 8).
    unawaited(HapticFeedback.mediumImpact());
    messenger.showSnackBar(const SnackBar(content: Text('Squad created.')));
  }
}

Future<void> _showJoinSquadDialog(BuildContext context) async {
  final cubit = context.read<SquadCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final joined = await showDialog<bool>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: 'Join a squad',
      hintText: 'Invite code',
      submitLabel: 'Join',
      textCapitalization: TextCapitalization.characters,
      onSubmit: cubit.joinSquad,
    ),
  );
  if (joined == true) {
    unawaited(HapticFeedback.mediumImpact());
    messenger.showSnackBar(const SnackBar(content: Text('Joined squad.')));
  }
}

/// Reserved for a genuine failure of the underlying squad stream (see
/// `SquadCubit._subscribeToMySquad`'s doc comment) — a failed create/join no
/// longer routes here, so both real recovery paths stay available instead of
/// only the one the user happened not to be using.
class _SquadErrorView extends StatelessWidget {
  const _SquadErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  onPressed: () => _showCreateSquadDialog(context),
                  child: const Text('Create a squad'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _showJoinSquadDialog(context),
                  child: const Text('Join with code'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared dialog shape for create-squad/join-squad/report-member — a
/// disposed `TextEditingController`, a submit lock so a failed or slow
/// network call can't be double-fired, inline validation, and an inline
/// error message on failure instead of the dialog vanishing with only a
/// SnackBar (or, previously for create/join, the whole page falling back to
/// a generic error screen — see `_SquadErrorView`'s doc comment).
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.hintText,
    required this.submitLabel,
    required this.onSubmit,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  final String title;
  final String hintText;
  final String submitLabel;
  final Future<void> Function(String value) onSubmit;
  final TextCapitalization textCapitalization;
  final int maxLines;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  final _controller = TextEditingController();
  var _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'This field is required.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(value);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = friendlySquadErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_submitting,
            maxLines: widget.maxLines,
            textCapitalization: widget.textCapitalization,
            decoration: InputDecoration(hintText: widget.hintText),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel),
        ),
      ],
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
            _InviteCodeCard(inviteCode: squad.inviteCode),
            const SizedBox(height: 14),
            const _ConquestTicker(),
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
                                  _MemberAvatar(
                                    displayName: m.displayName,
                                    avatarUrl: m.avatarUrl,
                                    size: 44,
                                    borderRadius: BorderRadius.circular(16),
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
                  return _LeaderboardRow(
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
                    : () => _confirmLeaveSquad(context),
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

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({required this.inviteCode});

  final String inviteCode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppleGlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Icon(Icons.qr_code, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite code',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryLabelColor(context),
                  ),
                ),
                Text(
                  inviteCode,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 2,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: Icon(Icons.copy, color: scheme.primary),
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

/// True when [entries]`[index]` shares its rank with an adjacent entry —
/// `LeaderboardEntry.rank` uses standard "competition ranking" (equal-area
/// neighbors share a rank number) as of the 2026-07-29 UI/UX audit, so a
/// shared rank is detected by comparing neighbors rather than re-deriving it
/// from `areaSqm`.
bool isLeaderboardRowTied(List<LeaderboardEntry> entries, int index) {
  final tiedWithPrev =
      index > 0 && entries[index - 1].rank == entries[index].rank;
  final tiedWithNext =
      index < entries.length - 1 &&
      entries[index + 1].rank == entries[index].rank;
  return tiedWithPrev || tiedWithNext;
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
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
        ? BorderRadius.circular(14)
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
                        child: _MemberAvatar(
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

/// Real avatar image with a graceful initials fallback — shared by the
/// "Live now" cards and leaderboard rows so both a member's own photo (when
/// `profiles.avatar_url` has one) and the no-photo case render identically.
/// Same `cacheWidth`/`cacheHeight`/`errorBuilder`/`loadingBuilder` shape as
/// `ProfileAvatarButton` (`core/theme/expressive_widgets.dart`).
class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.displayName,
    required this.avatarUrl,
    required this.size,
    required this.borderRadius,
    required this.background,
    required this.foreground,
  });

  final String displayName;
  final String? avatarUrl;
  final double size;
  final BorderRadius borderRadius;
  final Color background;
  final Color foreground;

  Widget _initials() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: borderRadius),
      child: Center(
        child: Text(
          displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold, color: foreground),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl;
    if (url == null || url.isEmpty) return _initials();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * dpr).round(),
        cacheHeight: (size * dpr).round(),
        errorBuilder: (context, error, stackTrace) => _initials(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _initials(),
      ),
    );
  }
}

Future<void> _confirmLeaveSquad(BuildContext context) async {
  final cubit = context.read<SquadCubit>();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Leave squad?'),
      content: const Text("You'll need the invite code to rejoin later."),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Leave'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await cubit.leaveSquad();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlySquadErrorMessage(e))));
    }
  }
}

Future<void> _showReportMemberDialog(
  BuildContext context, {
  required String userId,
  required String displayName,
}) async {
  final cubit = context.read<SquadCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final reported = await showDialog<bool>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: 'Report $displayName',
      hintText: 'What happened?',
      submitLabel: 'Submit report',
      maxLines: 3,
      onSubmit: (reason) =>
          cubit.reportMember(reportedUserId: userId, reason: reason),
    ),
  );
  if (reported == true) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Report submitted. Thank you.')),
    );
  }
}

enum _LeaderboardScope { nearby, global }

/// `p_time_window` values the leaderboard RPCs accept, in display order.
enum _TimeWindow {
  daily('daily', 'Daily'),
  weekly('weekly', 'Weekly'),
  allTime('all_time', 'All-time');

  const _TimeWindow(this.rpcValue, this.label);

  final String rpcValue;
  final String label;
}

/// Nearby/global leaderboard scope + daily/weekly/all-time time window
/// (refined territory plan item 4; daily added per the 2026-07-29 UI/UX
/// audit) — deliberately separate from the squad-scoped leaderboard above
/// (`SquadCubit.watchLeaderboard`'s live-polled stream), which needs neither
/// a scope nor window picker and works whether or not this sheet is ever
/// opened. One-shot fetches, refetched on scope/window change rather than
/// polled — a leaderboard spanning "everyone nearby" or "everyone" doesn't
/// need the same live-during-a-run freshness a squad's own handful of
/// members does.
///
/// Pagination: the underlying RPCs (`nearby_leaderboard`/`global_leaderboard`)
/// now take a `p_offset` param, so "load more" on scroll-near-bottom fetches
/// the NEXT page at `offset: currentItems.length` with a fixed page size and
/// appends the result — a true cursor, not a re-fetch-with-larger-limit.
class _LeaderboardsSheet extends StatefulWidget {
  const _LeaderboardsSheet();

  @override
  State<_LeaderboardsSheet> createState() => _LeaderboardsSheetState();
}

class _LeaderboardsSheetState extends State<_LeaderboardsSheet> {
  static const _nearbyRadiusM = 5000.0;
  static const _pageSize = 50;

  var _scope = _LeaderboardScope.nearby;
  var _timeWindow = _TimeWindow.weekly;
  var _loading = true;
  var _loadingMore = false;
  String? _error;
  List<LeaderboardEntry> _entries = const [];

  /// True once a page returns fewer than [_pageSize] rows — no point
  /// requesting yet another page after that.
  var _hasMore = true;

  int? _myRank;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_load());
    unawaited(_loadMyRank());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    // "Near bottom" — within 200px of the end, so the next page has time to
    // arrive before the user actually reaches it.
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      unawaited(_loadMore());
    }
  }

  Future<List<LeaderboardEntry>> _fetch({required int offset}) {
    return _scope == _LeaderboardScope.nearby
        ? getIt<GetNearbyLeaderboard>()(
            GetNearbyLeaderboardParams(
              radiusM: _nearbyRadiusM,
              timeWindow: _timeWindow.rpcValue,
              rowLimit: _pageSize,
              offset: offset,
            ),
          )
        : getIt<GetGlobalLeaderboard>()(
            timeWindow: _timeWindow.rpcValue,
            rowLimit: _pageSize,
            offset: offset,
          );
  }

  /// Resets to the first page — called on initial load and on scope/window
  /// change.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final entries = await _fetch(offset: 0);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _hasMore = entries.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlySquadErrorMessage(e);
        _loading = false;
      });
    }
  }

  /// Fetches the NEXT page at `offset: _entries.length` and appends it —
  /// a real cursor now that the RPCs take `p_offset`, rather than the old
  /// approach of refetching the whole list from offset 0 with a larger
  /// limit. A page returning fewer than [_pageSize] rows means there's no
  /// more data.
  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = await _fetch(offset: _entries.length);
      if (!mounted) return;
      setState(() {
        _entries = [..._entries, ...nextPage];
        _loadingMore = false;
        _hasMore = nextPage.length >= _pageSize;
      });
    } catch (_) {
      // Best-effort — keep whatever page is already showing rather than
      // surfacing a full-sheet error for a failed "load more" tick.
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  /// Independent targeted query for the pinned "You: #N" row — deliberately
  /// not derived from `_entries`, which is only ever a prefix of the full
  /// leaderboard once pagination is involved.
  Future<void> _loadMyRank() async {
    try {
      final rank = await getIt<GetMyLeaderboardRank>()(
        nearby: _scope == _LeaderboardScope.nearby,
        timeWindow: _timeWindow.rpcValue,
        radiusM: _nearbyRadiusM,
      );
      if (!mounted) return;
      setState(() => _myRank = rank);
    } catch (_) {
      if (!mounted) return;
      setState(() => _myRank = null);
    }
  }

  void _onScopeChanged(_LeaderboardScope scope) {
    setState(() => _scope = scope);
    unawaited(_load());
    unawaited(_loadMyRank());
  }

  void _onTimeWindowChanged(_TimeWindow window) {
    setState(() => _timeWindow = window);
    unawaited(_load());
    unawaited(_loadMyRank());
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              'Leaderboards',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<_LeaderboardScope>(
                    segments: const [
                      ButtonSegment(
                        value: _LeaderboardScope.nearby,
                        label: Text('Nearby'),
                      ),
                      ButtonSegment(
                        value: _LeaderboardScope.global,
                        label: Text('Global'),
                      ),
                    ],
                    selected: {_scope},
                    onSelectionChanged: (selected) =>
                        _onScopeChanged(selected.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<_TimeWindow>(
                    segments: [
                      for (final window in _TimeWindow.values)
                        ButtonSegment(value: window, label: Text(window.label)),
                    ],
                    selected: {_timeWindow},
                    onSelectionChanged: (selected) =>
                        _onTimeWindowChanged(selected.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Sticky "you" row — an independent targeted query (`_myRank`),
            // not scanned from `_entries`, so it stays correct regardless of
            // how many pages have been loaded or whether the user's own row
            // happens to be on the currently-fetched page at all.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: ShapeTokens.medium,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_pin_circle,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _myRank == null ? 'You: unranked' : 'You: #$_myRank',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: _loading
                  ? const Center(child: ExpressiveLoader())
                  : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.error),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _entries.isEmpty
                  ? Center(
                      child: Text(
                        _scope == _LeaderboardScope.nearby
                            ? "No nearby players yet — complete a run so others can find you."
                            : 'No global activity yet.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _entries.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _entries.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        return _LeaderboardRow(
                          row: _entries[i],
                          index: i,
                          count: _entries.length,
                          isTied: isLeaderboardRowTied(_entries, i),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small live activity feed of recent territory captures — "conquest
/// ticker" (2026-07-29 UI/UX audit item 9). Falls back to a periodic
/// refetch rather than Realtime, since `SquadRemoteDataSource` only opens a
/// per-squad Presence/Broadcast channel and there's no existing public
/// broadcast channel this feed could piggyback on.
class _ConquestTicker extends StatefulWidget {
  const _ConquestTicker();

  @override
  State<_ConquestTicker> createState() => _ConquestTickerState();
}

class _ConquestTickerState extends State<_ConquestTicker> {
  static const _refetchInterval = Duration(seconds: 30);
  static const _rotateInterval = Duration(seconds: 4);

  List<TerritoryCaptureFeedItem> _items = const [];
  var _index = 0;
  Timer? _refetchTimer;
  Timer? _rotateTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refetchTimer = Timer.periodic(_refetchInterval, (_) => unawaited(_load()));
    _rotateTimer = Timer.periodic(_rotateInterval, (_) {
      if (!mounted || _items.length < 2) return;
      setState(() => _index = (_index + 1) % _items.length);
    });
  }

  @override
  void dispose() {
    _refetchTimer?.cancel();
    _rotateTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await getIt<GetRecentTerritoryCaptures>()(rowLimit: 10);
      if (!mounted) return;
      setState(() {
        _items = items;
        if (_index >= items.length) _index = 0;
      });
    } catch (_) {
      // Best-effort — a failed refetch just leaves the last known feed
      // showing (or nothing, before the first successful load).
    }
  }

  String _label(TerritoryCaptureFeedItem item) {
    final areaLabel = item.areaTakenSqm >= 10000
        ? '${(item.areaTakenSqm / 1000000).toStringAsFixed(2)} km²'
        : '${item.areaTakenSqm.round()} m²';
    return item.loserDisplayName == null
        ? '${item.winnerDisplayName} captured $areaLabel of unclaimed ground'
        : '${item.winnerDisplayName} captured $areaLabel from ${item.loserDisplayName}';
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final item = _items[_index.clamp(0, _items.length - 1)];

    return AnimatedSwitcher(
      duration: MotionTokens.defaultSpatial,
      switchInCurve: MotionTokens.effectsCurve,
      switchOutCurve: MotionTokens.effectsCurve,
      child: Container(
        key: ValueKey(item.captureId),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: ShapeTokens.mediumLarge,
        ),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, size: 16, color: scheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _label(item),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-time weekly-leaderboard-reset ceremony (2026-07-29 UI/UX audit item
/// 11) — wraps the whole page so it can run its check exactly once per
/// `SquadPage` mount (the shell's `IndexedStack` keeps this tab's `State`
/// alive across tab switches, so "once per mount" already means "once per
/// app session" in practice) without disturbing `_SquadView`'s own
/// `BlocBuilder` rebuilds. When the caller is currently in a squad (read off
/// `SquadCubit`'s state, already provided above this widget in the tree),
/// uses the squad-scoped weekly rank (`my_squad_rank` via [GetMySquadRank])
/// instead of the global one, falling back to the global weekly rank
/// (`my_global_rank` via [GetMyLeaderboardRank]) when the caller has no
/// squad.
class _WeeklyResetCeremonyGate extends StatefulWidget {
  const _WeeklyResetCeremonyGate({required this.child});

  final Widget child;

  @override
  State<_WeeklyResetCeremonyGate> createState() =>
      _WeeklyResetCeremonyGateState();
}

class _WeeklyResetCeremonyGateState extends State<_WeeklyResetCeremonyGate> {
  var _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowCeremony());
  }

  static String _isoWeekKey(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    // ISO week: the week containing this date's Thursday determines both
    // the week's year and number, so a late-Dec/early-Jan date lands in the
    // correct week even when it crosses a calendar-year boundary.
    final thursday = d.add(Duration(days: 4 - d.weekday));
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    final weekNum =
        ((thursday.difference(firstDayOfYear).inDays) / 7).floor() + 1;
    return '${thursday.year}-W$weekNum';
  }

  Future<void> _maybeShowCeremony() async {
    if (_checked || !mounted) return;
    _checked = true;
    try {
      final store = getIt<WeeklyResetLocalDataSource>();
      final currentWeek = _isoWeekKey(DateTime.now());
      final lastWeek = await store.getLastSeenWeek();
      final lastRank = await store.getLastKnownRank();
      // Read squad membership off the already-provided `SquadCubit` rather
      // than fetching it again — this widget sits inside the same
      // `BlocProvider<SquadCubit>` as `_SquadView`.
      final squadId = mounted ? context.read<SquadCubit>().state.squad?.id : null;
      final currentRank = squadId != null
          ? await getIt<GetMySquadRank>()(squadId: squadId, timeWindow: 'weekly')
          : await getIt<GetMyLeaderboardRank>()(
              nearby: false,
              timeWindow: 'weekly',
            );

      if (lastWeek != null &&
          lastWeek != currentWeek &&
          lastRank != null &&
          currentRank != null &&
          mounted) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => WeeklyRecapSheet(
            currentRank: currentRank,
            previousRank: lastRank,
          ),
        );
      }

      await store.save(isoWeek: currentWeek, rank: currentRank);
    } catch (_) {
      // Best-effort — never blocks the page on a failed rank fetch or a
      // SharedPreferences read/write hiccup.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
