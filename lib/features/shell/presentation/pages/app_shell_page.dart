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
  static const _mediumWindowBreakpoint = 600.0;

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
    final body = IndexedStack(index: _index, children: pages);
    final isMediumOrWider = MediaQuery.sizeOf(context).width >= _mediumWindowBreakpoint;

    if (isMediumOrWider) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _goTo,
              labelType: NavigationRailLabelType.all,
              destinations: _destinations
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
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: _destinations,
      ),
    );
  }
}
