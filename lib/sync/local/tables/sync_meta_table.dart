import 'package:drift/drift.dart';

/// Per-table watermark for `PullDownSync`'s incremental delta pull — one
/// row per remote table pulled, tracking the newest `updated_at` seen so
/// far so every sync cycle can pull `updated_at > lastPulledAt` instead of
/// only ever hydrating once on a bare local cache (see `PullDownSync` doc
/// comment on why the old one-shot-on-empty-table approach missed
/// convergence after the first pull).
@DataClassName('SyncMetaRow')
class SyncMeta extends Table {
  TextColumn get entityTable => text()();
  DateTimeColumn get lastPulledAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entityTable};
}
