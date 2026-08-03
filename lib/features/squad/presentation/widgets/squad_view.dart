import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../profile/presentation/widgets/current_user_avatar_button.dart';
import '../bloc/squad_cubit.dart';
import '../bloc/squad_state.dart';
import 'leaderboards_sheet.dart';
import 'squad_body.dart';

class SquadView extends StatelessWidget {
  const SquadView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        // Split from the body's own `BlocBuilder` below: `SquadState.presence`
        // updates as often as every ~3s per live squadmate
        // (`SquadCubit`'s throttled presence stream), but the header only
        // reads `state.squad`. Without this `buildWhen`, every presence tick
        // repainted this `AppleGlassContainer`'s `BackdropFilter` blur along
        // with the rest of the page — one of the most expensive widgets in
        // Flutter — for a header that hadn't actually changed.
        child: BlocBuilder<SquadCubit, SquadState>(
          buildWhen: (previous, current) => previous.squad != current.squad,
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
                                    builder: (_) => const LeaderboardsSheet(),
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
                // Re-subscribed independently of the header above so
                // presence/leaderboard/status updates only rebuild the body
                // (no `BackdropFilter` inside it), not the header's blur.
                Expanded(
                  child: BlocBuilder<SquadCubit, SquadState>(
                    builder: (context, bodyState) =>
                        SquadBody(state: bodyState),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
