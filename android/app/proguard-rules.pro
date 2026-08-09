# Most plugins used here (maplibre_gl, geolocator, camera, google_mlkit_pose_detection,
# flutter_local_notifications, the `alarm` package) ship their own AAR
# consumer-rules.pro, which AGP merges automatically — this file only needs
# to cover things those don't. Kept intentionally small; if a release build
# crashes with a ClassNotFoundException/NoSuchMethodError that a debug build
# doesn't, that's the signal to add a targeted `-keep` here rather than
# widening these broadly.

# ===========================================================================
# FIX: "Failed to create an instance of androidx.work.impl.WorkDatabase"
# WorkManager (used by the `alarm` package and flutter_foreground_task)
# uses Room under the hood. R8 strips the auto-generated RoomDatabase
# implementation classes and their no-arg constructors when minification
# is enabled. The WorkManager AAR ships consumer rules but they are
# insufficient when isShrinkResources=true is combined with full R8 mode.
# ===========================================================================
-keep class androidx.work.** { *; }
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.**

# Room Database — keeps generated _Impl classes that R8 can't trace via
# reflection. WorkManager's WorkDatabase is a Room DB internally.
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Database class * { *; }
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public static ** INSTANCE;
    public static ** Companion;
}
-dontwarn androidx.room.**

# Drift (moor) — the local app database also uses code generation.
-keep class **.drift.** { *; }
-keep class **.moor.** { *; }
-dontwarn **.drift.**

# ML Kit pose detection loads some classes via reflection for its
# on-device model loader.
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# MapLibre Native's JNI bridge (org.maplibre.android.geometry, .maps, etc.)
# is called from native code by class/method name, which R8 can't see and
# would otherwise strip.
-keep class org.maplibre.android.** { *; }
-dontwarn org.maplibre.android.**

# The `alarm` package (com.gdelataillade.alarm) — its consumer-rules.pro
# covers most of this, but its WorkManager-driven alarm-ring callback is
# invoked by class name from a background isolate/worker, which R8 can't
# trace statically. A silently-dropped callback here means an alarm that
# never rings — explicit keep rather than trusting the consumer rules alone
# (see this file's header comment: verified only by manual device testing,
# not CI, so a dependency bump could regress this undetected).
-keep class com.gdelataillade.alarm.** { *; }
-dontwarn com.gdelataillade.alarm.**

# flutter_foreground_task (com.pravera.flutter_foreground_task) — same
# reasoning: its Android foreground-service/task-handler classes are
# started by the OS via class name, not a direct Kotlin call R8 can trace.
-keep class com.pravera.flutter_foreground_task.** { *; }
-dontwarn com.pravera.flutter_foreground_task.**

# Gson-based (de)serialization used transitively by several Play Services
# APIs (location, ML Kit) needs generic signatures kept to work post-shrink.
-keepattributes Signature,*Annotation*
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Sentry — crash reporting SDK uses reflection to read app metadata.
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Supabase / Ktor / OkHttp — network layer used for backend sync.
-keep class io.ktor.** { *; }
-dontwarn io.ktor.**
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class okio.** { *; }
-dontwarn okio.**

# Kotlin serialization used by Supabase client.
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep class kotlinx.serialization.** { *; }
-dontwarn kotlinx.serialization.**
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}

# Flutter plugin registrant — always keep so the plugin registry survives shrink.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**
