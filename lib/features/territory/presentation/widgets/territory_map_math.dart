import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../../domain/entities/territory_at_risk.dart';

/// Pure geometry/formatting helpers shared by `territory_page.dart` and
/// `active_run_page.dart` — extracted from both (previously duplicated
/// verbatim, e.g. `_colorToHex`) since none of them touch a
/// `MapLibreMapController` or any widget state, unlike the rest of either
/// file's map-lifecycle logic.
String colorToHex(Color color) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${argb.substring(2)}';
}

double haversineMeters(LatLng a, LatLng b) {
  const earthRadiusM = 6371000.0;
  final dLat = (b.latitude - a.latitude) * (math.pi / 180);
  final dLng = (b.longitude - a.longitude) * (math.pi / 180);
  final lat1 = a.latitude * (math.pi / 180);
  final lat2 = b.latitude * (math.pi / 180);
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthRadiusM * math.asin(math.sqrt(h));
}

/// A 32-point polygon approximating a [radiusMeters] circle around
/// (lat, lng) — MapLibre's `CircleOptions.circleRadius` is in screen
/// pixels, not meters, so it can't represent a real-world-sized zone that
/// stays accurate across zoom levels; a `Fill` polygon (same primitive
/// territories already use) does.
List<LatLng> circlePolygon(double lat, double lng, double radiusMeters) {
  const points = 32;
  const earthRadiusM = 6371000.0;
  final latRad = lat * (math.pi / 180);
  final ring = <LatLng>[];
  for (var i = 0; i <= points; i++) {
    final angle = 2 * math.pi * i / points;
    final dLat =
        (radiusMeters * math.cos(angle)) / earthRadiusM * (180 / math.pi);
    final dLng =
        (radiusMeters * math.sin(angle)) /
        (earthRadiusM * math.cos(latRad)) *
        (180 / math.pi);
    ring.add(LatLng(lat + dLat, lng + dLng));
  }
  return ring;
}

/// Fallback health (0-100) for an owned territory, derived from
/// `TerritoryAtRisk.lastDefendedAt`/`expiresAt` — used only when
/// `Territory.health` is null (a row cached before `territories_in_bbox()`
/// started returning the real server-computed `health` column, i.e. a
/// cache-migration safety net, not the normal path anymore). A territory
/// absent from the at-risk list is outside the decay warning window
/// entirely, i.e. full health.
double healthOfTerritory(
  String territoryId,
  Map<String, TerritoryAtRisk> atRiskById,
) {
  final risk = atRiskById[territoryId];
  if (risk == null) return 100;
  final totalWindowSec = risk.expiresAt
      .difference(risk.lastDefendedAt)
      .inSeconds;
  if (totalWindowSec <= 0) return 0;
  final remainingSec = risk.expiresAt.difference(DateTime.now()).inSeconds;
  return (remainingSec / totalWindowSec * 100).clamp(0, 100).toDouble();
}
