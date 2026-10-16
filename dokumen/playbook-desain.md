# System Design Playbook — my approach, in easy words

This is how I solve common senior full stack design problems. Answers default to this best practice; my own projects come in only when they ask about my experience. It is my engineering approach, not a record of past projects: say it in present tense ("I'd…", "My rule is…"). When it fits, anchor it in one real story from my story bank. Keep the easy-word rules: never say "idempotency"; say "a unique request key, so the same request only runs once" or "safe to retry".

## Flash sale (limited stock, huge spike at a fixed time)
- Assumptions: for example 10,000 items, hundreds of thousands of users arriving in the first seconds, no overselling allowed, and the payment must finish within a few minutes.
- Before the sale: serve the product page from a CDN and cache, load the stock into Redis, and warm everything up. Put a waiting room or token gate in front if traffic is far above capacity.
- Buying: one atomic step in Redis decides who gets an item (decrement the stock only if it is above zero, in one Lua script), plus a per-user limit. Users who lose get a fast "sold out" answer, without touching the database.
- The winner gets a reservation with a short time limit (for example 10 minutes). The order is written in the background through a queue, with a unique request key so retries never create two orders. The database keeps the final truth with a conditional update (stock only goes down if it is above zero).
- If payment fails or the time limit passes, the reservation is released and the stock goes back. A check-and-fix job compares Redis with the database after the sale.
- The hardest part is overselling under heavy contention, and the hot stock key. The trade-off: Redis is fast, but the database must stay the source of truth, so the two must be checked against each other. For extreme load, split the stock into several counters.
- Protection: rate limiting per user and IP, bot checks, and a circuit breaker so the payment provider is not flooded.
- Validate with a load test at several times the expected peak, and watch p95 latency, error rate, queue length, oversell count (must be zero) and the gap between Redis and the database.

## Walking through my own take-home or HackerRank design
- Start with the goal and the two or three requirements that drove the design.
- Then the main flow in one pass (request path), then the one part I'm most careful about (consistency or the bottleneck), then what I'd improve with more time.
- When challenged ("what if Redis goes down?", "what if two requests arrive at the same time?"), answer with the failure mode, what the design does today, and the fix. It is fine to say "That's a gap in my current design; I'd fix it by…".

## Duplicate payments / double submit (e.g. "Pay Invoice" clicked twice)
- First, reproduce it: look in the logs for two payment requests for the same invoice a few milliseconds apart, and in the payments table for two rows with the same invoice ID.
- Frontend: disable the button after the first click and show a loading state. This only helps the experience; double taps, retries and slow networks still get through.
- The key is per payment attempt, not per invoice. The checkout creates one unique request key when the payment page opens. Retries of that attempt reuse the same key. A new, deliberate attempt after a failure gets a new key.
- Backend: every payment request must carry the key. The database is the final guard: a unique constraint on the key, and inside one transaction I lock the invoice row and check its status. If the invoice is already paid, I return the original receipt instead of charging again.
- Across services: the same key travels with the request through every service and to the payment provider, so the provider also refuses a second charge. Each service remembers the keys it has already processed. Events leave through an outbox table, so the database and the message queue never disagree.
- Monitoring: count duplicate attempts and blocked charges, and alert on spikes.

## A pipeline that slows down as usage grows (OCR → chunking → embedding → LLM)
- Measure before changing anything: time per stage (p95), queue length per stage, failure rate, and CPU/GPU use. The slowest stage with the longest queue is the bottleneck.
- Give each stage its own queue and its own workers, so I can scale only the slow stage by adding workers there.
- Make the heavy stages cheaper: batch embedding calls, skip work for documents that didn't change (compare a content hash), and cap workers per GPU so they don't fight for memory.
- Separate interactive work from bulk work: user questions get a fast lane; bulk re-indexing runs in a slow lane or at night.
- Scale workers automatically by queue length, and set a target like "a new document is searchable within N minutes".

## High concurrency (e.g. 10,000 users at once)
- Stateless API servers behind a load balancer, so I scale by adding more servers.
- Cache hot reads in Redis; indexes on every query path; read replicas when reads dominate; a connection pool so the database isn't flooded.
- Writes in transactions with a unique request key; slow work goes to a background queue.
- Timeouts everywhere, retries with backoff, a circuit breaker for slow dependencies.
- Load test step by step and watch p95 latency and error rate.

