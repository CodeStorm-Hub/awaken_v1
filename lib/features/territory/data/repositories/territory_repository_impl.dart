import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../sync/local/database.dart';
import '../../domain/entities/bounty_zone.dart';
import '../../domain/entities/geo_bounds.dart';
import '../../domain/entities/rival.dart';
import '../../domain/entities/territory.dart';
import '../../domain/entities/territory_at_risk.dart';
import '../../domain/repositories/territory_repository.dart';
import '../datasources/territory_remote_datasource.dart';
import '../mappers/territory_mapper.dart';

/// Pull-only cache repository (plan §3 — `territories` is server-authoritative
/// and never written by the client outbox). Writes straight to `AppDatabase`
/// rather than through `LocalWriter`, matching the doc comment on the
/// `Territories` Drift table: this cache intentionally never enqueues a
/// `sync_outbox` entry of its own.
@LazySingleton(as: TerritoryRepository)
class TerritoryRepositoryImpl implements TerritoryRepository {
  TerritoryRepositoryImpl(this._remote, this._db, this._supabase);

  final TerritoryRemoteDataSource _remote;
  final AppDatabase _db;
  final SupabaseClient _supabase;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Cap on total cached rows (plan: "evict/limit cached rows outside the
  /// current viewport instead of unbounded accumulation") — a session that
  /// pans the map widely would otherwise grow this table forever, since
  /// `refreshTerritories` only ever adds/updates rows for whatever bbox was
  /// last queried.
  static const _cacheCap = 2000;

  /// `compute()` spawns a real isolate, which has non-trivial fixed cost
  /// (spawn + message copy) — worth paying only when the parse it's avoiding
  /// would actually risk blocking a frame. Below this row count the inline
  /// parse is cheaper than the isolate hop; above it, a large cache (up to
  /// `_cacheCap`) can have enough combined polygon complexity to jank the UI
  /// thread, so it's worth moving off it.
  static const _isolateThreshold = 200;

  @override
  Stream<List<Territory>> watchTerritories() {
    return (_db.select(
      _db.territories,
    )..where((t) => t.deletedAt.isNull())).watch().asyncMap((rows) async {
      if (rows.isEmpty) return const <Territory>[];
      final args = (rows, _currentUserId);
      // GeoJSON parsing/coordinate transform for every cached row feeds
      // straight into the map render. For small/typical caches the parse
      // itself is cheap, so it stays inline; only above `_isolateThreshold`
      // does it move to a background isolate via `compute()`.
      if (rows.length < _isolateThreshold) return _mapTerritoryRows(args);
      return compute(_mapTerritoryRows, args);
    });
  }

  @override
  Stream<double> watchOwnedAreaSqm() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(0);
    final query = _db.select(_db.territories)
      ..where((t) => t.ownerId.equals(userId))
      ..where((t) => t.deletedAt.isNull());

    // `territories` is pull-only/server-authoritative (never locally
    // authored — see the class doc comment), so the local Drift cache is
    // always a *subset* of the true total: it's bbox-scoped (see
    // `_cacheCap`/`refreshTerritories` above) and silently omits any
    // territory outside whatever's been pulled into view. Summing it
    // directly under-counts a user whose territory spans multiple areas.
    // `my_owned_area_sqm()` sums every row server-side regardless of what's
    // cached, so it's the only correct source for this figure — the local
    // `watch()` stream is used purely as a "something changed, refetch"
    // trigger (fires immediately on listen, and again after every
    // `refreshTerritories()` pull), not as the emitted value itself.
    return query.watch().asyncMap((_) => _remote.fetchMyOwnedAreaSqm());
  }

