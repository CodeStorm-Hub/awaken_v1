import 'package:awaken/features/alarm/data/datasources/wake_up_tax_store.dart';
import 'package:awaken/sync/local/database.dart';
import 'package:awaken/sync/outbox/local_writer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plan discussion: the wake-up tax is global/per-user (not per-alarm) so
/// it can't be reset by deleting and recreating an alarm.
void main() {
  late AppDatabase db;
  late WakeUpTaxStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = WakeUpTaxStore(db, LocalWriter(db));
  });

  tearDown(() => db.close());

  test('defaults to 1.0 with no prior writes', () async {
    expect(await store.current(), 1.0);
  });

  test('bump() steps up by the configured multiplier', () async {
    await store.bump();
    expect(await store.current(), 1.5);
    await store.bump();
    expect(await store.current(), 2.25);
  });

  test('bump() is bounded at the configured cap', () async {
    for (var i = 0; i < 10; i++) {
      await store.bump();
    }
    expect(await store.current(), 4.0);
  });

  test('reset() returns to 1.0 regardless of accumulated bumps', () async {
    await store.bump();
    await store.bump();
    await store.reset(sessionId: 'session-1');
    expect(await store.current(), 1.0);
  });

  test('watch() reflects the latest value after each write', () async {
    expect(await store.watch().first, 1.0);
    await store.bump();
    expect(await store.watch().first, 1.5);
    await store.reset(sessionId: 'session-1');
    expect(await store.watch().first, 1.0);
  });
}
