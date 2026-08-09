import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../data/datasources/weekly_reset_local_datasource.dart';
import '../../domain/usecases/get_my_leaderboard_rank.dart';
import '../../domain/usecases/get_my_squad_rank.dart';
import '../bloc/squad_cubit.dart';
import 'weekly_recap_sheet.dart';

/// One-time weekly-leaderboard-reset ceremony (2026-07-29 UI/UX audit item
/// 11) — wraps the whole page so it can run its check exactly once per
/// `SquadPage` mount (the shell's `IndexedStack` keeps this tab's `State`
/// alive across tab switches, so "once per mount" already means "once per
/// app session" in practice) without disturbing `SquadView`'s own
/// `BlocBuilder` rebuilds. When the caller is currently in a squad (read off
/// `SquadCubit`'s state, already provided above this widget in the tree),
/// uses the squad-scoped weekly rank (`my_squad_rank` via [GetMySquadRank])
/// instead of the global one, falling back to the global weekly rank
/// (`my_global_rank` via [GetMyLeaderboardRank]) when the caller has no
/// squad.
class WeeklyResetCeremonyGate extends StatefulWidget {
  const WeeklyResetCeremonyGate({super.key, required this.child});

  final Widget child;

  @override
  State<WeeklyResetCeremonyGate> createState() =>
      WeeklyResetCeremonyGateState();
}

class WeeklyResetCeremonyGateState extends State<WeeklyResetCeremonyGate> {
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
      // `BlocProvider<SquadCubit>` as `SquadView`.
      final squadId = mounted
          ? context.read<SquadCubit>().state.squad?.id
          : null;
      final currentRank = squadId != null
          ? await getIt<GetMySquadRank>()(
              squadId: squadId,
              timeWindow: 'weekly',
            )
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
