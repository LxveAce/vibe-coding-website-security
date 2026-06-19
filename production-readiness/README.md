# Production-readiness — what separates a vibe-coded demo from a real app

> *"You don't need all that for a simple website — that's production level of a huge company."*
> Correct — **and that's the point.** This is the menu of production-grade concerns AI skips; you
> consciously decide which your app actually needs. Every item is tagged with a tier so you neither
> over-engineer a landing page nor under-engineer a fintech.

**Tiers:** 🟢 Every app · 🔵 Once you have users/data · 🟠 At scale · 🔴 Regulated / enterprise

> Security-specific items (input validation, authz, secrets, TLS, rate limiting, dependency scanning) live
> in [`../security/`](../security/) — this doc is the testing / reliability / data / ops / governance layer.

## Categories

1. **Testing & quality engineering** (6 items)
2. **Reliability & resilience patterns** (5 items)
3. **Data, privacy & regulatory compliance** (5 items)
4. **Operations, observability & recovery** (3 items)
5. **Architecture, governance & accessibility** (3 items)

---

## Testing & quality engineering

AI-coded apps usually ship with little or no test suite, or a pile of brittle, auto-generated tests that assert implementation details and pass even when the app is broken. The model optimizes for "code that runs once," not "code that keeps working as it changes." This cluster turns a one-shot demo into a system that survives edits, traffic, and partial failures: a real test pyramid, regression nets for fixed bugs, performance and resilience testing under load and failure, coverage gates that catch untested code without becoming a vanity metric, and a human/automated review process that holds quality over time.

### 🟢 Unit, integration, and end-to-end (E2E) tests

**What it is.** A layered automated test suite: many fast unit tests on isolated functions/components, fewer integration tests that exercise one real boundary at a time (DB, queue, HTTP client), and a small number of E2E tests that drive the whole app through the UI or public API like a real user. This is Mike Cohn's/Martin Fowler's 'test pyramid.'

**Why vibe-coded apps skip it.** Vibe-coded apps often have zero tests, or the model writes only happy-path E2E/UI tests because that 'looks like testing.' It also writes tests that assert internal implementation (exact mock call args, private state) so they pass even when behavior breaks, and inverts the pyramid into a slow, flaky 'ice-cream cone' of UI tests. Generated tests frequently just re-assert what the code already does rather than the intended behavior.

