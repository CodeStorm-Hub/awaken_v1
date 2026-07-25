import 'package:flutter/material.dart';

import '../../../alarm/presentation/pages/alarm_list_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../squad/presentation/pages/squad_page.dart';
import '../../../territory/presentation/pages/territory_page.dart';

/// Material 3 adaptive navigation shell — `NavigationBar` on compact
/// windows, `NavigationRail` at the M3 medium-window-size-class breakpoint
/// (600dp) and above (foldables/tablets), per the UI/UX plan's
/// unbuilt "adaptive/multi-pane" direction (see CLAUDE.md). Destinations
/// match the Claude Design handoff's `showBottomNav` set: Home, Alarms,
/// Territory, Squad — Profile is reached via the avatar button on each of
/// those screens, not a nav destination itself.
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  var _index = 0;

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
    NavigationDestination(icon: Icon(Icons.alarm_outlined), selectedIcon: Icon(Icons.alarm), label: 'Alarms'),
    NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Territory'),
    NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Squad'),
  ];

  void _goTo(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onOpenAlarms: () => _goTo(1),
        onOpenTerritory: () => _goTo(2),
        onOpenSquad: () => _goTo(3),
      ),
      const AlarmListPage(),
      const TerritoryPage(),
      const SquadPage(),
    ];
    return AdaptiveNavScaffold(
      selectedIndex: _index,
      onDestinationSelected: _goTo,
      destinations: _destinations,
      body: IndexedStack(index: _index, children: pages),
    );
  }
}

/// The shell's adaptive chrome (breakpoint switch + nav widgets), split out
/// from [AppShellPage] so it's testable without needing every real feature
/// page's own `getIt` dependencies (`HomePage`/`TerritoryPage`/etc. each
/// pull in several use cases and, for `TerritoryPage`, a native
/// `MapLibreMap` platform view — none of which a plain widget test can
/// stand up without heavy mocking). Tests exercise this directly with a
/// trivial `body` instead. Not otherwise meant to be reused — `body` is
/// still the full `IndexedStack` of real pages in production.
@visibleForTesting
class AdaptiveNavScaffold extends StatelessWidget {
  const AdaptiveNavScaffold({
    required this.body,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.mediumWindowBreakpoint = 600.0,
    super.key,
  });

  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final double mediumWindowBreakpoint;

  @override
  Widget build(BuildContext context) {
    final isMediumOrWider = MediaQuery.sizeOf(context).width >= mediumWindowBreakpoint;

    if (isMediumOrWider) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map((d) => NavigationRailDestination(icon: d.icon, selectedIcon: d.selectedIcon, label: Text(d.label)))
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
      ),
    );
  }
}
