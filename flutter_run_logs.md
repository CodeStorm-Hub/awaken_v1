PS J:\GitHub\flutter_projects\awaken> flutter run --flavor dev -t lib/main_dev.dart
Resolving dependencies...
Downloading packages... 
  _fe_analyzer_shared 96.0.0 (105.0.0 available)
  analyzer 10.2.0 (14.1.0 available)
  build 4.0.7 (4.0.9 available)
  build_config 1.3.1 (1.3.2 available)
  build_runner 2.15.1 (2.15.3 available)
  cli_util 0.4.2 (0.5.2 available)
  connectivity_plus 6.1.5 (7.3.1 available)
  dart_style 3.1.7 (3.1.12 available)
  drift 2.34.2 (2.34.3 available)
  drift_dev 2.34.0 (2.34.5 available)
  get_it 8.3.0 (9.2.1 available)
  google_fonts 6.3.3 (8.2.0 available)
  hooks 2.0.2 (2.1.0 available)
  image 4.8.0 (4.9.1 available)
  injectable 2.7.1+4 (3.0.0 available)
  injectable_generator 2.12.1 (3.1.1 available)
  intl 0.20.2 (0.20.3 available)
  jni 0.14.2 (1.0.2 available)
  latlong2 0.9.1 (0.10.1 available)
  lean_builder 0.1.10 (1.2.0 available)
  matcher 0.12.19 (0.12.20 available)
  meta 1.18.0 (1.19.0 available)
  native_toolchain_c 0.19.2 (0.19.3 available)
  objective_c 9.4.1 (9.5.0 available)
  package_config 2.2.0 (3.0.0 available)
  path_provider_android 2.2.23 (2.3.1 available)
  patrol 3.20.0 (4.8.0 available)
  patrol_finders 2.9.0 (3.6.0 available)
  patrol_log 0.5.0 (0.10.0 available)
  posix 6.5.0 (6.5.2 available)
  record_use 0.6.0 (1.0.0 available)
  source_gen 4.2.3 (4.2.4 available)
  sqlite3_flutter_libs 0.5.42 (0.6.0+eol available)
  sqlparser 0.44.5 (0.45.0 available)
  test 1.31.0 (1.31.2 available)
  test_api 0.7.11 (0.7.13 available)
  test_core 0.6.17 (0.6.19 available)
  vector_math 2.2.0 (2.4.1 available)
  xml 6.6.1 (7.0.1 available)
Got dependencies!
39 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Launching lib/main_dev.dart on sdk gphone16k x86 64 in debug mode...
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): alarm, dynamic_color, flutter_foreground_task, google_mlkit_commons, google_mlkit_pose_detection, maplibre_gl, patrol, sentry_flutter
Future versions of Flutter will fail to build if your app uses plugins that apply KGP.

Please check the changelogs of these plugins and upgrade to a version that supports Built-in Kotlin.
If no such version exists, report the issue to the plugin. If necessary, here is a guide on filing
an issue against a plugin: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers#report-incompatible-kotlin-gradle-plugin-usage-to-plugin-authors

If you are a plugin author, please migrate your plugin to Built-in Kotlin using this guide: https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors
Running Gradle task 'assembleDevDebug'...                          22.5s
√ Built build\app\outputs\flutter-apk\app-dev-debug.apk
Installing build\app\outputs\flutter-apk\app-dev-debug.apk...      1,546ms
I/FlutterActivityAndFragmentDelegate(15552): If you are attempting to set --enable-dart-profiling via Intent extras to launch a Flutter component outside of using the Flutter CLI, note that support for setting engine flags on Android via Intent will soon be dropped; see https://github.com/flutter/flutter/issues/180686 for more information on this breaking change. To migrate, set --enable-dart-profiling or any other flags specified via Intent extras on the command line instead or see https://github.com/flutter/flutter/blob/main/docs/engine/Flutter-Android-Engine-Flags.md for alternative methods.     
D/FlutterJNI(15552): Beginning load of flutter...
D/FlutterJNI(15552): flutter (null) was loaded normally!
I/flutter (15552): [IMPORTANT:flutter/shell/platform/android/android_context_gl_impeller.cc(104)] Using the Impeller rendering backend (OpenGLES).
D/FlutterGeolocator(15552): Attaching Geolocator to activity
D/FlutterRenderer(15552): Width is zero. 0,0
D/FlutterGeolocator(15552): Creating service.
D/FlutterGeolocator(15552): Binding to location service.
I/WindowExtensionsImpl(15552): Initializing Window Extensions, vendor API level=10, activity embedding enabled=true
W/UiContextUtils(15552): Requested context is a non-UI Context. Creating a UI-Context with display: 0. Context: Context=android.app.Application@6431311, of which baseContext=android.app.ContextImpl@9a02cc7
D/VRI[MainActivity](15552): WindowInsets changed: 1080x2424 statusBars:[0,142,0,0] navigationBars:[0,0,0,63] mandatorySystemGestures:[0,174,0,84]
D/FlutterRenderer(15552): Width is zero. 0,0
I/aken.awaken.dev(15552): Compiler allocated 5567KB to compile void android.view.ViewRootImpl.performTraversals(long)
I/Surface (15552): Creating surface for consumer unnamed-15552-0 with slotExpansion=1 for 64 slots
I/Surface (15552): Creating surface for consumer VRI[MainActivity]#0(BLAST Consumer)0 with slotExpansion=1 for 64 slots
D/FlutterJNI(15552): Sending viewport metrics to the engine.
I/Surface (15552): Creating surface for consumer unnamed-15552-1 with slotExpansion=1 for 64 slots
I/Surface (15552): Creating surface for consumer e264b19 SurfaceView[com.awaken.awaken.dev/com.awaken.awaken.MainActivity]#1(BLAST Consumer)1 with slotExpansion=1 for 64 slots
Syncing files to device sdk gphone16k x86 64...                    136ms

