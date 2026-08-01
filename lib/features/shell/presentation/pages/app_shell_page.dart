import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../sync/outbox/sync_worker.dart';
import '../../../../sync/sync_status.dart';
import '../../../alarm/presentation/pages/alarm_list_page.dart';
import '../../../home/presentation/pages/home_page.dart';
import '../../../profile/presentation/widgets/auth_dialog.dart';
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

  // Separate from `_index` deliberately: `_pages` below is a `late final`
  // list built once in `initState` (see its own doc comment for why), so a
  // plain constructor argument computed from `_index` would freeze at
  // whatever `_index` was at that one moment. A `ValueNotifier` is a stable
  // object identity `TerritoryPage` can listen to directly, letting it react
  // to live tab-visibility changes without the page list itself ever
  // needing to rebuild. Powers `TerritoryPage`'s native MapLibre view being
  // paused (not built at all) while its tab isn't the active one — that
  // view's own render thread otherwise keeps compositing in the background
  // indefinitely once created, regardless of which tab IndexedStack is
  // showing (confirmed live via DevTools: continuous ~20fps frame
  // production and Raster-thread-bound jank even sitting idle on Home).
  final _isTerritoryTabActive = ValueNotifier<bool>(false);

  static const _territoryTabIndex = 2;

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

  void _goTo(int index) {
    if (index == _territoryTabIndex || index == 3) {
      final user = Supabase.instance.client.auth.currentUser;
      final isGuest = user == null || user.isAnonymous;
      if (isGuest) {
        showDialog<void>(
          context: context,
          builder: (_) => const AuthDialog(mode: AuthDialogMode.link),
        );
        return;
      }
    }
    setState(() => _index = index);
    _isTerritoryTabActive.value = index == _territoryTabIndex;
  }

  @override
  void dispose() {
    _isTerritoryTabActive.dispose();
    super.dispose();
  }

  // Previously constructed inline in `build()`, on every shell rebuild
  // (e.g. every `_goTo` tab switch) — that handed `IndexedStack` a brand
  // new `Widget` instance for every page each time, so it couldn't tell the
  // subtrees were "the same" page across rebuilds and reconstructed all
  // four (including their `State`) instead of just switching which one is
  // visible. Building once in `initState` and keeping the list in a
  // `late final` field lets `IndexedStack` preserve each tab's state
  // (scroll position, in-flight animations, etc.) across tab switches.
  late final List<Widget> _pages = [
    HomePage(
      onOpenAlarms: () => _goTo(1),
      onOpenTerritory: () => _goTo(2),
      onOpenSquad: () => _goTo(3),
    ),
    const AlarmListPage(),
    TerritoryPage(isActive: _isTerritoryTabActive),
    const SquadPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveNavScaffold(
      selectedIndex: _index,
      onDestinationSelected: _goTo,
      destinations: _destinations,
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _pages),
          const Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: RepaintBoundary(
                child: _ShellSyncBadge(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small, non-intrusive sync/offline indicator for the shell chrome —
/// previously `SyncWorker.status` had no consumer anywhere reachable from
/// every tab, so a stuck outbox drain (pending writes not reaching the
/// server) or a plain offline state was invisible unless the user happened
/// to be on `TerritoryPage` (which has its own, more verbose banner). Only
/// renders when there's something worth flagging — hidden entirely on
/// `SyncStatus.idle` (nothing pending, already synced).
class _ShellSyncBadge extends StatelessWidget {
  const _ShellSyncBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<SyncStatus>(
      stream: getIt<SyncWorker>().status,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null || status == SyncStatus.idle) {
          return const SizedBox.shrink();
        }

        final (icon, bg, fg) = switch (status) {
          SyncStatus.syncing => (
            Icons.sync,
            scheme.surfaceContainerHigh,
            scheme.onSurfaceVariant,
          ),
          SyncStatus.offline => (
            Icons.cloud_off,
            scheme.surfaceContainerHigh,
            scheme.onSurfaceVariant,
          ),
          SyncStatus.error => (
            Icons.sync_problem,
            scheme.errorContainer,
            scheme.onErrorContainer,
          ),
          SyncStatus.idle => (
            Icons.cloud_done,
            scheme.surface,
            scheme.onSurface,
          ),
        };

        return Padding(
          padding: const EdgeInsets.only(top: 8, right: 12),
          child: Tooltip(
            message: switch (status) {
              SyncStatus.syncing => 'Syncing…',
              SyncStatus.offline =>
                "Offline — will sync when you're back online",
              SyncStatus.error => "Couldn't sync some changes",
              SyncStatus.idle => '',
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: status == SyncStatus.syncing
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Icon(icon, size: 16, color: fg),
            ),
          ),
        );
      },
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
                  return TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: secondaryLabelColor(context),
                  );
                }),
                iconTheme: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return IconThemeData(color: scheme.primary, size: 22);
                  }
                  return IconThemeData(
                    color: secondaryLabelColor(context),
                    size: 22,
                  );
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
