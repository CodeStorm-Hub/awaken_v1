import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

/// Thin wrapper over `connectivity_plus` — the only place besides
/// `SyncWorker` that decides when a drain attempt is worth making. A
/// reachable network doesn't guarantee Supabase is reachable, but it's a
/// cheap enough gate that the outbox's own retry/backoff handles the rest.
@lazySingleton
class ConnectivityWatcher {
  final _connectivity = Connectivity();

  Stream<bool> get onlineChanges =>
      _connectivity.onConnectivityChanged.map(_isOnline);

  Future<bool> get isOnline async => _isOnline(await _connectivity.checkConnectivity());

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
