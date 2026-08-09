import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/adaptive_dialog.dart';
import '../bloc/squad_cubit.dart';
import '../squad_error_message.dart';
import '../../domain/entities/leaderboard_entry.dart';
import 'text_prompt_dialog.dart';

/// Shared helpers used by several extracted squad widgets — dialog
/// launchers and small pure helpers that don't belong to any single widget.
/// Split out of `squad_page.dart` (2026-07-31 god-file cleanup) so the
/// individual widget files below don't need to depend on each other for
/// these.
Future<void> showCreateSquadDialog(BuildContext context) async {
  final cubit = context.read<SquadCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final created = await showDialog<bool>(
    context: context,
    builder: (_) => TextPromptDialog(
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

Future<void> showJoinSquadDialog(BuildContext context) async {
  final cubit = context.read<SquadCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final joined = await showDialog<bool>(
    context: context,
    builder: (_) => TextPromptDialog(
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

Future<void> confirmLeaveSquad(BuildContext context) async {
  final cubit = context.read<SquadCubit>();
  final confirmed = await showAdaptiveConfirmDialog(
    context: context,
    title: 'Leave squad?',
    message: "You'll need the invite code to rejoin later.",
    confirmLabel: 'Leave',
  );
  if (!confirmed) return;

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

Future<void> showReportMemberDialog(
  BuildContext context, {
  required String userId,
  required String displayName,
}) async {
  final cubit = context.read<SquadCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final reported = await showDialog<bool>(
    context: context,
    builder: (_) => TextPromptDialog(
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
