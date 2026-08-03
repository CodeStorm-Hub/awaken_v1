# Flutter MapLibre 3D & Location Performance Rules

## Engine & Component Usage
* For mobile-only Flutter apps (Android & iOS), use `maplibre_gl` wrapping **MapLibre Native**.
* Do not load MapLibre GL JS on mobile builds.

## 3D Extrusions & Styling
* Use `type: "fill-extrusion"` in MapLibre Style JSON for 3D buildings.
* Apply `minzoom: 14` on 3D extrusion layers to preserve rendering performance at low zoom levels.
* Configure dynamic camera pitch (`pitch: 60.0`) for perspective 3D views.

## High-Frequency GPS Tracking
* **DO NOT** invoke `setState()` on high-frequency location update stream callbacks.
* Update camera or markers directly via `MapLibreMapController.animateCamera(CameraUpdate.newCameraPosition(...), duration: Duration(milliseconds: 800))` to ensure 60-120 FPS rendering off the main Flutter isolate thread.
