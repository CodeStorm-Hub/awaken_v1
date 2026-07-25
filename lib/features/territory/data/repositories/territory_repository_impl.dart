import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../sync/local/database.dart';
import '../../domain/entities/geo_bounds.dart';
import '../../domain/entities/territory.dart';
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

  @override
  Stream<List<Territory>> watchTerritories() {
    return (_db.select(
      _db.territories,
    )..where((t) => t.deletedAt.isNull())).watch().map(
      (rows) => rows
          .map((r) => TerritoryMapper.fromRow(r, currentUserId: _currentUserId))
          .toList(),
    );
  }

  @override
  Stream<double> watchOwnedAreaSqm() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(0);
    final query = _db.select(_db.territories)
      ..where((t) => t.ownerId.equals(userId))
      ..where((t) => t.deletedAt.isNull());
    return query.watch().map(
      (rows) => rows.fold<double>(0, (sum, r) => sum + r.areaSqm),
    );
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
}