## Real-time data to the browser
- Push updates (WebSocket or server-sent events) instead of heavy polling.
- Aggregate and downsample on the server; send only what the screen can show; keep raw data for drill-down.

## Many devices / IoT at scale
- MQTT at the device edge, Kafka in the middle, keyed by device ID so each device stays in order; add consumers to scale.
- Keep latest state in Redis, history in a time-series store.
- Mark a device offline after a few missed heartbeats; on reconnect it sends a full snapshot and a check-and-fix job repairs gaps; reconnect with random delay to avoid a storm.

## Database growth
- Find slow queries first; add the right index; avoid N+1 queries.
- Archive or partition old data by time; read replicas for reports; keep heavy reports off the main database.
- Change the schema in small, backward-compatible steps.

## Safe releases
- Feature flags, gradual rollout to a small group first, quick rollback.
- Database changes that work with both the old and the new code.
- Watch errors and latency after each step; stop the rollout if they rise.

## Rate limiting and abuse
- Limit per user or API key at the gateway (token bucket), return a clear "try again later" response, and protect expensive endpoints first.

## Caching
- Cache what is read often and changes rarely; set a short expiry; clear or update the cache when the data changes; watch the hit rate.

## Failure handling for common patterns (say this whenever I name the pattern)
- Background queue / workers: a worker can crash mid-job → the job becomes visible again after a timeout; a message can arrive twice → the worker is safe to retry (keyed by job ID); a job keeps failing → retry 3–5 times with backoff, then move it to a dead-letter queue and alert; the queue grows faster than workers → alert on queue length and add workers.
- Cache: the cache goes down → read from the database with a timeout and protect it with a rate limit; stale data → short expiry and clear on write; many requests miss at once → only one request rebuilds the value, the others wait or get the old value.
- Retries: retries can make an outage worse → exponential backoff with jitter, a retry budget, and only for errors that can succeed later (timeouts, 503), never for bad requests.
- Read replicas: replicas lag → read your own writes from the primary; send only lag-tolerant reads (reports, lists) to replicas.
- Distributed lock: the lock holder dies → the lock has an expiry; a slow holder can outlive the lock → protect writes with a version number (fencing token).
- Outbox: the publisher crashes after writing the outbox row → it retries from the table, so consumers must handle duplicates.
- Saga (multi-service workflow): a later step fails → run the compensating steps in reverse order; record each step's state so a restart continues correctly.
- Circuit breaker: a dependency is slow → fail fast after N errors, return a fallback, and probe again after a cool-down.
- Webhooks: the receiver is down or slow → retry with backoff for hours, sign the payload, and the receiver handles duplicates by event ID.

## Back-of-envelope numbers (quantify every design)
- Traffic: concurrent users × requests per user per second. Example: 10,000 active users, one request every 5 seconds each → about 2,000 requests per second; plan for a 3× peak → about 6,000.
- Storage: events per second × size × seconds per day. Example: 625 small messages per second × 200 bytes ≈ 10 GB per day.
- Targets I name: p95 latency (e.g. under 200 ms for reads), error rate (e.g. under 0.1%), recovery time (e.g. back within 5 minutes), timeouts (e.g. 2 seconds per call), retry limit (3–5 attempts).
- Rough capacity: one Redis node handles on the order of 100,000 simple operations per second; one Postgres primary handles thousands of simple writes per second, depending on hardware and indexes. Always say "roughly" and confirm with a load test.

## Database transactions (easy words)
- ACID: a transaction is all or nothing (atomic), keeps rules true (consistent), doesn't see other unfinished work (isolated), and survives a crash once committed (durable).
- Isolation levels: Read Committed is the Postgres default — no dirty reads, but a value can change between two reads. Repeatable Read keeps the same snapshot during the transaction. Serializable acts as if transactions ran one by one; the database may abort one, so the app must retry.
- Classic problems: lost update (two people read the same stock and both write) → fix with a row lock (SELECT … FOR UPDATE), an atomic update (stock = stock - 1 WHERE stock > 0), or a version column (optimistic locking, retry on conflict). Write skew (two transactions each check a rule and both pass) → Serializable or lock the rows that the rule depends on.
- Pessimistic vs optimistic locking: lock first when conflicts are frequent (hot rows like stock); use a version check when conflicts are rare (most profile or settings updates).
- Deadlocks: two transactions lock rows in a different order → always lock in the same order, keep transactions short, and retry when the database reports a deadlock.
- Keep transactions short: no network calls (payment providers, emails) inside a transaction; long transactions hold locks and exhaust the connection pool.
- Across services there is no shared transaction: use the outbox table for "save and publish", and a saga with compensating steps for multi-service workflows.
- Money and counters: use exact types (numeric or integer cents), a unique request key on writes, and a constraint in the database as the last guard.