  @override
  Future<void> refreshTerritories(GeoBounds bounds) async {
    final rows = await _remote.fetchTerritoriesInBbox(bounds);
    final fetchedIds = rows.map((r) => r['id']! as String).toSet();

    await _db.transaction(() async {
      // Reconciliation: `territories_in_bbox` only ever returns non-deleted
      // rows for this bbox — a previously-cached row that fell inside this
      // same bbox but is missing from the fresh result has been removed
      // server-side (decayed, captured away, etc). Upsert-only would keep
      // that stale geometry cached forever.
      final cached = await _db.select(_db.territories).get();
      for (final row in cached) {
        final rowBounds = TerritoryMapper.boundsOf(row.geoJson);
        if (rowBounds == null) continue;
        final inQueriedBounds =
            rowBounds.minLat <= bounds.maxLat &&
            rowBounds.maxLat >= bounds.minLat &&
            rowBounds.minLng <= bounds.maxLng &&
            rowBounds.maxLng >= bounds.minLng;
        if (!inQueriedBounds) continue;

        if (!fetchedIds.contains(row.id)) {
          if (row.deletedAt == null) {
            await (_db.update(_db.territories)
                  ..where((t) => t.id.equals(row.id)))
                .write(TerritoriesCompanion(deletedAt: Value(DateTime.now())));
          }
        } else if (row.deletedAt != null) {
          // Reappeared in a fresh fetch (e.g. recaptured) — clear the
          // tombstone; the upsert below refreshes its geometry/area anyway.
          await (_db.update(_db.territories)..where((t) => t.id.equals(row.id)))
              .write(const TerritoriesCompanion(deletedAt: Value(null)));
        }
      }

      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _db.territories,
          rows.map((row) {
            return TerritoriesCompanion.insert(
              id: row['id']! as String,
              ownerId: row['user_id']! as String,
              geoJson: jsonEncode(row['geom_geojson']),
              areaSqm: (row['area_sqm']! as num).toDouble(),
              updatedAt: DateTime.parse(row['updated_at']! as String),
              health: Value((row['health'] as num?)?.toInt()),
            );
          }).toList(),
        );
      });

      await _evictBeyondCap();
    });
  }

  /// Keeps the cache bounded once it exceeds [_cacheCap]: drops the
  /// least-recently-updated rows outside the just-queried bbox first (rows
  /// inside it were just refreshed and are the most likely to be viewed
  /// again immediately).
  Future<void> _evictBeyondCap() async {
    final total =
        await (_db.selectOnly(_db.territories)
              ..addColumns([_db.territories.id.count()]))
            .map((row) => row.read(_db.territories.id.count()) ?? 0)
            .getSingle();
    final overflow = total - _cacheCap;
    if (overflow <= 0) return;

    final evictable =
        await (_db.select(_db.territories)
              ..orderBy([(t) => OrderingTerm.asc(t.updatedAt)])
              ..limit(overflow))
            .get();
    if (evictable.isEmpty) return;
    await (_db.delete(
      _db.territories,
    )..where((t) => t.id.isIn(evictable.map((r) => r.id)))).go();
  }

  @override
  Future<Rival?> fetchCurrentRival() async {
    final row = await _remote.fetchCurrentRival();
    if (row == null) return null;
    return Rival(
      rivalId: row['rival_id']! as String,
      rivalDisplayName: row['rival_display_name'] as String?,
      areaTakenSqm: (row['area_taken_sqm']! as num).toDouble(),
      asWinner: row['as_winner']! as bool,
      occurredAt: DateTime.parse(row['occurred_at']! as String),
      territoryLat: (row['rival_territory_lat'] as num?)?.toDouble(),
      territoryLng: (row['rival_territory_lng'] as num?)?.toDouble(),
    );
  }

  @override
  Future<List<TerritoryAtRisk>> fetchTerritoriesAtRisk() async {
    final rows = await _remote.fetchTerritoriesAtRisk();
    return rows
        .map(
          (row) => TerritoryAtRisk(
            id: row['id']! as String,
            areaSqm: (row['area_sqm']! as num).toDouble(),
            lastDefendedAt: DateTime.parse(row['last_defended_at']! as String),
            expiresAt: DateTime.parse(row['expires_at']! as String),
          ),
        )
        .toList();
  }

  @override
  Future<List<BountyZone>> fetchActiveBountyZones() async {
    final rows = await _remote.fetchActiveBountyZones();
    return rows
        .map(
          (row) => BountyZone(
            id: row['id']! as String,
            centerLat: (row['center_lat']! as num).toDouble(),
            centerLng: (row['center_lng']! as num).toDouble(),
            radiusM: (row['radius_m']! as num).toDouble(),
            multiplier: (row['multiplier']! as num).toDouble(),
          ),
        )
        .toList();
  }
}

/// Top-level (isolate-sendable) so `compute()` in `watchTerritories` can run
/// it off the main isolate.
List<Territory> _mapTerritoryRows(
  (List<TerritoryRow> rows, String? currentUserId) args,
) {
  final (rows, currentUserId) = args;
  return rows
      .map((r) => TerritoryMapper.fromRow(r, currentUserId: currentUserId))
      .toList();
}
