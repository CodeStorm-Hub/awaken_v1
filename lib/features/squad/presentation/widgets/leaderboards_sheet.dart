import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/expressive_widgets.dart';
import '../../../../core/theme/shape_tokens.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/usecases/get_global_leaderboard.dart';
import '../../domain/usecases/get_my_leaderboard_rank.dart';
import '../../domain/usecases/get_nearby_leaderboard.dart';
import '../squad_error_message.dart';
import 'leaderboard_row.dart';
import 'squad_page_shared.dart';

enum _LeaderboardScope { nearby, global }

/// `p_time_window` values the leaderboard RPCs accept, in display order.
enum _TimeWindow {
  daily('daily', 'Daily'),
  weekly('weekly', 'Weekly'),
  allTime('all_time', 'All-time');

  const _TimeWindow(this.rpcValue, this.label);

  final String rpcValue;
  final String label;
}

/// Nearby/global leaderboard scope + daily/weekly/all-time time window
/// (refined territory plan item 4; daily added per the 2026-07-29 UI/UX
/// audit) — deliberately separate from the squad-scoped leaderboard above
/// (`SquadCubit.watchLeaderboard`'s live-polled stream), which needs neither
/// a scope nor window picker and works whether or not this sheet is ever
/// opened. One-shot fetches, refetched on scope/window change rather than
/// polled — a leaderboard spanning "everyone nearby" or "everyone" doesn't
/// need the same live-during-a-run freshness a squad's own handful of
/// members does.
///
/// Pagination: the underlying RPCs (`nearby_leaderboard`/`global_leaderboard`)
/// now take a `p_offset` param, so "load more" on scroll-near-bottom fetches
/// the NEXT page at `offset: currentItems.length` with a fixed page size and
/// appends the result — a true cursor, not a re-fetch-with-larger-limit.
class LeaderboardsSheet extends StatefulWidget {
  const LeaderboardsSheet({super.key});

  @override
  State<LeaderboardsSheet> createState() => LeaderboardsSheetState();
}

class LeaderboardsSheetState extends State<LeaderboardsSheet> {
  static const _nearbyRadiusM = 5000.0;
  static const _pageSize = 50;

  var _scope = _LeaderboardScope.nearby;
  var _timeWindow = _TimeWindow.weekly;
  var _loading = true;
  var _loadingMore = false;
  String? _error;
  List<LeaderboardEntry> _entries = const [];

  /// True once a page returns fewer than [_pageSize] rows — no point
  /// requesting yet another page after that.
  var _hasMore = true;

  int? _myRank;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_load());
    unawaited(_loadMyRank());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading || _loadingMore || !_hasMore) return;
    // "Near bottom" — within 200px of the end, so the next page has time to
    // arrive before the user actually reaches it.
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      unawaited(_loadMore());
    }
  }

  Future<List<LeaderboardEntry>> _fetch({required int offset}) {
    return _scope == _LeaderboardScope.nearby
        ? getIt<GetNearbyLeaderboard>()(
            GetNearbyLeaderboardParams(
              radiusM: _nearbyRadiusM,
              timeWindow: _timeWindow.rpcValue,
              rowLimit: _pageSize,
              offset: offset,
            ),
          )
        : getIt<GetGlobalLeaderboard>()(
            timeWindow: _timeWindow.rpcValue,
            rowLimit: _pageSize,
            offset: offset,
          );
  }

  /// Resets to the first page — called on initial load and on scope/window
  /// change.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final entries = await _fetch(offset: 0);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _hasMore = entries.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlySquadErrorMessage(e);
        _loading = false;
      });
    }
  }

  /// Fetches the NEXT page at `offset: _entries.length` and appends it —
  /// a real cursor now that the RPCs take `p_offset`, rather than the old
  /// approach of refetching the whole list from offset 0 with a larger
  /// limit. A page returning fewer than [_pageSize] rows means there's no
  /// more data.
  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = await _fetch(offset: _entries.length);
      if (!mounted) return;
      setState(() {
        _entries = [..._entries, ...nextPage];
        _loadingMore = false;
        _hasMore = nextPage.length >= _pageSize;
      });
    } catch (_) {
      // Best-effort — keep whatever page is already showing rather than
      // surfacing a full-sheet error for a failed "load more" tick.
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  /// Independent targeted query for the pinned "You: #N" row — deliberately
  /// not derived from `_entries`, which is only ever a prefix of the full
  /// leaderboard once pagination is involved.
  Future<void> _loadMyRank() async {
    try {
      final rank = await getIt<GetMyLeaderboardRank>()(
        nearby: _scope == _LeaderboardScope.nearby,
        timeWindow: _timeWindow.rpcValue,
        radiusM: _nearbyRadiusM,
      );
      if (!mounted) return;
      setState(() => _myRank = rank);
    } catch (_) {
      if (!mounted) return;
      setState(() => _myRank = null);
    }
  }

  void _onScopeChanged(_LeaderboardScope scope) {
    setState(() => _scope = scope);
    unawaited(_load());
    unawaited(_loadMyRank());
  }

  void _onTimeWindowChanged(_TimeWindow window) {
    setState(() => _timeWindow = window);
    unawaited(_load());
    unawaited(_loadMyRank());
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
                  borderRadius: ShapeTokens.pill,
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
                    onSelectionChanged: (selected) =>
                        _onScopeChanged(selected.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<_TimeWindow>(
                    segments: [
                      for (final window in _TimeWindow.values)
                        ButtonSegment(value: window, label: Text(window.label)),
                    ],
                    selected: {_timeWindow},
                    onSelectionChanged: (selected) =>
                        _onTimeWindowChanged(selected.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Sticky "you" row — an independent targeted query (`_myRank`),
            // not scanned from `_entries`, so it stays correct regardless of
            // how many pages have been loaded or whether the user's own row
            // happens to be on the currently-fetched page at all.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: ShapeTokens.r12,
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person_pin_circle,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _myRank == null ? 'You: unranked' : 'You: #$_myRank',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
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
                      controller: _scrollController,
                      itemCount: _entries.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i >= _entries.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        return LeaderboardRow(
                          row: _entries[i],
                          index: i,
                          count: _entries.length,
                          isTied: isLeaderboardRowTied(_entries, i),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