## Coding round: how I talk while I code
- Restate the problem in one sentence and ask about input size, edge cases and expected output.
- Walk through one small example by hand, then say the simple solution and its time and space complexity.
- Improve it if needed (hash map, two pointers, sorting, heap, BFS/DFS), and say why it is better.
- Code in small, named functions; talk while typing; then test with the example, an empty input, one element, duplicates, and the largest size.
- Close with the complexity and one thing I'd change for production (validation, logging, tests).

## Kafka consumer lag is growing (e.g. millions of messages behind)
- Investigation first: is the consumer slow (database writes, a slow downstream call), stuck (one poison message), or just under-scaled? Check lag per partition, processing time per message, error rate, and database latency.
- Retention headroom: Kafka deletes old messages after the retention period (for example 7 days or a size limit). Compare "lag ÷ catch-up speed" with the time left before messages expire; if it's close, extend retention or move the backlog to cheaper storage before data is lost.
- Scale: consumers only scale up to the number of partitions; if all partitions are busy, add partitions (plan it, because keyed ordering changes) or make each consumer faster with batch writes.
- Backpressure: when downstream can't keep up, slow the input instead of crashing: rate-limit ingestion, use bounded queues, pause non-critical producers, and give critical topics (transactions) their own consumers so telemetry can't starve them.
- Safety: commit the offset only after the message is processed and saved; consumers are safe to retry using the event ID with a unique constraint; a message that fails repeatedly goes to a dead-letter topic after bounded retries with backoff.
- Prioritize: for heartbeats, the latest state matters most, so update the latest state first and backfill history later.
- Validate: alert on lag, on time-to-expiry of the backlog, and on dead-letter volume; autoscale consumers on lag.

## Payment request timed out and the customer retries
- One key per logical payment attempt, sent by the client in an Idempotency-Key header and reused on retries.
- Step 1, short database transaction: insert the payment row with the key (unique constraint) and status PENDING, then commit. Never keep a database transaction open while calling the payment provider.
- Step 2: call the provider and pass the same key, so the provider also refuses a double charge.
- Step 3: update the status to SUCCEEDED or FAILED; a timeout means UNKNOWN, not failed.
- Same key, different amount or invoice → reject with an error; store a hash of the request with the key.
- Two identical requests at the same time → the unique constraint lets only one insert win; the other returns "in progress" or the stored result.
- A reconciliation job asks the provider about PENDING and UNKNOWN payments every few minutes and settles them.
- Validate: zero double charges, the number of UNKNOWN payments older than 15 minutes, and provider error rate.

## Deadline pressure (PM wants 6 weeks, estimate is 8)
- Treat it as a scope problem, not a people problem; ask what business outcome must exist in week 6.
- Commit to a reduced-scope release in week 6 (not week 7): map the critical path and dependencies, cut or defer non-critical features (advanced reports, nice-to-have UI), and keep the core flow.
- Non-negotiables: payment correctness, security, and basic monitoring; these are never cut.
- Split the work by ownership: for 5 engineers, for example 2 on the core API and database, 1 on payments, 1 on the frontend, 1 on testing, release and monitoring; weekly milestones and a risk list visible to the PM.
- If the critical path still doesn't fit, raise it in week 1, not week 5.

## When a dependency fails (say this for any design)
- Redis down: reads fall back to the database with timeouts and rate limits; writes that depend on Redis (stock counters) pause instead of guessing; run Redis with a replica and automatic failover.
- Database connections exhausted: use a connection pooler, short transactions, statement timeouts, and cap the pool per service so one service can't take all connections.
- Partitioning: split data by a key that spreads load evenly (station ID, tenant ID), avoid hot keys, and keep related data on the same partition.