Flutter run key commands.
r Hot reload.
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).

A Dart VM Service on sdk gphone16k x86 64 is available at: http://127.0.0.1:57971/t-P33WpjwK4=/
The Flutter DevTools debugger and profiler on sdk gphone16k x86 64 is available at: http://127.0.0.1:57971/t-P33WpjwK4=/devtools/?uri=ws://127.0.0.1:57971/t-P33WpjwK4=/ws
I/aken.awaken.dev(15552): hiddenapi: Accessing hidden field Landroid/view/Choreographer;->mLastFrameTimeNanos:J (runtime_flags=0, domain=platform, api=unsupported) from Lio/sentry/android/core/internal/util/SentryFrameMetricsCollector; (domain=app, TargetSdkVersion=36) using reflection: allowed
D/nativeloader(15552): Load /system/lib64/liblog.so using class loader ns clns-9 (caller=/data/app/~~3XqC2Ieikpy-hQhPnhwUzA==/com.awaken.awaken.dev--gKQ5Xr6ozuExFNhPmhrpw==/base.apk!classes22.dex): ok
D/nativeloader(15552): Load /data/app/~~3XqC2Ieikpy-hQhPnhwUzA==/com.awaken.awaken.dev--gKQ5Xr6ozuExFNhPmhrpw==/base.apk!/lib/x86_64/libsentry.so using class loader ns clns-9 (caller=/data/app/~~3XqC2Ieikpy-hQhPnhwUzA==/com.awaken.awaken.dev--gKQ5Xr6ozuExFNhPmhrpw==/base.apk!classes22.dex): ok
D/nativeloader(15552): Load /data/app/~~3XqC2Ieikpy-hQhPnhwUzA==/com.awaken.awaken.dev--gKQ5Xr6ozuExFNhPmhrpw==/base.apk!/lib/x86_64/libsentry-android.so using class loader ns clns-9 (caller=/data/app/~~3XqC2Ieikpy-hQhPnhwUzA==/com.awaken.awaken.dev--gKQ5Xr6ozuExFNhPmhrpw==/base.apk!classes22.dex): ok
W/SentryDeviceInf(15552): type=1400 audit(0.0:77): avc:  denied  { read } for  name="version" dev="proc" ino=4026532034 scontext=u:r:untrusted_app_34:s0:c255,c256,c512,c768 tcontext=u:object_r:proc_version:s0 tclass=file permissive=0 app=com.awaken.awaken.dev
D/FlutterGeolocator(15552): Geolocator foreground service connected
D/FlutterGeolocator(15552): Initializing Geolocator services
D/FlutterGeolocator(15552): Flutter engine connected. Connected engine count 1
I/flutter (15552): supabase.supabase_flutter: INFO: ***** Supabase init completed ***** 
I/Choreographer(15552): Skipped 62 frames!  The application may be doing too much work on its main thread.
D/WindowLayoutComponentImpl(15552): Register WindowLayoutInfoListener on Context=com.awaken.awaken.MainActivity@2729c8c, of which baseContext=android.app.ContextImpl@cbf3f31
D/FlutterJNI(15552): Sending viewport metrics to the engine.
I/HWUI    (15552): Using FreeType backend (prop=Auto)
I/flutter (15552): supabase.auth: INFO: Refresh session 
D/ProfileInstaller(15552): Installing profile for com.awaken.awaken.dev
I/Choreographer(15552): Skipped 81 frames!  The application may be doing too much work on its main thread.
I/HWUI    (15552): Davey! duration=1415ms; Flags=1, FrameTimelineVsyncId=431805, IntendedVsync=5942224236671, Vsync=5943574236617, InputEventId=0, HandleInputStart=5943590410207, AnimationStart=5943590410975, PerformTraversalsStart=5943590411313, DrawStart=5943592977230, FrameDeadline=5942240903337, FrameStartTime=5943589940881, FrameInterval=16666666, WorkloadTarget=16666666, AnimationTime=5943574236617, AnimationCounter=-1, SyncQueued=5943593729856, SyncStart=5943637522643, IssueDrawCommandsStart=5943639914122, SwapBuffers=5943654249129, FrameCompleted=5943683383509, DequeueBufferDuration=27130813, QueueBufferDuration=216345, GpuCompleted=5943658539018, SwapBuffersCompleted=5943683383509, DisplayPresentTime=608896, CommandSubmissionCompleted=5943654249129,
I/flutter (15552): dynamic_color: Core palette detected.
I/PlatformViewsChannel(15552): Using legacy platform view rendering strategy.
D/nativeloader(15552): Load /data/app/~~3XqC2Ieikpy-hQhPnhwUzA==/com.awaken.awaken.dev--gKQ5Xr6ozuExFNhPmhrpw==/base.apk!/lib/x86_64/libmaplibre.so using class loader ns clns-9 (caller=/data/app/~~3XqC2Ieikpy-hQhPnhwUzA==/com.awaken.awaken.dev--gKQ5Xr6ozuExFNhPmhrpw==/base.apk!classes23.dex): ok
I/PlatformViewsController(15552): Hosting view in a virtual display for platform view: 0
I/PlatformViewsController(15552): PlatformView is using SurfaceProducer backend
I/Surface (15552): Creating surface for consumer unnamed-15552-2 with slotExpansion=1 for 64 slots
I/Surface (15552): Creating surface for consumer ImageReader-1080x2424f22m7-15552-0 with slotExpansion=1 for 64 slots
D/InsetsController(15552): Setting requestedVisibleTypes to 240 (was 503)
D/FlutterJNI(15552): Sending viewport metrics to the engine.
D/WindowOnBackDispatcher(15552): setTopOnBackInvokedCallback (unwrapped): android.app.Dialog$$ExternalSyntheticLambda2@b94f5dc
D/WindowOnBackDispatcher(15552): setOnBackInvokedCallbackInfo: android.app.Dialog$$ExternalSyntheticLambda2@b94f5dc
I/Surface (15552): Creating surface for consumer unnamed-15552-3 with slotExpansion=1 for 64 slots
I/Surface (15552): Creating surface for consumer VRI[]#2(BLAST Consumer)2 with slotExpansion=1 for 64 slots
I/Surface (15552): Creating surface for consumer unnamed-15552-4 with slotExpansion=1 for 64 slots
I/Surface (15552): Creating surface for consumer 57de6e5 SurfaceView[]#3(BLAST Consumer)3 with slotExpansion=1 for 64 slots
I/Mbgl-EGLConfigChooser(15552): In emulator: false
W/libc    (15552): Access denied finding property "vendor.mesa.virtgpu.kumquat"
I/Mbgl    (15552): {RenderThread 87}[General]: GPU Identifier: Android Emulator OpenGL ES Translator (NVIDIA GeForce GTX 1650/PCIe/SSE2)
D/InsetsController(15552): hide(ime())
I/ImeTracker(15552): com.awaken.awaken.dev:7ce39b8b: onCancelled at PHASE_CLIENT_ALREADY_HIDDEN
E/FlutterGeolocator(15552): Geolocator position updates started
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
I/aken.awaken.dev(15552): Background concurrent mark compact GC freed 6272KB AllocSpace bytes, 23(1760KB) LOS objects, 49% free, 5236KB/10MB, paused 585us,23.263ms total 65.119ms
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
<!-- This line is generating continuously -->
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {OnlineFileSourc}[General]: The resource `https://tiles.openfreemap.org/fonts/Open%20Sans%20Regular%2cArial%20Unicode%20MS%20Regular/0-255.pbf` not found
E/Mbgl    (15552): {RenderThread 87}[Style]: Failed to load glyph range 0-255 for font stack Open Sans Regular,Arial Unicode MS Regular:( HTTP status code 404)
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
<!-- This line is generating continuously -->
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/FlutterGeolocator(15552): Geolocator position updates stopped
E/FlutterGeolocator(15552): There is still another flutter engine connected, not stopping location service
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
W/Mbgl-HttpRequest(15552): Request failed due to a permanent error: Canceled 
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
W/Mbgl-HttpRequest(15552): Request failed due to a permanent error: Canceled 
W/Mbgl    (15552): {Worker 2}[General]: Invalid geometry in line layer
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
<!-- This line is generating continuously -->
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
I/aken.awaken.dev(15552): Background concurrent mark compact GC freed 4935KB AllocSpace bytes, 0(0B) LOS objects, 49% free, 5556KB/10MB, paused 411us,5.406ms total 18.482ms
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
<!-- This line is generating continuously -->
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
I/aken.awaken.dev(15552): Background young concurrent mark compact GC freed 5561KB AllocSpace bytes, 0(0B) LOS objects, 49% free, 5572KB/10MB, paused 81us,5.895ms total 11.308ms
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
<!-- This line is generating continuously -->
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
I/aken.awaken.dev(15552): NativeAlloc concurrent mark compact GC freed 498KB AllocSpace bytes, 0(0B) LOS objects, 49% free, 5604KB/10MB, paused 81us,5.705ms total 22.578ms
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
E/Mbgl    (15552): {aken.awaken.dev}[JNI]: Error setting property: line-dasharray data expressions not supported
<!-- This line is generating continuously -->