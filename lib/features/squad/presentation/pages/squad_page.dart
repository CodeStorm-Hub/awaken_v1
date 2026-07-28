import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../profile/presentation/widgets/current_user_avatar_button.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/usecases/get_global_leaderboard.dart';
import '../../domain/usecases/get_nearby_leaderboard.dart';
import '../bloc/squad_cubit.dart';
import '../bloc/squad_state.dart';
import '../squad_error_message.dart';

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
        ? BorderRadius.circular(14)
        : groupedItemRadius(index: index, count: count, outer: 14);
    final bg = row.isYou
        ? scheme.primary.withValues(alpha: 0.18)
        : scheme.surfaceContainer;
    final fg = row.isYou ? scheme.primary : scheme.onSurface;
    final rankBg = row.rank == 1
        ? const Color(0xFFFF9F0A).withValues(alpha: 0.2)
        : row.isYou
        ? scheme.primary.withValues(alpha: 0.25)
        : scheme.surfaceContainerHigh;
    final rankFg = row.rank == 1
        ? const Color(0xFFFF9F0A)
        : row.isYou
        ? scheme.primary
        : secondaryLabelColor(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(
            color: row.isYou
                ? scheme.primary.withValues(alpha: 0.4)
                : scheme.outline,
            width: row.isYou ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label:
                    'Rank ${row.rank}, ${row.displayName}'
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
                                '${row.rank}',
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
                      _MemberAvatar(
                        displayName: row.displayName,
                        avatarUrl: row.avatarUrl,
                        size: 32,
                        borderRadius: BorderRadius.circular(16),
                        background: scheme.tertiaryContainer,
                        foreground: scheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.displayName,
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

/// Nearby/global leaderboard scope + all-time/weekly time window (refined
/// territory plan item 4) — deliberately separate from the squad-scoped
/// leaderboard above (`SquadCubit.watchLeaderboard`'s live-polled stream),
/// which needs neither a scope nor window picker and works whether or not
/// this sheet is ever opened. One-shot fetches, refetched on scope/window
/// change rather than polled — a leaderboard spanning "everyone nearby" or
/// "everyone" doesn't need the same live-during-a-run freshness a squad's
/// own handful of members does.
class _LeaderboardsSheet extends StatefulWidget {
  const _LeaderboardsSheet();

  @override
  State<_LeaderboardsSheet> createState() => _LeaderboardsSheetState();
}

class _LeaderboardsSheetState extends State<_LeaderboardsSheet> {
  static const _nearbyRadiusM = 5000.0;

  var _scope = _LeaderboardScope.nearby;
  var _weekly = false;
  var _loading = true;
  String? _error;
  List<LeaderboardEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = _scope == _LeaderboardScope.nearby
          ? await getIt<GetNearbyLeaderboard>()(
              GetNearbyLeaderboardParams(
                radiusM: _nearbyRadiusM,
                weekly: _weekly,
              ),
            )
          : await getIt<GetGlobalLeaderboard>()(weekly: _weekly);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlySquadErrorMessage(e);
        _loading = false;
      });
    }
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
                    onSelectionChanged: (selected) {
                      setState(() => _scope = selected.first);
                      unawaited(_load());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('All-time')),
                      ButtonSegment(value: true, label: Text('Weekly')),
                    ],
                    selected: {_weekly},
                    onSelectionChanged: (selected) {
                      setState(() => _weekly = selected.first);
                      unawaited(_load());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
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
                      itemCount: _entries.length,
                      itemBuilder: (context, i) => _LeaderboardRow(
                        row: _entries[i],
                        index: i,
                        count: _entries.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
