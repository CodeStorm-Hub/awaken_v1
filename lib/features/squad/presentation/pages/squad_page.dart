import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../bloc/squad_cubit.dart';
import '../widgets/squad_view.dart';
import '../widgets/weekly_reset_ceremony_gate.dart';

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
      child: const WeeklyResetCeremonyGate(child: SquadView()),
    );
  }
}
