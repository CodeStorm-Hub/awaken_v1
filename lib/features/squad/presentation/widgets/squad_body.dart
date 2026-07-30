import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../bloc/squad_cubit.dart';
import '../bloc/squad_state.dart';
import 'no_squad_view.dart';
import 'squad_error_view.dart';
import 'squad_loaded_view.dart';

class SquadBody extends StatelessWidget {
  const SquadBody({super.key, required this.state});

  final SquadState state;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case SquadStatus.loading:
        return const Center(child: ExpressiveLoader());
      case SquadStatus.noSquad:
        return const NoSquadView();
      case SquadStatus.error:
        return SquadErrorView(
          message: state.errorMessage ?? 'Something went wrong.',
          onRetry: () => context.read<SquadCubit>().retry(),
        );
      case SquadStatus.loaded:
        return SquadLoadedView(state: state);
    }
  }
}
