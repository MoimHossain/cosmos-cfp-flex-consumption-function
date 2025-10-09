Created 4 todos

Ran `microsoft_docs_search` 
Completed with input: {
  "query": "Azure Cosmos DB change feed guarantees at least once ordering partitions"
}

Optimizing tool selection...

Starting (2/4) *Search functions trigger*

Ran Microsoft Docs Search 
Completed with input: {
  "query": "Azure Functions Cosmos DB trigger at least once delivery semantics retry behavior unhandled exception"
}

Starting (3/4) *Gather full-fidelity info*

Ran Microsoft Docs Search 
Completed with input: {
  "query": "Cosmos DB change feed deletes full fidelity all versions and deletes mode reliability"
}

Starting (4/4) *Synthesize answer*

## Short answer

You can rely on the Cosmos DB change feed + Azure Functions trigger to deliver every create/update (and optionally delete, if you enable “all versions and deletes” mode) at least once, but not exactly once, and not necessarily every intermediate update in “latest version” mode. You must design for:
- At-least-once (duplicates / reprocessing possible)
- Possible collapse of rapid successive updates into only the final state (in latest version mode)
- Per–logical-partition ordering only (no global ordering)
- No delete notifications unless you implement soft-delete or use all-versions-and-deletes mode (preview)
- Need for careful error handling because an unhandled exception in a Functions Cosmos DB trigger does NOT automatically retry the same batch (unless you configure a retry policy at the function level)

Below is a deeper breakdown with authoritative references.

---

## What is guaranteed

1. At-least-once delivery (push model / change feed processor semantics)  
   - The feed is an ordered (per partition key value) log of item changes.  
   - Each change appears “exactly once” in the underlying feed; when using processors / triggers, the effective processing guarantee becomes “at least once” because your handler might see the same batch again on retry.  
   Reference: “The change feed processor provides automatic checkpointing and ‘at least once’ semantics.” (Change feed features)

2. Per-partition key ordering  
   - Order is guaranteed by modification time within a single logical partition key value.  
   - No ordering guarantee across different partition key values.  
   Reference: “This sort order is guaranteed per partition key… no guaranteed order across partition key values.”

3. Multi-region continuity  
   - In failover, feed remains contiguous; for multi-write accounts the ordering basis is the conflict-resolution timestamp (crts).  
   Reference: Change feed in multi‑region accounts section.

4. Unlimited retention (latest version mode) while the item exists  
   - You can start from the beginning unless the item was deleted.  
   Reference: Latest version mode retention.

5. All intermediate versions & deletes available only in “all versions and deletes” mode (preview) with continuous backup retention window.  
   - Outside retention window, historical versions vanish for that mode.  
   References: Change feed modes; Design pattern limitations.

---

## What is NOT guaranteed (and common misconceptions)

| Aspect | Reality | Impact on your design |
|--------|---------|-----------------------|
| Exactly once processing | Not guaranteed: you must handle duplicates/idempotency | Make writes idempotent (e.g., upserts with version checks, store last processed etag) |
| Global ordering | Not provided across partitions | Avoid cross-partition causal assumptions |
| Intermediate updates (rapid succession) in latest version mode | May be skipped (you only see final state) | If you need every step, model each state as a separate item or use all versions and deletes mode |
| Deletes (latest version mode) | Not emitted | Use soft delete flag or switch modes |
| Automatic retry on unhandled exception (Functions trigger) | A failed batch may be skipped unless you enable retry policy | Always catch exceptions; use retry policies + dead-letter / error container |
| Full historical replay including deletes | Only if you captured them (soft delete) or used all versions and deletes mode within retention window | Choose mode early; enabling later doesn’t retroactively add history |

---

## Failure / “missing change” scenarios and root causes

1. Unhandled exception in Function without retry policy  
   - The batch isn’t reprocessed; appears as “missed.”  
   Mitigation: Configure [retry policies] + wrap logic in try/catch; dead-letter failing docs.

2. Competing consumers (another Function or local dev instance) with same lease configuration  
   - Leases “stolen,” so expected changes processed elsewhere.  
   Mitigation: Use unique `leaseCollectionPrefix` per logical consumer / environment.

3. Rapid successive updates to same item (latest version mode)  
   - Intermediate states collapsed.  
   Mitigation: Switch to all versions and deletes mode (preview) + continuous backup OR model each event as additive writes.