**How to do it.** Adopt the pyramid: many unit tests (Vitest/Jest for JS/TS, pytest for Python, JUnit for Java, Go's testing pkg), some narrow integration tests using real dependencies in containers via Testcontainers, and a few E2E tests on critical journeys (signup, checkout) with Playwright or Cypress. Test observable behavior, not implementation; avoid over-mocking. Push tests as far down the pyramid as possible, and when a high-level test catches a bug with no failing low-level test, add the missing lower-level test (Fowler). For service-to-service boundaries, prefer consumer-driven contract tests (Pact) over broad E2E to cut flaky integration coverage. Use Playwright's auto-waiting/web-first assertions, user-facing locators, and isolated per-test data to keep E2E stable.

**When it applies.** Every app (at minimum unit + a couple of smoke/E2E tests on the money path; integration and the full pyramid become essential Once you have users/data and multiple services).

**Sources:** <https://martinfowler.com/articles/practical-test-pyramid.html> · <https://playwright.dev/docs/best-practices> · <https://docs.pact.io/>

### 🟢 Regression tests

**What it is.** Tests that lock in previously-correct behavior so future changes don't reintroduce old bugs. The highest-value pattern: every time you fix a bug, first write a failing test that reproduces it, then fix it — that test lives forever in the suite and runs on every commit.

**Why vibe-coded apps skip it.** AI assistants fix the reported symptom and move on without adding a guard test, so the same bug reappears after the next refactor or after the model 'helpfully' rewrites the area. With no CI running the suite on each change, regressions ship silently. Vibe-coded codebases also lack the discipline of 'red test first,' so fixes aren't proven.

**How to do it.** Make it a rule: for every bug, add a regression test reproducing it before fixing (a characterization test for legacy areas). Keep these in the normal suite and run the full suite automatically in CI on every push/PR (GitHub Actions, GitLab CI, CircleCI). Use snapshot/golden tests judiciously for serialized output and visual regression (Playwright's toHaveScreenshot, Percy/Chromatic) for UI. Gate merges on the suite passing via required status checks/branch protection. Speed up large suites with test selection/sharding, but never delete regression tests to 'go faster.'

**When it applies.** Every app — this is the cheapest, highest-leverage testing habit; the bug-reproduction test pays for itself the first time someone refactors.

**Sources:** <https://www.browserstack.com/guide/regression-testing> · <https://docs.github.com/en/actions/automating-builds-and-tests/about-continuous-integration> · <https://playwright.dev/docs/test-snapshots>

### 🔵 Load & stress testing

**What it is.** Performance testing that measures how the system behaves under load. Load testing = expected peak traffic; stress testing = push beyond the breaking point to find limits and how it fails; soak/endurance = sustained load for hours to surface memory leaks and resource exhaustion; spike testing = sudden surges to test autoscaling lag.

**Why vibe-coded apps skip it.** A demo that works for one user tells you nothing about 1,000 concurrent users. AI-generated apps commonly have N+1 queries, missing DB indexes, unbounded result sets, no connection pooling, and no caching — all invisible until load hits. Vibe coders rarely define latency/error budgets or run any load test before launch, then fall over on the first traffic spike.

**How to do it.** Script realistic scenarios with k6 (JS, CLI-first, low overhead), Gatling, Locust, or JMeter (many protocols, GUI-driven). Define explicit pass/fail thresholds tied to SLOs — e.g. k6 http_req_duration: ['p(95)<200'] and http_req_failed: ['rate<0.01']; a breach makes k6 exit non-zero so it gates CI. Test against a production-like environment with production-like data volumes. Run the relevant modes (load, stress, soak, spike). Watch p95/p99 percentiles (not averages), error rate, and saturation (CPU, memory, DB connections). Fix the usual culprits first: add DB indexes, eliminate N+1 queries, add caching and connection pooling.

**When it applies.** Once you have users/data — a low-traffic internal tool can skip it; anything public-facing or with a launch/marketing moment needs at least basic load + spike testing before go-live.

**Sources:** <https://grafana.com/docs/k6/latest/using-k6/thresholds/> · <https://grafana.com/docs/k6/latest/testing-guides/api-load-testing/> · <https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html>

### 🟢 Chaos engineering & resilience testing

**What it is.** Deliberately injecting failures (kill an instance, add latency, drop a dependency, fail an AZ) to verify the system degrades gracefully and recovers, building confidence it can withstand turbulent production conditions. Pioneered by Netflix (Chaos Monkey/Simian Army) and Amazon GameDays.

**Why vibe-coded apps skip it.** AI-generated code assumes every dependency is always up and fast: no timeouts, no retries with backoff, no circuit breakers, no fallbacks, no graceful degradation. A single slow downstream call can exhaust a thread/connection pool and cascade into a full outage. Vibe coders never test the unhappy path where infrastructure misbehaves.

**How to do it.** First build the resilience patterns the chaos will test: per-call timeouts, retries with exponential backoff PLUS jitter (so retries don't synchronize into a thundering herd), circuit breakers (Fowler's pattern; libs like resilience4j, Polly, or a service mesh), bulkheads, and idempotency so retries are safe. Then run controlled experiments following the Principles of Chaos: define a steady-state hypothesis (latency/error KPIs), vary real-world events, minimize blast radius, and automate/run experiments continuously. Tools: AWS Fault Injection Service, Gremlin, LitmusChaos, Chaos Mesh (Kubernetes), or toxiproxy for network faults. Begin in staging, run scheduled GameDays, and only graduate to production once safeguards exist.

**When it applies.** At scale / distributed systems — genuine fault-injection chaos is overkill for a single-server CRUD app, but the underlying resilience patterns (timeouts, retries with backoff+jitter, circuit breakers) are Every app the moment it calls any external API, DB, or third-party service.

**Sources:** <https://principlesofchaos.org/> · <https://martinfowler.com/bliki/CircuitBreaker.html> · <https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html>

### 🟠 Test coverage thresholds enforced in CI

**What it is.** A coverage tool measures which lines/branches the tests execute, and CI fails the build if coverage drops below a set threshold — protecting against new untested code sneaking in. Best applied to changed/diff lines (patch coverage), not just the total.

**Why vibe-coded apps skip it.** Two opposite failure modes: vibe-coded apps either have no coverage gate at all, or chase a 100% target that pushes the model to write assertion-free tests that execute code without verifying anything. High coverage with weak tests gives false confidence — coverage measures execution, not correctness (Goodhart's law: when a measure becomes a target, it stops being a good measure).

**How to do it.** Wire a coverage tool into CI: c8/nyc or Jest --coverage (JS), coverage.py/pytest-cov, JaCoCo (Java), go test -cover. Enforce a realistic floor (commonly ~80%, with a slightly lower hard fail like 70%) using built-in thresholds (jest coverageThreshold, pytest --cov-fail-under, JaCoCo rules) or a service like Codecov/Coveralls that can gate on patch coverage. Require branch coverage, not just line. Crucially, validate test quality with mutation testing (Stryker for JS/.NET/Scala, PIT/Pitest for Java, mutmut/cosmic-ray for Python) periodically — it mutates the code and checks your tests actually fail, exposing tests that hit lines without asserting. Treat coverage as a floor and a smell detector, never a goal that replaces code review.

**When it applies.** Once you have users/data and a team — solo prototypes can skip the gate, but any shared/long-lived codebase benefits; mutation testing is At scale or for high-stakes logic.

**Sources:** <https://about.codecov.io/blog/mutation-testing-how-to-ensure-code-coverage-isnt-a-vanity-metric/> · <https://docs.codecov.com/docs/commit-status> · <https://stryker-mutator.io/docs/>

### 🟢 Code review process & standards

**What it is.** A required human (and automated) review of every change before it merges. Google's standard: a reviewer approves once the change definitely improves the overall code health of the system — not when it's perfect — looking at design, functionality, complexity, tests, naming, comments, and style.

**Why vibe-coded apps skip it.** In solo vibe coding there is no second pair of eyes, and the AI is happy to approve its own output. Generated changes often include subtle security holes, dead code, inconsistent patterns, and missing tests that a reviewer would catch. There's also no style guide or branch protection, so anything merges.

**How to do it.** Require pull requests with at least one approving review via branch protection / required status checks (GitHub, GitLab). Adopt Google's eng-practices standard: prioritize code health over perfection, let technical facts and the style guide overrule opinion, mark non-blocking nits as 'Nit:', and comment on the code, not the person. Keep changes small for faster, better reviews. Use a PR template/checklist (tests added? security? rollback?) and a CODEOWNERS file. Layer in automation: linters/formatters (ESLint, Prettier, ruff, golangci-lint), type checks, and SAST/dependency scanning (CodeQL — free on public repos and via GitHub Advanced Security on private ones — plus Snyk, Dependabot), with AI-assisted review as a first pass — but keep a human as the final gate, since the human catches intent and design the bot misses.

**When it applies.** Every app with more than one contributor; even solo, automated review (linters, CodeQL/equivalent SAST, Dependabot) on every PR is Every app and cheap to enable.

**Sources:** <https://google.github.io/eng-practices/review/reviewer/standard.html> · <https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches> · <https://codeql.github.com/>

**Key references:** [Martin Fowler — The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html) · [Principles of Chaos Engineering](https://principlesofchaos.org/) · [Martin Fowler — Circuit Breaker](https://martinfowler.com/bliki/CircuitBreaker.html) · [Google eng-practices — The Standard of Code Review](https://google.github.io/eng-practices/review/reviewer/standard.html) · [Grafana k6 — Thresholds (pass/fail criteria & CI exit codes)](https://grafana.com/docs/k6/latest/using-k6/thresholds/) · [AWS Well-Architected — Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html) · [Codecov — Mutation Testing vs. coverage as a vanity metric](https://about.codecov.io/blog/mutation-testing-how-to-ensure-code-coverage-isnt-a-vanity-metric/) · [Google Testing Blog — Flaky Tests at Google and How We Mitigate Them](https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html) · [Pact — Consumer-Driven Contract Testing docs](https://docs.pact.io/)

---

## Reliability & resilience patterns

This cluster covers how an app behaves when its dependencies (databases, third-party APIs, networks) misbehave: failing gracefully, retrying safely, stopping the bleeding when a dependency is down, handling concurrent access without corrupting data, and caching without serving stale or inconsistent data. Vibe-coded apps almost always assume the happy path — every fetch succeeds, only one user acts at a time, and data is fresh — so they have no try/catch around external calls, retry naively (or not at all), have no idempotency so retries double-charge, do read-modify-write that loses updates under concurrency, and bolt on caching with no invalidation. These are the failures that turn a small outage into a cascading one or into corrupted/duplicated data, and they only surface under real load, real failures, and real concurrency.

### 🟢 Error handling & graceful degradation

**What it is.** Catching and handling failures from external calls (DB, APIs, file I/O) instead of letting exceptions crash the request or the process, and degrading functionality (partial results, cached/default values, read-only mode) rather than returning a blank error page when a dependency is down.

**Why vibe-coded apps skip it.** LLM-generated code is written against the happy path: an `await fetch()` or DB query with no try/catch, no timeout, and no distinction between transient and permanent errors. The model rarely adds a global error boundary or thinks about what the UI should show when a downstream service is unavailable, so one failed dependency takes the whole feature (or process) down.

**How to do it.** Wrap every external call in error handling with an explicit timeout (clients without timeouts hang threads and cause cascading failures — Google SRE). Distinguish retryable (network/5xx/timeout) from non-retryable (4xx/validation/auth) errors and only retry the former. Add a top-level error boundary/handler (Express error middleware, React Error Boundary, ASP.NET exception middleware) so unhandled errors return a clean 500 and structured log, not a stack trace. Implement graceful degradation: serve degraded/partial responses or cached data when overloaded, and shed load (return 503) before the server tips over rather than queueing unbounded work (Google SRE 'Handling Overload' / 'Addressing Cascading Failures'). Never swallow errors silently — log with context and a correlation/request ID.

**When it applies.** Every app — every app makes at least one external/DB call. Tiered load shedding and criticality-based degradation are 'At scale'.

**Sources:** <https://sre.google/sre-book/handling-overload/> · <https://sre.google/sre-book/addressing-cascading-failures/>

### 🟢 Retry logic with exponential backoff + jitter, and idempotency

**What it is.** Retrying transient failures at progressively longer, randomized intervals (capped, with a max attempt count) so the system can self-heal — combined with idempotency (an idempotency key) so that a retried request that actually succeeded the first time doesn't perform the operation twice (e.g. double-charge a card).

**Why vibe-coded apps skip it.** Vibe-coded apps either don't retry at all, or retry in a tight `for` loop with a fixed delay — which synchronizes all clients into 'thundering herd' spikes that hammer an already-struggling service. They retry non-idempotent POSTs (creating duplicate orders/charges), retry permanent 4xx errors forever, and stack retries at multiple layers, multiplying a single user action into dozens of backend calls (Google SRE: one action can become 64 attempts).

**How to do it.** Use exponential backoff with jitter, a max retry count, and a cap — prefer 'full jitter': sleep = random(0, min(cap, base * 2^attempt)) (AWS Architecture Blog). Retry only idempotent/transient failures; never retry non-idempotent operations without an idempotency key (AWS REL05-BP03). Add a server-wide retry budget / token bucket so total retries are bounded (Google SRE: e.g. cap at 60 retries/min, then fail fast) and retry at only ONE layer of the stack. For mutating POST endpoints, accept a client-generated Idempotency-Key (UUID v4): the server stores the response (status + body) for that key and replays it on retry, regardless of whether the first attempt succeeded or failed — Stripe retains keys at least 24h; GET/DELETE are idempotent by definition and don't need keys. Don't hand-roll this — use battle-tested libraries: AWS SDK retry modes (standard/adaptive), resilience4j (Java), Polly (.NET), tenacity (Python), got/p-retry (Node).

**When it applies.** Retry+backoff+jitter: every app that calls a network/DB. Idempotency keys: 'Once you have users/data' — mandatory for any payment, order, or money-movement / mutating endpoint that clients can retry.

**Sources:** <https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/> · <https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_mitigate_interaction_failure_limit_retries.html> · <https://docs.stripe.com/api/idempotent_requests> · <https://sre.google/sre-book/addressing-cascading-failures/>

### 🟠 Circuit breakers & fallback behavior

**What it is.** A wrapper around a remote call that 'trips open' after a failure threshold so subsequent calls fail fast (without waiting on timeouts) instead of piling up against a dead dependency; after a reset timeout it goes 'half-open' to test one trial call, then closes if the dependency recovered. Paired with fallback behavior — serving cached data, default values, or degraded responses while open.

**Why vibe-coded apps skip it.** AI-generated code has no concept of a dependency being persistently down. Combined with naive retries, a slow/failing downstream causes every request to block on timeouts, exhausting threads/connections and cascading the outage upward — the exact failure circuit breakers exist to prevent. Vibe-coded apps also have no fallback path, so a single dependency outage becomes a total outage.

**How to do it.** Wrap risky remote calls in a circuit breaker (Martin Fowler / Nygard 'Release It!'). Configure a failure threshold (e.g. open after N failures or X% error rate), a reset/half-open timeout, and a per-call invocation timeout. Log every state change and expose breaker state for monitoring (Fowler). Provide a fallback for the open state: cached/stale data, a sensible default, a queued write for later, or a clearly-degraded UI — never an infinite spinner. Use a library, don't hand-roll: resilience4j (Java/Spring), Polly (.NET), opossum (Node), pybreaker (Python), or a service mesh (Envoy/Istio outlier detection) for infra-level breaking. Combine with bulkheads (isolated connection pools per dependency) so one slow dependency can't starve the rest.

**When it applies.** Once you have users/data — most valuable when you depend on multiple external services or microservices. A simple single-DB CRUD site can get by with timeouts + retry budgets; circuit breakers become important as the dependency graph grows ('At scale').

**Sources:** <https://martinfowler.com/bliki/CircuitBreaker.html> · <https://sre.google/sre-book/addressing-cascading-failures/>

### 🔵 Concurrency handling & race-condition prevention (locking, atomic ops)

**What it is.** Ensuring correct results when multiple requests touch the same data at once: avoiding lost updates, double-spends, and duplicate inserts via atomic database operations, optimistic locking (version columns), pessimistic locking (SELECT ... FOR UPDATE), unique constraints, and serializable transactions.

**Why vibe-coded apps skip it.** LLM code is written as if one user acts at a time. The classic anti-pattern it emits is read-modify-write: `SELECT balance` → compute in app code → `UPDATE balance = newValue`. Under concurrency two requests read the same value and the second write clobbers the first (lost update). It also checks-then-inserts ('does this email exist? no → insert') creating duplicates, and assumes app-level checks substitute for DB constraints. These bugs are invisible in single-user testing and only appear under load.

**How to do it.** Push correctness into the database. For counters/balances use a single atomic statement with a relative expression: `UPDATE accounts SET balance = balance - 10 WHERE id = ? AND balance >= 10` instead of read-modify-write. For idempotent upserts use `INSERT ... ON CONFLICT (key) DO UPDATE` (Postgres) / `INSERT ... ON DUPLICATE KEY UPDATE` (MySQL) backed by a UNIQUE constraint — the constraint is the real guarantee, the app check is just UX. Use optimistic locking (a `version` column; UPDATE ... WHERE version = ?, retry on 0 rows affected — supported natively by JPA/Hibernate, EF Core via concurrency tokens) for low-contention edits, and pessimistic locking (`SELECT ... FOR UPDATE` inside a transaction) for high-contention hot rows. Set the right isolation level (SERIALIZABLE / REPEATABLE READ) when invariants span multiple rows, and be ready to retry serialization failures. For cross-process coordination (e.g. one cron worker) use a distributed lock (Redis Redlock, Postgres advisory locks). Avoid in-process locks/mutexes as the primary defense in a multi-instance deployment — they don't span servers.

**When it applies.** Once you have users/data — the moment two requests can hit the same row concurrently (any inventory, balance, booking, like-counter, unique-username flow). A truly single-user tool can skip it, but the DB-side fixes are cheap enough to be a default.

**Sources:** <https://www.enterprisedb.com/blog/postgresql-anti-patterns-read-modify-write-cycles> · <https://vladmihalcea.com/how-to-fix-optimistic-locking-race-conditions-with-pessimistic-locking/> · <https://on-systems.tech/blog/128-preventing-read-committed-sql-concurrency-errors/>

### 🟠 Caching strategy and cache invalidation

**What it is.** Storing computed/fetched results to cut latency and load, with a deliberate policy for which pattern to use (cache-aside, write-through), how entries expire (TTL), how they're invalidated when the source changes, and how to avoid stampedes when a hot key expires.

**Why vibe-coded apps skip it.** AI-generated caching is usually 'cache forever and never invalidate', producing stale data users can't refresh, or it caches per-user/private data in a shared layer (a privacy leak after login). It also ignores the cache stampede: when a popular key's TTL expires, every concurrent request misses simultaneously and the herd hammers the database. And it conflates HTTP cache directives — e.g. uses `no-cache` thinking it means 'don't store' (it means 'revalidate before reuse'; `no-store` is the one that prevents storage).

**How to do it.** Pick a pattern explicitly: cache-aside (lazy load: read cache → on miss read DB → populate; on write, DELETE the key rather than update it, which is safer) is the common default; write-through keeps cache fresh at the cost of write latency. Always set a TTL — there is no such thing as cache-forever — and add jitter to TTLs (a rule of thumb is ~10–20% of the base TTL) so many keys don't expire at the same instant. Prevent stampedes with a per-key lock/single-flight (only one request rebuilds the entry; others wait or serve stale), stale-while-revalidate (serve the stale value instantly while refreshing in the background), or probabilistic early expiration. For HTTP/CDN layers, use correct Cache-Control: `public, max-age=…, stale-while-revalidate=…, stale-if-error=…` for cacheable content; `private` for anything user-specific after login; `no-store` (NOT `no-cache`) for truly sensitive responses; `immutable` + long max-age for content-hashed static assets (MDN). Invalidate on write via key deletion or event/tag-based invalidation; never rely solely on TTL for correctness-critical data. Use Redis/Memcached for the shared cache and never put private data in a shared cache.

**When it applies.** Once you have users/data (performance optimization — premature caching adds bugs). Stampede protection, multi-tier and CDN caching, and event-driven invalidation are 'At scale'. The privacy rule (never cache private data publicly) applies the moment you have auth.

**Sources:** <https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control> · <https://en.wikipedia.org/wiki/Cache_stampede>

**Key references:** [Google SRE Book — Handling Overload](https://sre.google/sre-book/handling-overload/) · [Google SRE Book — Addressing Cascading Failures (retry budgets, deadline propagation)](https://sre.google/sre-book/addressing-cascading-failures/) · [AWS Architecture Blog — Exponential Backoff and Jitter (full/equal/decorrelated jitter)](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/) · [AWS Well-Architected Reliability Pillar — REL05-BP03 Control and limit retry calls](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/rel_mitigate_interaction_failure_limit_retries.html) · [Stripe API — Idempotent requests (UUID v4 keys, ≥24h retention, replay on retry)](https://docs.stripe.com/api/idempotent_requests) · [Martin Fowler — Circuit Breaker (closed/open/half-open, thresholds, monitoring)](https://martinfowler.com/bliki/CircuitBreaker.html) · [MDN — Cache-Control (max-age, no-store vs no-cache, private, stale-while-revalidate, stale-if-error)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cache-Control) · [EnterpriseDB — PostgreSQL Anti-patterns: Read-Modify-Write Cycles (atomic UPDATE, SELECT FOR UPDATE)](https://www.enterprisedb.com/blog/postgresql-anti-patterns-read-modify-write-cycles) · [Vlad Mihalcea — Optimistic vs Pessimistic Locking for race conditions](https://vladmihalcea.com/how-to-fix-optimistic-locking-race-conditions-with-pessimistic-locking/) · [Wikipedia — Cache stampede (locking/single-flight, external recomputation, probabilistic early expiration)](https://en.wikipedia.org/wiki/Cache_stampede)

---

## Data, privacy & regulatory compliance

This cluster covers how an app classifies, protects, retains, deletes, and isolates personal data, plus the baseline obligations of GDPR (any EU/UK users) and HIPAA (any US health data). Vibe-coded apps almost always skip it because the LLM optimizes for "make the feature work," not "what happens to this data afterward": they dump every field a form offers into one wide table, log full request bodies (PII and all), have no delete-account path, no retention job, and a single shared dataset where a forgotten WHERE tenant_id clause leaks every customer's data. None of this shows up in a demo, but it is exactly what gets an app fined, breached, or pulled from an app store. The fixes are mostly architectural decisions made once (data inventory, tenant scoping at the data layer, retention jobs, encryption defaults) rather than features bolted on later.

### 🟢 PII handling: classification, minimization, encryption

**What it is.** Knowing exactly which fields are personal/sensitive (name, email, IP, location, government IDs, health, biometrics), collecting and keeping the minimum needed, and protecting it in transit (TLS) and at rest (disk/column/field encryption, hashing, tokenization). It is the foundation every privacy law builds on.

**Why vibe-coded apps skip it.** AI scaffolds wide tables that store everything a form can submit, log entire request/response bodies including PII, and leave 'encryption at rest' to whatever the default is. There's usually no inventory of what's sensitive, so nobody can answer 'where does SSN live?' during an audit or breach.

**How to do it.** Build a data inventory/dictionary tagging each column by sensitivity. Apply minimization: don't collect fields you don't use; truncate/tokenize where possible (store last-4 of a card, not the PAN — use a vault like Stripe/Basis Theory, never store raw PANs). Always-on TLS 1.2+/1.3 with HSTS. Encrypt at rest: full-disk plus column/field-level encryption for the most sensitive fields (Postgres pgcrypto, app-layer AEAD via libsodium/AWS KMS envelope encryption, or cloud-native TDE). Hash passwords with a memory-hard algorithm — OWASP order: Argon2id first, then scrypt, then bcrypt (PBKDF2 only where FIPS-140 is required) — never store reversibly or with plain SHA/MD5. Scrub PII from logs/analytics: mask, hash, or drop health and government identifiers per the OWASP Logging Cheat Sheet, and avoid logging full request/response bodies, tokens, or secrets. Centralize access to PII behind a narrow data layer with least-privilege DB roles.

**When it applies.** Every app (any app collecting email/password needs TLS, password hashing, and log scrubbing); field-level encryption + tokenization vaults are 'Once you have users/data' and become mandatory for 'Regulated/enterprise' (payment, health, finance).

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/User_Privacy_Protection_Cheat_Sheet.html> · <https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html> · <https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html>

### 🟢 Data retention & deletion policies (right to erasure)

**What it is.** A defined schedule for how long each data type is kept and a reliable mechanism to actually delete it — both on a timer (storage limitation) and on user request (GDPR Art. 17 right to erasure / 'right to be forgotten'). Includes cascading deletes across related tables, caches, search indexes, file/object storage, analytics, and backups.

**Why vibe-coded apps skip it.** Vibe-coded apps keep everything forever — there's no 'delete my account' flow, no TTL/retention job, and data is scattered across a primary DB, a search index, an S3 bucket, a logging pipeline, and third-party tools, so a 'delete' only touches one of them. Soft-deletes (deleted_at flag) are mistaken for real erasure.

**How to do it.** Write a retention schedule per data category and enforce it with scheduled jobs (cron/worker) that purge or anonymize expired rows. Implement a real account-deletion path that cascades across ALL stores: primary DB (use FK ON DELETE CASCADE or explicit deletes), search index, object storage, caches, queues, analytics, and downstream SaaS via their deletion APIs. For data you must retain (legal/tax/fraud) keep only what's required and document the lawful basis — Art. 17 has explicit exceptions (legal obligations, legal claims, freedom of expression/information, public-interest archiving/scientific/historical research, public health). For backups, you generally don't restore-to-delete-to-re-backup; instead document that the record is deleted from live systems and will age out of backups per the rotation schedule, and re-suppress on restore. Cryptographic erasure (destroy the per-record/per-tenant key so ciphertext is unrecoverable) is a clean way to 'delete' from immutable backups. Track and respond to erasure requests without undue delay and within the GDPR one-month window (Art. 12(3)).

**When it applies.** Every app that has accounts should offer self-service deletion; formal retention schedules + erasure SLAs are 'Once you have users/data' and legally required for 'Regulated/enterprise' / any EU-UK users.

**Sources:** <https://gdpr-info.eu/art-17-gdpr/> · <https://gdpr-info.eu/art-5-gdpr/> · <https://www.dataprotection.ie/en/individuals/know-your-rights/right-erasure-articles-17-19-gdpr>

### 🟢 GDPR compliance basics for developers

**What it is.** The EU/UK regime that applies to ANY app processing personal data of people in the EU/UK regardless of where the company is. Built on Art. 5 principles (lawfulness/fairness/transparency, purpose limitation, data minimisation, accuracy, storage limitation, integrity & confidentiality, accountability), a lawful basis for each use, data-subject rights (access, rectification, erasure, portability, objection), privacy by design/default, and Art. 32 security of processing. Fines reach up to EUR 20M or 4% of global annual turnover (whichever is higher).

**Why vibe-coded apps skip it.** AI generates features with no notion of lawful basis or consent. Typical failures: one giant pre-ticked 'I agree' checkbox bundling marketing with core service (invalid — consent must be specific, granular, opt-in), tracking/analytics cookies firing before consent, no privacy policy, no data-export or deletion endpoints, and no record of processing activities.

**How to do it.** Pick and document a lawful basis per processing purpose (consent, contract, legitimate interest, etc.). Implement granular, unbundled, opt-in consent for non-essential cookies/marketing and a real consent-management banner (e.g. a CMP) that blocks tags until consent — pre-ticked boxes are non-compliant. Build self-service data-subject-rights endpoints: export (portability, machine-readable like JSON), rectification, and deletion. Bake in privacy by design/default: minimize fields, default to the least-sharing setting, least privilege. Maintain a Record of Processing Activities and run a DPIA for high-risk processing. Put a Data Processing Agreement in place with every sub-processor (your hosting, email, analytics vendors). Comply with Art. 32: encryption/pseudonymisation, confidentiality/integrity/availability, and the ability to restore availability after an incident. Have a 72-hour breach-notification plan (Art. 33).

**When it applies.** Every app with any EU/UK users (the law is extraterritorial); the heavier machinery (DPIA, full RoPA, DPO) scales in at 'Once you have users/data' and 'Regulated/enterprise'.

**Sources:** <https://gdpr-info.eu/art-5-gdpr/> · <https://gdpr-info.eu/art-32-gdpr/> · <https://gdpr-info.eu/art-17-gdpr/>

### 🔴 HIPAA compliance basics (PHI) for developers

**What it is.** The US rule governing Protected Health Information (PHI/ePHI) — any individually identifiable health data. If your app touches PHI you're either a Covered Entity or a Business Associate and must meet the Security Rule's administrative, physical, and technical safeguards (access controls, audit controls, integrity, person/entity authentication, transmission security) plus the Privacy and Breach Notification Rules.

**Why vibe-coded apps skip it.** Founders assume 'we use AWS so we're HIPAA compliant' — but you must sign a BAA with every vendor that touches PHI (AWS, your DB host, email, SMS, analytics) and most consumer SaaS won't sign one. Vibe-coded health apps log PHI, email it in plaintext, lack audit trails, and have no unique per-user IDs or access logging.

**How to do it.** Sign a Business Associate Agreement with EVERY sub-processor handling PHI; drop any vendor that won't. Encrypt ePHI in transit (TLS 1.2+, prefer 1.3) and at rest (AES-256; align to NIST SP 800-111 at rest, SP 800-52 in transit) — encryption is technically 'addressable,' but encrypting to the HHS/NIST standard is what grants the breach-notification SAFE HARBOR (encrypted PHI is not 'unsecured'), so treat it as mandatory and protect the keys. Access controls: unique user IDs, least privilege, MFA (prefer TOTP/WebAuthn over emailed codes), automatic logoff, role-based PHI access. Audit controls: tamper-evident, append-only logs of who accessed which record when (and never put PHI in the log message itself). Integrity controls: hashing/versioning to detect alteration. Authentication: SSO/mTLS for service-to-service. Run a documented risk analysis and keep policies, training, and a breach-notification process (notify affected individuals without unreasonable delay and no later than 60 days). Minimum-necessary principle: surface only the PHI a role needs.

**When it applies.** Regulated/enterprise — but it is non-negotiable from day one for ANY app that creates, receives, stores, or transmits PHI in the US, even a tiny MVP.

**Sources:** <https://www.hipaajournal.com/hipaa-encryption-requirements/> · <https://www.kiteworks.com/hipaa-compliance/hipaa-encryption-requirements-safe-harbor-guide/> · <https://www.accountablehq.com/post/hipaa-compliance-for-developers-requirements-technical-controls-and-step-by-step-checklist>

### 🔴 Multi-tenancy & data isolation (tenant-scoped access)

**What it is.** In any SaaS where multiple customers (tenants) share infrastructure, every query, cache key, file path, and background job must be scoped so tenant A can never read or write tenant B's data. Isolation can be separate databases, separate schemas, or shared tables with a tenant_id column guarded by Row-Level Security.

**Why vibe-coded apps skip it.** AI writes queries like SELECT * FROM orders WHERE id = :id with no tenant filter, deriving tenant from a client-supplied header or URL param that an attacker can change (a cross-tenant IDOR). One missing WHERE tenant_id leaks the whole customer base — a top SaaS breach pattern, invisible in single-tenant testing.

**How to do it.** Derive tenant context from the authenticated session/verified JWT claims, never from client-supplied input — 'never trust client-supplied tenant IDs without validation.' Enforce isolation at the DATA layer, not just the API: use PostgreSQL Row-Level Security with a policy like USING (tenant_id = current_setting('app.current_tenant')::uuid) set per request/connection, so even a buggy query can't escape the tenant. Add tenant_id to every table, every composite key/index, every cache key, and every object-storage path; validate that a fetched resource's tenant_id matches the session before returning it. Centralize this in a tenant-aware repository/ORM scope or middleware so developers can't forget it. For high-sensitivity or regulated tenants, escalate to schema- or database-per-tenant. Test with automated cross-tenant access checks (attempt to read another tenant's IDs and assert 403/404).

**When it applies.** Every multi-tenant app from day one — retrofitting tenant isolation after a leak is brutal. Schema/DB-per-tenant isolation is 'At scale' / 'Regulated/enterprise'.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Multi_Tenant_Security_Cheat_Sheet.html> · <https://aws.amazon.com/blogs/database/multi-tenant-data-isolation-with-postgresql-row-level-security/> · <https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html>

**Key references:** [OWASP User Privacy Protection Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/User_Privacy_Protection_Cheat_Sheet.html) · [OWASP Password Storage Cheat Sheet (Argon2id/scrypt/bcrypt)](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html) · [OWASP Multi-Tenant Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Multi_Tenant_Security_Cheat_Sheet.html) · [OWASP Logging Cheat Sheet (PII in logs)](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) · [GDPR Art. 5 — Principles relating to processing of personal data](https://gdpr-info.eu/art-5-gdpr/) · [GDPR Art. 17 — Right to erasure ('right to be forgotten')](https://gdpr-info.eu/art-17-gdpr/) · [GDPR Art. 32 — Security of processing](https://gdpr-info.eu/art-32-gdpr/) · [HIPAA Encryption Requirements (HIPAA Journal)](https://www.hipaajournal.com/hipaa-encryption-requirements/) · [Multi-tenant data isolation with PostgreSQL Row Level Security (AWS)](https://aws.amazon.com/blogs/database/multi-tenant-data-isolation-with-postgresql-row-level-security/)

---

## Operations, observability & recovery

This cluster covers what happens after an AI-coded app ships: proving who did what (audit trails), defining how much downtime and data loss you can tolerate (RTO/RPO), and being able to actually get back online (DR + tested backups). Vibe-coded apps almost universally treat logging as console.log debugging output, have never defined a single recovery objective, and rely on a single managed database with no tested restore path. The result is that the first real incident — a ransomware event, a bad migration, a dropped table, or a fraud dispute — becomes unrecoverable or unprovable, because logs are mutable and gone, and "the backup" was never restored even once. The fixes are cheap and mostly configuration, but they must be decided deliberately, not assumed.

### 🟢 Audit trails & tamper-evident logging

**What it is.** An audit trail is an append-only, attributable record of security- and business-significant events (logins, access-control decisions, data create/update/delete and exports, privilege and user-admin changes, high-value transactions) capturing who did what, to what, from where, and when. Tamper-evident logging adds integrity protection so any alteration or deletion of those records is detectable. This is distinct from ordinary application/debug logs.

**Why vibe-coded apps skip it.** AI-generated apps emit unstructured console.log/print lines to stdout with no actor, no standard timestamp, and no integrity. They log secrets (passwords, session IDs, access tokens, card data) that OWASP explicitly says never to log, and they store 'audit' rows in the same app database the app can freely UPDATE/DELETE — so a compromised app account or a buggy migration silently rewrites history. Models also conflate debug logs with audit trails and never separate them.

**How to do it.** Separate security/audit logging from app logs. Log the OWASP event set (login success/failure with user context, access-control failures, server-side input-validation failures, data add/modify/delete/export, admin actions, sensitive-data access) and NEVER log passwords, session IDs, access tokens, encryption keys, or cardholder data (hash/pseudonymize identifiers). Use structured logging (JSON) with a stable schema and align event names/fields to the OWASP Logging Vocabulary (e.g. authn_login_success[:userid], plus datetime/appid/event/level/source_ip). Make storage append-only: a write-only DB account with no UPDATE/DELETE on the audit table, or ship to WORM/immutable storage (AWS S3 Object Lock in Compliance mode, Azure Immutable Blob). Add tamper-evidence with a SHA-256 hash chain (each record stores hash(previous_hash + this_record)) so any insertion/edit/deletion breaks the chain and is detectable on verification. Forward logs off-box to a separate, access-restricted system (CloudWatch Logs, an ELK/OpenSearch stack, Datadog, or a managed SIEM) over TLS, and alert on logging gaps (detect when logging stops). Restrict and review read access; encode/escape log fields to prevent log injection. Pair logs with monitoring/alerting per OWASP A09 — logs nobody reviews don't help during an incident.

**When it applies.** Every app (structured logs + don't log secrets + ship logs off the box). Tamper-evident hash chains, WORM storage, and full who-did-what audit trails are Regulated/enterprise (SOC 2, HIPAA 45 CFR 164.312(b), PCI DSS), and also warranted Once you have users/data handling money or PII where disputes and breach forensics matter.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html> · <https://owasp.org/Top10/2025/A09_2025-Security_Logging_and_Alerting_Failures/> · <https://cheatsheetseries.owasp.org/cheatsheets/Logging_Vocabulary_Cheat_Sheet.html>

### 🟢 RTO and RPO — definitions & how to set them

**What it is.** Two distinct recovery targets, set by the business, that drive your DR design. RTO (Recovery Time Objective) is the maximum acceptable delay between interruption of service and restoration of service — i.e. how long you can be down. RPO (Recovery Point Objective) is the maximum acceptable time after the last good data recovery point — i.e. how much data, measured in time, you can afford to lose (an RPO of 1 hour means losing up to the last hour of data is tolerable). RTO is about downtime; RPO is about data loss — they are not interchangeable.

**Why vibe-coded apps skip it.** Vibe-coded projects never define either number, so recovery is improvised under pressure. When the topic comes up, RTO and RPO get conflated. Teams also pick fantasy targets (zero downtime, zero data loss) that their single-region, single-database, daily-snapshot setup cannot deliver, or pick targets far stricter than the business needs — paying for complex multi-region failover an internal CRUD tool doesn't warrant. AWS explicitly lists 'select arbitrary recovery objectives' and 'select unrealistic recovery objectives such as zero time to recover or zero data loss' as anti-patterns; the numbers should come from business impact analysis, not vibes.

**How to do it.** Run a lightweight business-impact analysis per workload and answer AWS Well-Architected REL13-BP01's questions: max tolerable downtime before unacceptable impact (-> RTO), max tolerable data loss (-> RPO), financial/reputational/operational/regulatory impact, dependencies (your RTO/RPO can't beat your downstream dependencies'), and any contractual/SLA or compliance obligations. Build a tiers matrix (critical/high/medium/low) each with a target RTO and RPO, assign every workload to a tier, and have business and technical owners reconcile what's needed vs. achievable. Then map targets to technique: RPO is driven by backup/replication frequency (nightly snapshot ≈ 24h RPO; continuous/PITR replication ≈ seconds-to-minutes); RTO is driven by how fast you can stand infrastructure back up (IaC + automation, warm standby, etc.). Write the numbers down, treat them as a contract, and validate them with an actual restore test (see DR item) — an untested RTO is a guess.

**When it applies.** Every app should write down at least a one-line RTO/RPO (even 'RTO 24h, RPO 24h, restore from nightly backup' is a decision). Tiered matrices, sub-hour RPO via PITR/replication, and minutes-RTO architectures are At scale / Regulated where downtime or data loss has real financial, contractual, or compliance cost.

**Sources:** <https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_objective_defined_recovery.html> · <https://aws.amazon.com/blogs/architecture/disaster-recovery-dr-architecture-on-aws-part-i-strategies-for-recovery-in-the-cloud/>

### 🟢 Disaster recovery (DR) plan & backups (3-2-1, tested restores)

**What it is.** A documented, tested plan plus backups that let you meet your RTO/RPO after data loss, corruption, ransomware, region outage, or fat-fingered deletes. The 3-2-1 rule: keep 3 copies of data, on 2 different media/devices, with 1 copy off-site. Modern extension 3-2-1-1-0 adds 1 immutable/air-gapped (offline) copy and 0 errors (every backup verified by a restore). Critically, a backup that has never been restored is not a backup.

**Why vibe-coded apps skip it.** AI-coded apps typically depend on a single managed database in one region with, at best, the provider's default automated snapshots — no off-site/cross-account copy, no immutability, and no restore ever attempted. They have no runbook, so recovery is invented during the outage. AWS lists the exact failure modes: 'assuming that a backup exists,' 'assuming the time to restore falls within the RTO,' and restoring 'without using a runbook.' Common consequences: backups live in the same account/region/credentials that an attacker or bad deploy compromises (so ransomware encrypts the backups too); 'backup exists' is assumed but is corrupt, incomplete, or far slower to restore than realized; and SaaS data (Microsoft 365, Stripe, auth provider) is wrongly assumed to be backed up by the vendor.

**How to do it.** Implement 3-2-1: at least one off-site copy in a different region AND a different account/credential boundary from production. Make one copy immutable/air-gapped so ransomware can't alter it — AWS S3 Object Lock (Compliance mode), Azure Immutable Blob, or true offline media — this is the single highest-value upgrade against ransomware double-extortion. Match cadence to RPO: nightly snapshots for ~24h RPO; enable point-in-time recovery (RDS/Aurora PITR, DynamoDB PITR) for minutes-to-seconds RPO. Choose a DR strategy to match RTO/RPO and budget, cheapest to most expensive: Backup & Restore (highest RTO/RPO, lowest cost) -> Pilot Light -> Warm Standby -> Multi-site Active/Active (lowest RTO/RPO, highest cost). Define infrastructure as code (CloudFormation/CDK/Terraform) so you can rebuild fast. THEN test restores on a schedule, automated (per AWS REL09-BP04): restore to a clean environment, validate data integrity (checksums, row counts, latest record present, RPO met), and time the restore against your RTO; alert stakeholders on failure (the AWS Backup + Lambda/Step Functions + EventBridge + SNS automation is a documented pattern). Write a runbook with roles, steps, and contacts; review after each test. Don't forget to back up SaaS/third-party data you depend on.

**When it applies.** Every app needs automated backups + at least one off-site copy + one real restore test. Immutable/air-gapped copies (3-2-1-1-0) and a written, periodically rehearsed DR plan are Once you have users/data (especially money/PII or ransomware exposure). Pilot Light / Warm Standby / Multi-site active-active and automated continuous restore validation are At scale / Regulated where downtime cost justifies the spend.

**Sources:** <https://www.backblaze.com/blog/the-3-2-1-backup-strategy/> · <https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_backing_up_data_periodic_recovery_testing_data.html> · <https://aws.amazon.com/blogs/architecture/disaster-recovery-dr-architecture-on-aws-part-i-strategies-for-recovery-in-the-cloud/>

**Key references:** [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) · [OWASP Top 10 2025 — A09 Security Logging & Alerting Failures](https://owasp.org/Top10/2025/A09_2025-Security_Logging_and_Alerting_Failures/) · [OWASP Logging Vocabulary Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Vocabulary_Cheat_Sheet.html) · [AWS Well-Architected REL13-BP01 — Define recovery objectives (RTO/RPO)](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_planning_for_recovery_objective_defined_recovery.html) · [AWS Well-Architected REL09-BP04 — Periodic recovery to verify backup integrity](https://docs.aws.amazon.com/wellarchitected/latest/framework/rel_backing_up_data_periodic_recovery_testing_data.html) · [AWS Disaster Recovery Architecture, Part I — Recovery strategies (Backup/Restore, Pilot Light, Warm Standby, Multi-site)](https://aws.amazon.com/blogs/architecture/disaster-recovery-dr-architecture-on-aws-part-i-strategies-for-recovery-in-the-cloud/) · [Backblaze — The 3-2-1 Backup Strategy](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/)

---

## Architecture, governance & accessibility

This cluster covers the connective tissue that keeps an app maintainable and usable as it grows beyond the original prompt: a shared picture of how the system fits together (C4 diagrams), a durable record of *why* the big technical bets were made (ADRs), and a baseline of accessibility (WCAG 2.2) so the UI works for keyboard, screen-reader, low-vision, and motor-impaired users. Vibe-coded apps skip all three because an LLM optimizes for code that runs *now*, not for the human-readable context, decision history, or semantic markup that future maintainers and assistive technology depend on. The result is opaque architecture nobody can reason about, undocumented decisions that get silently reversed, and inaccessible div-soup UIs that are both a usability failure and, increasingly, a legal liability (the EU's European Accessibility Act has been enforceable since 28 June 2025).

### 🟢 Architecture diagrams (C4 model)

**What it is.** The C4 model is a lightweight, notation-independent way to draw software architecture at four nested zoom levels: System Context (your system + users + external systems), Container (deployable apps/services and data stores and how they talk), Component (the major building blocks inside a container), and the optional Code level (classes/functions). It gives a team one shared mental map at multiple altitudes.

**Why vibe-coded apps skip it.** AI-generated apps have no diagram artifact at all — the 'architecture' lives implicitly in scattered files and the model's transient context, so no human can see the big picture, the trust boundaries, or what talks to what. As the codebase grows by accretion of prompts, nobody can answer 'what are the moving parts?' without reading every file.

**How to do it.** Start with just the two diagrams the c4model.com site says are sufficient for most teams: a System Context diagram and a Container diagram — that alone captures most of the value. Keep them as diagrams-as-code so they version with the repo and don't rot: use Structurizr DSL, Mermaid's C4 diagram support, the PlantUML C4 macros (C4-PlantUML), or Likec4. Treat 'Container' as 'a separately deployable/runnable thing' (a SPA, an API service, a database, a Lambda) — NOT a Docker container; the names collide. Skip the Code level entirely or generate it on demand from the IDE rather than hand-maintaining it. Label every arrow with a purpose and protocol (e.g. 'reads orders via HTTPS/JSON').

**When it applies.** Every app benefits from a one-page Context + Container diagram (cheap, high-leverage onboarding doc). Component-level diagrams and rigorous upkeep are 'Once you have a team / multiple services' — a solo static site does not need the full model.

**Sources:** <https://c4model.com/abstractions> · <https://c4model.com/diagrams>

### 🟢 ADRs — Architecture Decision Records

**What it is.** An ADR is a short markdown file capturing one architecturally significant decision: its Title, Status (proposed/accepted/rejected/deprecated/superseded), Context (the forces and problem), Decision (what was chosen), and Consequences (the resulting trade-offs, good and bad). The collection forms a decision log living in the repo, usually under docs/adr/ numbered 0001, 0002, ….

**Why vibe-coded apps skip it.** An LLM makes hundreds of consequential choices (this database, that auth flow, this state library) but records zero rationale. Six weeks later nobody — human or AI — knows why Postgres over DynamoDB, or that a 'weird' workaround exists for a real constraint, so decisions get blindly reversed and the same debates repeat. The 'why' is the single most expensive thing to reconstruct after the fact.

**How to do it.** Adopt Michael Nygard's original 5-section format (his 2011 post popularized the practice), or MADR (Markdown Any Decision Records) if you want a richer template with considered options. Store ADRs next to the code in docs/adr/. Scaffold and number them with a tool: adr-tools (the original CLI: `adr new "Use Postgres"`, `adr new -s 5 "..."` to supersede #5), or Log4brains to publish them as a searchable static site. Make ADRs immutable: never edit an accepted decision — instead write a new ADR that supersedes it and flip the old one's status to 'superseded by 0012'. Trigger an ADR whenever a choice is hard to reverse, affects multiple parts of the system, or surprised someone. Add 'write an ADR for X' to your PR checklist so the practice survives.

**When it applies.** Every app should ADR its handful of foundational, hard-to-reverse choices (datastore, auth model, hosting, core framework). Disciplined per-decision ADRs across a backlog are 'Once you have a team' — they exist to transfer context between people and across time.

**Sources:** <https://adr.github.io/> · <https://github.com/joelparkerhenderson/architecture-decision-record>

### 🟢 Web accessibility (WCAG 2.2, ARIA, semantic HTML, keyboard nav, contrast)

**What it is.** Accessibility means the app is usable by people relying on screen readers, keyboard-only navigation, magnification, or with low vision / motor / cognitive impairments. WCAG 2.2 (a W3C Recommendation, Oct 2023) is the standard, organized by the POUR principles (Perceivable, Operable, Understandable, Robust) at conformance levels A, AA, AAA. AA is the practical and commonly-required legal target. It builds on semantic HTML, correct ARIA only where needed, full keyboard operability, and sufficient color contrast.

**Why vibe-coded apps skip it.** LLMs emit div/span soup with onClick handlers instead of native <button>/<nav>/<main>, so screen readers announce nothing and the Tab key can't reach controls. They also over-apply ARIA to patch this — but 'no ARIA is better than bad ARIA': WebAIM's survey of one million home pages found pages WITH ARIA averaged ~41% MORE detected errors. Generated UIs routinely ship low-contrast 'aesthetic' gray text, focus styles stripped by `outline: none`, custom dropdowns with no keyboard support, and tiny tap targets — none of which show up when you only eyeball it with a mouse.

**How to do it.** 1) Semantic HTML first — the first rule of ARIA is don't use ARIA if a native element exists; use <button>, <a>, <nav>, <main>, <label>, real <input>s, and one <h1> with logical heading order (these give keyboard and screen-reader support for free). 2) Keyboard nav — every interactive element must be reachable and operable by Tab/Enter/Space/Esc, in a logical order, with a VISIBLE focus indicator (never `outline:none` without a replacement); honor WCAG 2.2's 2.4.11 Focus Not Obscured (Minimum) & 2.4.13 Focus Appearance. 3) Contrast — meet SC 1.4.3 Contrast (Minimum): 4.5:1 for normal text, 3:1 for large text and UI components; verify with axe DevTools, Lighthouse, or WebAIM's contrast checker. 4) New WCAG 2.2 wins that are easy to botch: 2.5.8 Target Size (Minimum) 24x24 CSS px, 2.5.7 Dragging Movements need a single-pointer alternative, 3.3.8 Accessible Authentication (Minimum) — do NOT require a cognitive-function test (no memorize-this-code, no puzzle); allow password-manager autofill and paste, or offer a no-cognitive-test method like passkeys/WebAuthn/OAuth. 5) Add programmatic names: alt text on images, aria-label on icon-only buttons, programmatically-associated form labels and error messages. 6) Automate in CI with axe-core / Pa11y / Lighthouse, but always also test manually with the keyboard alone and a screen reader (NVDA, VoiceOver). Note: automated tools catch only a minority of issues (Deque's own figure is ~57% for a first audit; independent sources cite ~30-50%) — manual testing is non-negotiable for things like logical focus order, meaningful alt text, and helpful error messages.

**When it applies.** Every app — semantic HTML, keyboard operability, visible focus, and AA contrast are baseline quality, not extras, and have low cost if done from the start. Formal WCAG 2.2 AA conformance, audits, and a VPAT/ACR become mandatory for Regulated/enterprise & public-sector apps (ADA/Section 508 in the US; EN 301 549 / the European Accessibility Act, enforceable since 28 June 2025, in the EU).

**Sources:** <https://www.w3.org/WAI/WCAG22/quickref/> · <https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA> · <https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html>

**Key references:** [C4 model — Abstractions](https://c4model.com/abstractions) · [C4 model — Diagrams (System Context + Container sufficient for most teams)](https://c4model.com/diagrams) · [Architectural Decision Records (adr.github.io)](https://adr.github.io/) · [ADR examples & templates (joelparkerhenderson)](https://github.com/joelparkerhenderson/architecture-decision-record) · [W3C WCAG 2.2 Quick Reference (How to Meet)](https://www.w3.org/WAI/WCAG22/quickref/) · [MDN — ARIA (first rule of ARIA; 'no ARIA is better than bad ARIA'; WebAIM 41% stat)](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA) · [W3C Understanding SC 3.3.8 Accessible Authentication (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/accessible-authentication-minimum.html) · [Deque — Automated Accessibility Coverage Report (~57% first-audit detection)](https://www.deque.com/automated-accessibility-coverage-report/)

---

