# Architecture Decision Records

Short-form ADRs for the two decisions the refined plan flags as "decide once in Phase 0
and never revisit" (`awaken_app_refined_plan.md` §3, §6).

## ADR-001: State management — BLoC over Riverpod

**Decision:** `flutter_bloc` ^9.x.

**Context:** Both are viable; the plan calls this a coin-flip the team should make once and
stick with, since revisiting it mid-project means rewriting every feature's presentation layer.

**Rationale:** BLoC's explicit event→state contract maps directly onto the app's highest-risk
screens (alarm ring state machine, rep-counting state machine) where every transition needs to
be traceable and unit-testable in isolation from widgets. `bloc_test` gives us that for free.
Riverpod would work equally well; this is a default, not a rejection of Riverpod's merits.

**Consequences:** Every feature's `presentation/bloc/` follows the same Cubit/Bloc pattern.
`get_it`/`injectable` still owns cross-feature dependency wiring — blocs are constructed with
injected use cases, not injected themselves as global singletons.

---

## ADR-002: Offline sync engine — hand-rolled outbox over PowerSync

**Decision:** Hand-rolled outbox on Drift (transactional write + `sync_outbox` table +
backoff worker), not PowerSync or `offline_first_sync_drift`.

**Context:** Plan issue C5 — `offline_first_sync_drift` (v0.1.x, 4 likes, unverified
uploader) is too immature to own the app's core data-loss invariant. PowerSync is a credible,
purpose-built alternative but adds a managed-service dependency (or self-host burden) and
cost.

**Rationale:** Awaken's write patterns are simple and single-writer: append-only `sessions`
and `runs`, `territories` mutated only server-side via RPC. This doesn't need PowerSync's
general bidirectional-merge machinery. The outbox pattern (transactional enqueue in the same
SQLite transaction as the domain write, connectivity-triggered drain, `next_attempt_at`
backoff, idempotent upserts on client-generated UUIDv4 PKs) is ~500 lines, fully documented,
and keeps us vendor-free.

**Consequences:** `sync/` (plan §3) is the single place this logic lives; every feature writes
through a shared `LocalWriter`, never touches Supabase directly for user data. Revisit only if
the write patterns become genuinely bidirectional/collaborative (e.g. real-time co-editing) —
not expected for this product.
