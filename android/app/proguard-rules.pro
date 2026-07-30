# Most plugins used here (maplibre_gl, geolocator, camera, google_mlkit_pose_detection,
# flutter_local_notifications, the `alarm` package) ship their own AAR
# consumer-rules.pro, which AGP merges automatically — this file only needs
# to cover things those don't. Kept intentionally small; if a release build
# crashes with a ClassNotFoundException/NoSuchMethodError that a debug build
# doesn't, that's the signal to add a targeted `-keep` here rather than
# widening these broadly.
#
# Verified 2026-07-30 via a real `flutter build apk --release --flavor prod`
# + inspecting build/app/outputs/mapping/prodRelease/{seeds,usage}.txt:
# flutter_foreground_task's Service/Receiver/Plugin entry points and
# geolocator's plugin/enum classes survive R8 (kept automatically as
# manifest-declared components / via their own consumer rules) — no
# additional -keep needed for either. Re-verify the same way after bumping
# either plugin's major version.

# ML Kit pose detection loads some classes via reflection for its
# on-device model loader.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# MapLibre Native's JNI bridge (org.maplibre.android.geometry, .maps, etc.)
# is called from native code by class/method name, which R8 can't see and
# would otherwise strip.
-keep class org.maplibre.android.** { *; }
-dontwarn org.maplibre.android.**

# Gson-based (de)serialization used transitively by several Play Services
# APIs (location, ML Kit) needs generic signatures kept to work post-shrink.
-keepattributes Signature,*Annotation*
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
