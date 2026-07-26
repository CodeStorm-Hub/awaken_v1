import 'package:flutter/material.dart';

import '../../../../core/theme/expressive_widgets.dart';
import '../../../alarm/presentation/pages/alarm_list_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../squad/presentation/pages/squad_page.dart';
import '../../../territory/presentation/pages/territory_page.dart';

/// iOS adaptive navigation shell — iOS Cupertino TabBar styling on compact
/// windows (<600dp), `NavigationRail` at the medium-window-size-class
/// breakpoint (600dp) and above (foldables/tablets). Destinations match:
/// Home, Alarms, Territory, Squad.
class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  var _index = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.alarm_outlined),
      selectedIcon: Icon(Icons.alarm),
      label: 'Alarms',
    ),
    NavigationDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: 'Territory',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_outlined),
      selectedIcon: Icon(Icons.groups),
      label: 'Squad',
    ),
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

/// The shell's adaptive chrome (breakpoint switch + nav widgets).
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
    final isMediumOrWider =
        MediaQuery.sizeOf(context).width >= mediumWindowBreakpoint;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (isMediumOrWider) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: AppleGlassContainer(
            blurAmount: 25,
            borderRadius: BorderRadius.circular(28),
            padding: EdgeInsets.zero,
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: scheme.primary.withValues(alpha: 0.15),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    );
                  }
                  return const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8E8E93),
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: scheme.primary, size: 22);
                  }
                  return const IconThemeData(color: Color(0xFF8E8E93), size: 22);
                }),
              ),
              child: NavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                destinations: destinations,
                elevation: 0,
                height: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
