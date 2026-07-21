/// The two mutation kinds the outbox understands. Soft-delete is modeled as
/// its own operation (rather than an upsert with `deleted_at` set) so the
/// worker can push a minimal `{deleted_at}` patch instead of the full row.
enum OutboxOperation { upsert, delete }
