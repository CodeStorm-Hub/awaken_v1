import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../sync/local/database.dart';
import '../../../../sync/outbox/local_writer.dart';

/// The wake-up tax, kept per-user rather than per-alarm (plan discussion:
/// a per-alarm multiplier is gameable — delete the alarm, recreate it,
/// tax resets to 1.0). Writes go through `LocalWriter` (transactional
/// write + outbox enqueue, same as every other synced entity); reads go
/// straight to `AppDatabase`, matching `LocalWriter`'s write-only contract.
@lazySingleton
class WakeUpTaxStore {
  WakeUpTaxStore(this._db, this._localWriter);

  final AppDatabase _db;
  final LocalWriter _localWriter;

  static const _rowId = 1;

  Stream<double> watch() {
    return (_db.select(_db.userStats)..where((t) => t.id.equals(_rowId)))
        .watchSingleOrNull()
        .map((row) => row?.currentTaxMultiplier ?? 1.0);
  }

  Future<double> current() async {
    final row = await (_db.select(_db.userStats)..where((t) => t.id.equals(_rowId)))
        .getSingleOrNull();
    return row?.currentTaxMultiplier ?? 1.0;
  }

  /// Bounded step-up on a skip (plan §2.3 — never unbounded exponential).
  Future<void> bump() async {
    final next = (await current() * AppConstants.penaltyMultiplierStep)
        .clamp(1.0, AppConstants.penaltyMultiplierCap);
    await _localWriter.upsertUserStats(currentTaxMultiplier: next);
  }

  /// Full reset on any verified completion — the most legible rule (plan
  /// discussion: legibility over economy-tuning nuance).
  Future<void> reset() => _localWriter.upsertUserStats(currentTaxMultiplier: 1.0);
}
