import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:awaken/features/territory/data/mappers/territory_mapper.dart';

void main() {
  group('TerritoryMapper.polygonsFromMultiPolygonGeoJson', () {
    test('Polygon with no holes keeps a single outer ring', () {
      final geoJson = jsonEncode({
        'type': 'Polygon',
        'coordinates': [
          [
            [0.0, 0.0],
            [1.0, 0.0],
            [1.0, 1.0],
            [0.0, 0.0],
          ],
        ],
      });

      final polygons = TerritoryMapper.polygonsFromMultiPolygonGeoJson(
        geoJson,
      );

      expect(polygons, hasLength(1));
      expect(polygons.single, hasLength(1)); // outer ring only, no holes
      expect(polygons.single.single, hasLength(4));
    });

    test('Polygon with a hole keeps both the outer ring and the hole ring', () {
      // A previous version of this mapper dropped every ring past the
      // first ("holes are not modeled in v1") — this locks in that a
      // rival's ST_Difference cutout landing fully inside a territory now
      // survives parsing as a real interior ring instead of being silently
      // discarded.
      final geoJson = jsonEncode({
        'type': 'Polygon',
        'coordinates': [
          [
            [0.0, 0.0],
            [10.0, 0.0],
            [10.0, 10.0],
            [0.0, 10.0],
            [0.0, 0.0],
          ],
          [
            [4.0, 4.0],
            [6.0, 4.0],
            [6.0, 6.0],
            [4.0, 6.0],
            [4.0, 4.0],
          ],
        ],
      });

      final polygons = TerritoryMapper.polygonsFromMultiPolygonGeoJson(
        geoJson,
      );

      expect(polygons, hasLength(1));
      final rings = polygons.single;
      expect(rings, hasLength(2)); // outer + 1 hole
      expect(rings[0], hasLength(5)); // outer boundary
      expect(rings[1], hasLength(5)); // hole ring

      // GeoJSON is [lng, lat]; LatLng flips to (lat, lng).
      expect(rings[0].first.latitude, 0.0);
      expect(rings[0].first.longitude, 0.0);
      expect(rings[1].first.latitude, 4.0);
      expect(rings[1].first.longitude, 4.0);
    });

    test('MultiPolygon preserves per-component ring lists independently', () {
      final geoJson = jsonEncode({
        'type': 'MultiPolygon',
        'coordinates': [
          [
            // Component 1: outer only.
            [
              [0.0, 0.0],
              [1.0, 0.0],
              [1.0, 1.0],
              [0.0, 0.0],
            ],
          ],
          [
            // Component 2: outer + hole.
            [
              [10.0, 10.0],
              [20.0, 10.0],
              [20.0, 20.0],
              [10.0, 10.0],
            ],
            [
              [12.0, 12.0],
              [13.0, 12.0],
              [13.0, 13.0],
              [12.0, 12.0],
            ],
          ],
        ],
      });

      final polygons = TerritoryMapper.polygonsFromMultiPolygonGeoJson(
        geoJson,
      );

      expect(polygons, hasLength(2));
      expect(polygons[0], hasLength(1)); // component 1: outer only
      expect(polygons[1], hasLength(2)); // component 2: outer + hole
    });

    test('unrecognized geometry type returns empty', () {
      final geoJson = jsonEncode({
        'type': 'Point',
        'coordinates': [0.0, 0.0],
      });
      expect(TerritoryMapper.polygonsFromMultiPolygonGeoJson(geoJson), isEmpty);
    });
  });

  group('TerritoryMapper.boundsOf', () {
    test('computes the bounding box across all rings including holes', () {
      final geoJson = jsonEncode({
        'type': 'Polygon',
        'coordinates': [
          [
            [-5.0, -5.0],
            [5.0, -5.0],
            [5.0, 5.0],
            [-5.0, 5.0],
            [-5.0, -5.0],
          ],
          [
            [1.0, 1.0],
            [2.0, 1.0],
            [2.0, 2.0],
            [1.0, 1.0],
          ],
        ],
      });

      final bounds = TerritoryMapper.boundsOf(geoJson)!;

      expect(bounds.minLng, -5.0);
      expect(bounds.maxLng, 5.0);
      expect(bounds.minLat, -5.0);
      expect(bounds.maxLat, 5.0);
    });

    test('returns null for empty coordinates', () {
      final geoJson = jsonEncode({
        'type': 'MultiPolygon',
        'coordinates': <Object?>[],
      });
      expect(TerritoryMapper.boundsOf(geoJson), isNull);
    });
  });
}