4. Deletes not appearing  
   - Expected behavior in latest version mode.  
   Mitigation: Soft delete (`deleted:true`) or all versions and deletes mode.

5. Extremely high throughput backlog  
   - Delay (latency) before Function sees changes; not “lost,” just lagging.  
   Mitigation: Scale out (more Function instances), monitor lease container & feed estimator.

6. Lease container data loss (accidental deletion)  
   - Processor restarts from beginning or a default start point (can reprocess duplicates / or skip earliest batch in rare edge).  
   Mitigation: Protect lease container; treat it as critical infra.

---

## Latency expectations

- Typically seconds to low tens of seconds; no strict SLA published for “time to appear.” Backlog size + RU throttling + scale influences. Monitor lag with change feed estimator (SDK) or by tracking latest `_lsn` / `_ts` processed.

---

## When you CAN trust “every change will be observed”

| Need | Mode / Setup | Reliably seen? | Notes |
|------|--------------|---------------|-------|
| Final state after each distinct write (create/update) | Latest version | Yes (while item exists) | Intermediate states may be skipped |
| Each create, update, delete (full audit) | All versions & deletes | Yes (within retention window) | Preview; requires continuous backup |
| Deletes in latest version mode | Latest version only | No | Must soft delete |
| Historical replay back to container origin (existing items) | Latest version | Yes (unless deleted) | Items removed disappear from history |

---

## Design recommendations

1. Idempotency  
   - Include a deterministic operation ID (e.g., item `id` + version, or store last processed `_ts`) to avoid double side effects.

2. Dead-letter / error path  
   - On exception, log + persist failing document version to separate container/queue; then allow normal processing to continue.

3. Lease isolation  
   - Separate prefixes per environment (`dev`, `test`, `prod`) and per distinct processing pipeline to avoid “stealing” changes.

4. Monitoring  
   - Track: (a) number of docs processed per interval, (b) max lag (current time - max processed `_ts`), (c) batch failure counts.

5. Mode choice rubric  
   - If you only care about the “current state progression”: Latest version.  
   - If you need a true event log (all transitions + deletes): All versions and deletes mode + retention aligned with audit requirements.

6. Handling multi-region writes  
   - Expect potential reordering across regions; rely on `crts` for true ordering; design conflict resolution handling if reading concurrently.

---

## Quick checklist

- Need to guarantee no intermediate update lost? Use all versions & deletes or redesign writes as immutable events.
- Need deletes? Soft delete or enable all versions & deletes.
- Need audit chain older than retention window? Persist events yourself (e.g., append to an audit container upon each change).
- Avoid missed batches? Implement retries + catch all exceptions; monitor lease owners.

---

## References (Microsoft Docs)

(Each bullet points to the sourced statements used above.)

- Change feed features & ordering, multi-region: https://learn.microsoft.com/en-us/azure/cosmos-db/change-feed#features-of-change-feed  
- Design pattern limitations (intermediate updates, deletes, ordering): https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/change-feed-design-patterns#current-limitations  
- Change feed modes overview: https://learn.microsoft.com/en-us/azure/cosmos-db/change-feed#change-feed-modes  
- All versions & deletes mode (preview) details: https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/change-feed-modes#all-versions-and-deletes-change-feed-mode-preview  
- Change feed processor error handling (at-least-once rationale): https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/change-feed-processor#error-handling  
- Reading change feed push model & Functions retry guidance: https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/read-change-feed#read-change-feed-with-a-push-model  
- Functions Cosmos DB trigger troubleshooting (missing changes, unhandled exceptions, multiple consumers): https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/troubleshoot-changefeed-functions#common-scenarios-and-workarounds  
- Azure Functions retry policies: https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-error-pages#retry-policies  

---

## Bottom line

Yes: You can depend on seeing every create/update (and optionally delete) at least once, provided you configure leases correctly and handle errors. You cannot depend on seeing every intermediate update in latest version mode, nor on delete events without soft-delete or switching to all versions & deletes mode. Build for at-least-once, per-partition ordering, and potential replay.

If you tell me more about your downstream processing (idempotent writes? external APIs? analytics?), I can suggest concrete idempotency and dead-letter patterns next. Want that?