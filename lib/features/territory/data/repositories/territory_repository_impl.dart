import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../sync/local/database.dart';
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

  @override
  Stream<List<Territory>> watchTerritories() {
    return _db.select(_db.territories).watch().map(
          (rows) => rows.map((r) => TerritoryMapper.fromRow(r, currentUserId: _currentUserId)).toList(),
        );
  }

  @override
  Stream<double> watchOwnedAreaSqm() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(0);
    final query = _db.select(_db.territories)..where((t) => t.ownerId.equals(userId));
    return query.watch().map((rows) => rows.fold<double>(0, (sum, r) => sum + r.areaSqm));
  }

  @override
  Future<void> refreshTerritories() async {
    final rows = await _remote.fetchTerritories();
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
  }
}
