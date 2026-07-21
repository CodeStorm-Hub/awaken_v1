/// Drives the cloud-state chip (plan §3). `offline` and `idle` are both
/// "nothing pending"; kept distinct so the UI can show a muted vs. a
/// reassuring "synced" indicator.
enum SyncStatus { offline, idle, syncing, error }
