import 'package:awaken/features/territory/data/datasources/territory_remote_datasource.dart';
import 'package:awaken/features/territory/data/repositories/territory_repository_impl.dart';
import 'package:awaken/sync/local/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockTerritoryRemoteDataSource extends Mock
    implements TerritoryRemoteDataSource {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockGoTrueClient extends Mock implements GoTrueClient {}

class _MockUser extends Mock implements User {}

void main() {
  late AppDatabase db;
  late _MockTerritoryRemoteDataSource remote;
  late _MockSupabaseClient supabase;
  late _MockGoTrueClient auth;
  late TerritoryRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = _MockTerritoryRemoteDataSource();
    supabase = _MockSupabaseClient();
    auth = _MockGoTrueClient();

    when(() => supabase.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(null);

    repository = TerritoryRepositoryImpl(remote, db, supabase);
  });

  tearDown(() => db.close());

  /// A minimal valid single-ring square Polygon GeoJSON, offset by [seed] so
  /// distinct rows have distinct (but still valid) geometry.
  String squareGeoJson(int seed) {
    final base = seed.toDouble();
    return '{"type":"Polygon","coordinates":[[[$base,$base],'
        '[${base + 1},$base],[${base + 1},${base + 1}],'
        '[$base,${base + 1}],[$base,$base]]]}';
  }

  Future<void> insertRows(int count, {String ownerId = 'owner-1'}) async {
    for (var i = 0; i < count; i++) {
      await db
          .into(db.territories)
          .insert(
            TerritoriesCompanion.insert(
              id: 'territory-$i',
              ownerId: ownerId,
              geoJson: squareGeoJson(i),
              areaSqm: 100.0 + i,
              updatedAt: DateTime(2026, 1, 1),
            ),
          );
    }
  }

  group('TerritoryRepositoryImpl.watchTerritories — compute() offload', () {
    test(
      'emits an empty list without touching the parser when the cache is empty',
      () async {
        final result = await repository.watchTerritories().first;
        expect(result, isEmpty);
      },
    );

    test(
      'below the isolate threshold: rows are parsed correctly via the inline path',
      () async {
        await insertRows(3);

        final result = await repository.watchTerritories().first;

        expect(result, hasLength(3));
        final ids = result.map((t) => t.id).toSet();
        expect(ids, {'territory-0', 'territory-1', 'territory-2'});
        for (final territory in result) {
          expect(territory.ownerId, 'owner-1');
          expect(territory.isMine, isFalse); // currentUserId is null
          expect(territory.polygons, isNotEmpty);
          expect(territory.polygons.first.first, isNotEmpty); // outer ring
        }
      },
    );

    test(
      'above the isolate threshold: rows are parsed correctly via compute() '
      '— proving the isolate round-trip (message serialization) works end to end',
      () async {
        // TerritoryRepositoryImpl._isolateThreshold is 200 — comfortably
        // exceeded here without needing a slow/huge fixture.
        await insertRows(205);

        final result = await repository.watchTerritories().first;

        expect(result, hasLength(205));
        expect(result.map((t) => t.id).toSet(), hasLength(205));
        expect(result.every((t) => t.polygons.isNotEmpty), isTrue);
      },
    );

    test(
      'marks a territory as "mine" when its ownerId matches the signed-in user',
      () async {
        when(() => auth.currentUser).thenReturn(_MockUser());
        final user = auth.currentUser!;
        when(() => user.id).thenReturn('owner-1');

        await insertRows(1);

        final result = await repository.watchTerritories().first;

        expect(result.single.isMine, isTrue);
      },
    );
  });
}
