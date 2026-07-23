import 'package:equatable/equatable.dart';

/// A plain lat/lng bounding box — the domain layer's own type rather than
/// reusing `maplibre_gl`'s `LatLngBounds`, since `domain/` has a "zero
/// Flutter imports" convention (see CLAUDE.md) and `maplibre_gl` depends on
/// Flutter. Presentation converts a `MapLibreMapController.getVisibleRegion()`
/// result into this at the call site.
class GeoBounds extends Equatable {
  const GeoBounds({
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
  });

  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  @override
  List<Object?> get props => [minLat, minLng, maxLat, maxLng];
}
