# NoSQL & cache — MongoDB, Redis, DynamoDB

> The databases most often found wide-open on the internet. Auth + network isolation are non-negotiable; never expose Mongo (27017) or Redis (6379).

---

NoSQL stores and caches are among the most-breached categories for vibe-coded apps because their convenience defaults are also their failure modes: self-managed MongoDB historically shipped with auth OFF and bound to all interfaces, and Redis ships with NO password (the `default` user is `nopass ~* +@all`) — so the moment either lands on a public IP it's a freebie. In the 2017 MongoDB "apocalypse," automated scanners wiped roughly 28,000-33,000 internet-exposed, unauthenticated MongoDB databases and left Bitcoin ransom notes; the same playbook is still running today (Flare/SecurityWeek, 2024-2025: of ~3,100 fully exposed instances, ~1,416 were already wiped and replaced with a ~$500 BTC ransom note). The identical attack hits exposed Redis (FLUSHALL the whole dataset in one command, then CONFIG SET / MODULE / RDB tricks for RCE). The fixes are mostly configuration, not code: (1) NEVER expose these engines to the internet — bind to localhost/VPC, use private endpoints, and an IP allowlist that is never 0.0.0.0/0; (2) require authentication and apply least-privilege roles/ACLs/IAM per app; (3) enforce TLS in transit and encryption at rest; (4) in application code, block NoSQL operator injection ($where/$ne/$gt/$regex) by validating types and refusing client-supplied query operators; and (5) cap query results with pagination so a single request can't dump or scan the whole collection. Managed tiers (Atlas, Redis Cloud, DynamoDB) flip many defaults to safe — Atlas forces auth + TLS and starts with an empty IP access list, DynamoDB is private-by-default behind IAM and encrypted at rest — but you can still defeat them by adding 0.0.0.0/0, pasting an over-broad IAM policy, or leaking a connection string. Concrete settings, policy JSON, SQL, and CLI for each engine are below, with honest tiering. For the adjacent Supabase case (Postgres, but the canonical vibe-coded breach): tables are exposed through a public anon key and RLS is OFF until you enable it per table — the #1 cause of these leaks.

### 🟢 MongoDB: enable authentication and never bind to the public internet

**What it is.** Self-managed MongoDB (mongod) does not enable access control by default and, in many tutorial/Docker configs, binds to 0.0.0.0 (all interfaces). With no auth + a public IP, anyone can read, modify, or wipe every database. Fix: turn on access control and restrict the listening interface.

**Why it matters / why vibe-coded apps get it wrong.** This is the most-breached NoSQL misconfiguration in existence. Automated scanners hit port 27017: the 2017 campaign wiped roughly 28,000-33,000 unauthenticated, internet-exposed MongoDB databases, and the same playbook is still live (Flare/SecurityWeek 2024-2025 found ~3,100 still fully open with no auth, ~1,416 already wiped and replaced with a ~$500 BTC ransom note). The root cause MongoDB and researchers both cite: copied default/Docker/tutorial configs that bind to all interfaces with auth off, then get reused in prod. Vibe-coded apps inherit exactly these example configs.

**How.** Self-hosted: in mongod.conf set `security.authorization: enabled` (or start with `--auth`), and `net.bindIp: 127.0.0.1,<private-ip>` (NEVER 0.0.0.0 on a public host) plus a host firewall blocking 27017 from the internet. Create the first admin BEFORE enabling auth via the localhost exception: `use admin; db.createUser({user:'admin', pwd:passwordPrompt(), roles:['userAdminAnyDatabase']})`, then restart with auth on. Disable server-side JS if unused: `--noscripting`. Verify: `mongosh` from an external IP must be refused, and unauthenticated `db.runCommand({listDatabases:1})` must error. Atlas (managed): auth is mandatory and cannot be turned off — just create DB users (Database Access) with scoped roles and connect with SCRAM/X.509.

**When it applies.** Every app — for any MongoDB reachable beyond localhost. Auth + bindIp/firewall is non-negotiable before a single byte of real data lands.

**Sources:** <https://www.mongodb.com/docs/manual/administration/security-checklist/> · <https://www.mongodb.com/docs/manual/tutorial/enable-authentication/> · <https://flare.io/learn/resources/blog/mongodb-ransom> · <https://www.bleepingcomputer.com/news/security/mongodb-apocalypse-is-here-as-ransom-attacks-hit-10-000-servers/>

### 🟢 MongoDB Atlas: empty IP allowlist (never 0.0.0.0/0), private endpoints, TLS, RBAC

**What it is.** Atlas (managed MongoDB) enforces auth and TLS by default and starts with an EMPTY IP access list — nothing connects until you allow an IP. The danger is the convenience button '0.0.0.0/0 (allow access from anywhere)' that tutorials tell you to click, which re-opens the cluster to the entire internet (auth still required, but you've removed the network moat).

**Why it matters / why vibe-coded apps get it wrong.** Atlas does the hard part for you, so the only way to break it is to widen the network yourself or leak the connection string. Vibe-coded apps routinely add 0.0.0.0/0 to 'make it work from my laptop / from the deploy box', then forget. Combined with a leaked SRV connection string (committed to git, shipped in a client bundle), 0.0.0.0/0 turns a credential leak into a full breach. Free/shared tier DB users are also frequently granted broad roles like readWriteAnyDatabase — broader than most apps need.

**How.** Atlas console → Network Access → IP Access List: add only your app/egress IPs or CIDRs; delete any 0.0.0.0/0 entry. For prod on dedicated tiers (M10+), prefer a Private Endpoint (AWS PrivateLink / Azure Private Link / GCP Private Service Connect) or VPC peering so traffic never touches the public internet — note Free (M0) and Flex clusters do NOT support private endpoints or VPC peering, so on free tier rely on a tight IP allowlist. TLS is enforced (TLS 1.2+ default) — don't disable cert validation in the driver. Database Access → create a least-privilege user per app (e.g. role `readWrite` on one database, not `atlasAdmin`/`readWriteAnyDatabase`); use `authenticationRestrictions` to pin a user to a source IP. Encryption at rest is on by default; add Customer Key Management (BYOK via AWS/GCP/Azure KMS) on dedicated tiers if required.

**When it applies.** Every app uses Atlas auth+TLS+allowlist. Private endpoints/peering and BYOK KMS are 'At scale / Regulated' (dedicated tiers only).

**Sources:** <https://www.mongodb.com/docs/atlas/security/ip-access-list/> · <https://www.mongodb.com/docs/atlas/security-private-endpoint/> · <https://www.mongodb.com/docs/atlas/architecture/current/network-security/>

### 🔴 MongoDB: field-level / queryable encryption for sensitive fields

**What it is.** Beyond at-rest encryption, MongoDB supports Client-Side Field Level Encryption (CSFLE) and Queryable Encryption (QE): the driver encrypts specific fields (SSNs, tokens, PII) in your app before they're sent, so no MongoDB process — and no one with raw disk/backup access — ever sees plaintext for those fields.

**Why it matters / why vibe-coded apps get it wrong.** At-rest encryption only protects stolen disks; a leaked credential or an injection that dumps a collection still returns plaintext. For regulated data (PII/PHI/PCI), field-level encryption is what keeps the most sensitive columns useless even after a logical breach. Vibe-coded apps tend to store secrets and PII as plain BSON strings.

**How.** Configure the driver's `autoEncryption` with a KMS provider (AWS KMS / Azure / GCP / local key) and an `encryptedFieldsMap` (QE) or schema map (CSFLE) naming the fields and algorithm. Use deterministic / `queryType:'equality'` encryption for fields you must look up by exact match; use random encryption for fields you never query (max security). Keys are wrapped by a Customer Master Key in KMS; rotate them there. CSFLE schema can be enforced server-side; QE additionally supports indexed encrypted equality/range queries.

**When it applies.** Regulated/enterprise (and any app storing high-value secrets/PII). Adds key-management and query-shape constraints, so not worth it for low-sensitivity data.

**Sources:** <https://www.mongodb.com/docs/manual/core/csfle/> · <https://www.mongodb.com/docs/manual/administration/security-checklist/>

### 🟢 Redis: NOT internet-facing — protected-mode, requirepass/ACL, bind, TLS

**What it is.** Redis's trust model assumes only trusted clients on a trusted network. Out of the box it has NO authentication (the `default` user is `nopass ~* +@all`). Since 3.2 'protected-mode' is ON by default, which refuses external connections while no password is set and no bind is configured — but the instant you bind to a public interface AND set a password (or disable protected-mode 'to make it work'), you own the risk.

**Why it matters / why vibe-coded apps get it wrong.** An exposed, unauthenticated Redis is game over: a single `FLUSHALL` wipes all data, and attackers chain `CONFIG SET`/`MODULE`/RDB tricks to write files and achieve RCE. The classic vibe-coded mistake is `protected-mode no` + `bind 0.0.0.0` copied from a Stack Overflow answer, or a Docker port mapping `6379:6379` on a public host. Because protected-mode only guards the no-password case, adding a weak password while binding publicly removes the safety net entirely.

**How.** Keep `protected-mode yes`. `bind 127.0.0.1 -::1` (or a private interface only); never expose 6379 to the internet — put a host/cloud firewall in front. Always set strong auth: legacy `requirepass <64+ char secret from ACL GENPASS>`, or better, ACLs (below). Enable TLS for client/replication traffic (Redis 6+: set `tls-port`, `tls-cert-file`, `tls-key-file`, `tls-ca-cert-file`) since AUTH passwords otherwise cross the wire in plaintext. Run as the unprivileged `redis` user, not root. Managed (Redis Cloud / ElastiCache / Upstash): auth + TLS are on and the endpoint sits in a VPC/private network — keep it private, don't add public access.

**When it applies.** Every app — binding/firewall/auth applies to any Redis. TLS is 'Every app' if Redis crosses any untrusted hop; optional on a same-host loopback-only cache.

**Sources:** <https://redis.io/docs/latest/operate/oss_and_stack/management/security/> · <https://oneuptime.com/blog/post/2026-03-31-redis-how-to-configure-redis-protected-mode/view>

### 🔵 Redis: per-app ACL users with least privilege; disable dangerous commands

**What it is.** Redis 6+ ACLs let you create named users scoped to specific commands, command categories, and key patterns — instead of one shared password that can run everything. You also lock down the `default` user and remove destructive commands from app-facing users.

**Why it matters / why vibe-coded apps get it wrong.** A single `requirepass` means every service (and every attacker who gets the password) can `FLUSHALL`, `CONFIG SET`, `KEYS *` (which blocks the server), or `DEBUG`. Vibe-coded apps share one Redis and one password across web, workers, and sessions; a leak or injection then has full admin. ACLs reduce a compromised app credential to read/write a single key namespace.

**How.** Define users in redis.conf or via CLI. Lock the default user: `ACL SETUSER default off` after creating real users (or restrict it). Create a scoped app user: `ACL SETUSER app on >$(ACL GENPASS) ~app:* +@read +@write -@dangerous` (access only keys `app:*`, read/write but no admin/destructive commands). Redis 7+ supports per-pattern read/write: `%R~public:* %RW~app:*`. Persist with `ACL SAVE` / `aclfile`. Disable or rename destructive commands as defense-in-depth: `rename-command FLUSHALL ""`, `rename-command CONFIG ""`, `rename-command KEYS ""` (prefer ACL `-@dangerous`/`-@admin` over rename in 6+). Inspect with `ACL LIST` / `ACL GETUSER app`.

**When it applies.** Once you have users/data (multiple services or any multi-tenant data). A single-service throwaway cache can start with just requirepass; ACLs are the next step.

**Sources:** <https://redis.io/docs/latest/operate/oss_and_stack/management/security/acl/> · <https://redis.io/docs/latest/operate/oss_and_stack/management/security/>

### 🟢 Redis as session/token store: cache poisoning, key namespacing, validation

**What it is.** Redis is heavily used for sessions, auth tokens, rate limits, and cached responses. Two app-layer risks: (1) cache poisoning — if a cache key is built from unsanitized user/tenant input or lacks an instance/tenant prefix, an attacker can overwrite entries other users read; (2) treating the cache as trusted — reading session/token data back without re-validating it.

**Why it matters / why vibe-coded apps get it wrong.** If sessions live in a shared Redis and keys aren't namespaced per tenant/instance, one user's write can clobber another's. This is a real 2025 advisory class: Open WebUI (GHSA-3x8w-4f7p-xxc2) used bare key names like `tool_servers`/`terminal_servers` instead of instance-prefixed keys, letting an admin on one instance poison the shared Redis cache and route other instances' tool-call payloads (chat content + user identity) to an attacker-controlled server. Tokens stored in Redis must still be validated on read — Redis is fast storage, not an authority. Vibe-coded apps often concatenate raw input into keys (`'cache:'+req.query.q`) and trust whatever comes back.

**How.** Namespace every key with a fixed prefix plus a trusted, server-derived identifier: `sess:{userId}`, `cache:{tenantId}:{hash(normalizedInput)}` — never raw user strings; hash/allowlist the variable part, and apply a per-instance/per-tenant key prefix in multi-instance deployments. Set TTLs (`EX`/`PEXPIRE`) on sessions and cache entries so poisoned/stale data self-expires and tokens can't live forever. Validate/verify token integrity on read (signed/opaque token checked against source of truth), don't just trust presence in the cache. Store session IDs (random, high-entropy), not raw credentials. Isolate the session store behind a scoped ACL user so a compromised cache path can't reach session keys.

**When it applies.** Once you have users (anyone storing sessions/tokens/per-user cache in Redis). Single-tenant, non-user caches carry far less poisoning risk.

**Sources:** <https://redis.io/solutions/authentication-token-storage/> · <https://github.com/open-webui/open-webui/security/advisories/GHSA-3x8w-4f7p-xxc2>

### 🟢 DynamoDB: IAM least-privilege with item-level condition keys (dynamodb:LeadingKeys)

**What it is.** DynamoDB has no network endpoint to leave open and no password — all access is mediated by AWS IAM, and it's private/encrypted by default. Security here is entirely about writing tight IAM policies: scope actions and resources, and use DynamoDB condition keys to restrict access down to the item (partition key) and attribute level.

**Why it matters / why vibe-coded apps get it wrong.** The DynamoDB failure mode isn't an open port — it's an over-broad policy. Vibe-coded apps attach `AmazonDynamoDBFullAccess` (or `dynamodb:*` on `Resource:*`) to a Lambda/EC2 role, so a single app compromise or SSRF that grabs the role's temp creds can read, scan, and delete every table in the account. Without `dynamodb:LeadingKeys`, a multi-tenant 'users share one table' design lets any authenticated caller Scan/Query other tenants' items.

**How.** Grant a customer-managed policy scoped to specific actions on a specific table ARN — never `dynamodb:*` on `*`. For per-user/tenant item isolation, add a Condition with `dynamodb:LeadingKeys` (it represents the partition key, requires the `ForAllValues` modifier) matching the caller's identity, e.g.: `"Condition":{"ForAllValues:StringEquals":{"dynamodb:LeadingKeys":["${www.amazon.com:user_id}"]}}` (or `${graph.facebook.com:id}` / `${accounts.google.com:sub}` / a Cognito sub / `${aws:PrincipalTag/tenant}`) on Get/Query/Put/Update/Delete. CRITICAL (verbatim from AWS docs): do NOT grant `Scan` to such roles — Scan returns all items regardless of the leading keys. Restrict attributes with `dynamodb:Attributes` + force `dynamodb:Select: SPECIFIC_ATTRIBUTES` and constrain `dynamodb:ReturnValues` so writes can't echo hidden fields. Always use IAM roles (temporary creds), never long-lived access keys baked into the app/instance. Optionally pin access to a VPC with the `aws:sourceVpce` condition + a Gateway VPC endpoint so traffic never traverses the internet.

**When it applies.** Every app (least-privilege policy + roles, no full access). Item-level LeadingKeys is 'Once you have users' for any multi-tenant/shared-table design.

**Sources:** <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/specifying-conditions.html> · <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices-security-preventative.html>

### 🟢 DynamoDB: encryption at rest (KMS), no sensitive keys, private access

**What it is.** DynamoDB encrypts all tables, indexes, streams, and backups at rest by default using AWS KMS, with a choice of AWS-owned (default, no charge), AWS-managed, or customer-managed key (CMK). It has no public network surface — there is nothing to 'expose'. Remaining concerns: choosing the right key, keeping sensitive data out of key names/values, and keeping traffic off the public internet.

**Why it matters / why vibe-coded apps get it wrong.** Encryption at rest is automatic, so the gotchas are subtler: partition/sort key NAMES appear in DescribeTable and key VALUES land in CloudTrail and other logs (and AWS administrators may observe them) — so putting an email/SSN as a partition key leaks it into logs even though the table is 'encrypted'. Audit/regulated environments often need a CMK (with its own key policy and rotation) rather than the AWS-owned default. Vibe-coded apps also tend to store secrets/PII as plain attributes.

**How.** Default encryption is on — for compliance/audit control, set the table to a customer-managed KMS key (CMK) so you own rotation and the key policy. Never use sensitive data as primary-key names or values (AWS suggests generic `pk`/`sk` names); if you must key on sensitive data, use the AWS Database Encryption SDK for DynamoDB to client-side encrypt attributes before writing (you choose which attributes are encrypted/signed) — do NOT use a plain hash, which AWS notes is not sufficiently secure. Connections use TLS (HTTPS) automatically. For network isolation, access DynamoDB through a Gateway VPC endpoint and enforce it with `aws:sourceVpce` so requests can't originate from the open internet.

**When it applies.** At scale / Regulated for CMK + client-side attribute encryption; default at-rest encryption and TLS are automatic for Every app.

**Sources:** <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices-security-preventative.html> · <https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/EncryptionAtRest.html>

### 🟢 NoSQL injection: block client-supplied query operators ($where, $ne, $gt, $regex)

**What it is.** NoSQL injection happens when untrusted input is interpreted as query structure rather than data. In MongoDB, a JSON body like `{"password": {"$ne": null}}` or `{"price": {"$gt": 0}}` turns an equality check into 'not equal' / 'greater than', bypassing auth or dumping rows; `{"$where": "..."}` can run arbitrary server-side JS. The flaw is letting the client inject operator objects (keys starting with `$`).

**Why it matters / why vibe-coded apps get it wrong.** Frameworks that parse JSON/query strings into objects (Express + body-parser, etc.) will happily pass `{$ne: null}` straight into a Mongo query if you do `db.users.find(req.body)`. AI-generated handlers very commonly spread request bodies directly into queries with zero type checking, making auth-bypass and data-exfiltration trivial. `$where`/`$function`/`$accumulator` can additionally enable RCE-like server-side JS execution or heavy-CPU denial of service.

**How.** Validate input by type and shape with a schema (Zod/Joi/Mongoose schema) BEFORE it reaches a query — coerce values to expected primitives (string/number) so an object operator is rejected. Reject any object whose keys start with `$` or contain `.`; for Express, use a sanitizer (e.g. express-mongo-sanitize, or in newer Mongoose, query casting) to strip operator keys from req.body/query/params. Never pass `req.body` directly as a filter — explicitly build `{ email: String(req.body.email) }`. Disallow client-controlled `$where`/`$regex`/`$expr` unless strictly required and validated; disable server-side JS server-wide with `--noscripting` when unused. The same principle applies to any NoSQL engine: treat input as data, never as query structure.

**When it applies.** Every app that builds queries from user input. This is application code, independent of which managed tier you run.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/NoSQL_Security_Cheat_Sheet.html> · <https://www.mongodb.com/docs/manual/administration/security-checklist/>

### 🔵 General NoSQL: schema validation, pagination, and resource caps

**What it is.** Schemaless engines accept any shape unless you enforce one, and they'll happily return an entire collection if asked. Two safeguards: (1) server-side schema/JSON validation so malformed or oversized documents are rejected at write time; (2) hard pagination and result/timeout caps so a single read can't dump or scan everything.

**Why it matters / why vibe-coded apps get it wrong.** Without validation, an attacker (or a buggy client) can write documents with unexpected types/extra fields that later break queries or smuggle operator-like data. Without pagination caps, a `find({})` / unbounded `Scan` returns the whole dataset — a cheap exfiltration and a denial-of-service (memory/cost) vector. Vibe-coded list endpoints frequently return all rows with no limit, and DynamoDB Scan with no bound is both slow and a full-table leak if the IAM policy allows it.

**How.** MongoDB: attach a JSON Schema validator to collections (`db.createCollection('users',{validator:{$jsonSchema:{...}}})`) and set `validationLevel:'strict'`; keep BSON object-check on (`net.wireObjectCheck:true`, default). Enforce pagination with `.limit(n)` + range/`_id`-based (keyset) paging, and use `maxTimeMS` to cap long queries. DynamoDB: prefer Query over Scan, always set `Limit` and handle `LastEvaluatedKey` for paging; deny `Scan` in IAM for user-facing roles (see LeadingKeys item). Redis: never `KEYS *` in app paths — use `SCAN` with COUNT, and bound list/set sizes. Across engines: enforce a max page size server-side (e.g. cap to 100) so the client can't request unbounded results.

**When it applies.** Once you have users/data — pagination caps matter the moment a collection grows; schema validation is good hygiene from the first table.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/NoSQL_Security_Cheat_Sheet.html> · <https://www.mongodb.com/docs/manual/administration/security-checklist/>

### 🟢 Adjacent reference (Supabase free tier): RLS is OFF by default behind a public anon key

**What it is.** Though Supabase is Postgres (not NoSQL), it's the canonical vibe-coded data breach and worth knowing alongside these stores. Supabase exposes your tables through an auto-generated REST/GraphQL API using a PUBLIC `anon` key shipped in the browser. Row Level Security is the only thing standing between that public key and your data — and RLS is DISABLED by default on tables you create via SQL.

**Why it matters / why vibe-coded apps get it wrong.** On the free tier the anon key is, by design, embedded client-side and visible to anyone. With RLS off (or a lazy `USING (true)` policy that AI tools generate to make tests pass), anyone with the anon key can read/modify/delete every row via a simple curl. Analyses attribute ~83% of Supabase exposures to RLS misconfiguration; the CVE-2025-48757 incident found ~10.3% of scanned Lovable apps (170 of 1,645) leaking user data through the anon key. The `service_role` key bypasses RLS entirely and must never ship to the client. (Note: the Supabase free tier also pauses projects after ~1 week of inactivity and has no automated daily backups — keep your own.)

**How.** For EVERY table in an API-exposed schema: `ALTER TABLE public.<t> ENABLE ROW LEVEL SECURITY;` then add explicit policies, e.g. `CREATE POLICY "own rows" ON public.profiles FOR SELECT TO authenticated USING ((SELECT auth.uid()) = user_id);` — wrap `auth.uid()` in `(SELECT ...)` for per-statement caching/performance, and scope policies `TO authenticated` (not the default which includes `anon`). Avoid `USING (true)` on anything sensitive. Test AS the anon role (empty results don't prove safety — confirm the policy, not the data). Keep `service_role` server-side only (Edge Functions / backend), never in client bundles or NEXT_PUBLIC_ vars. Run Supabase's Security Advisor / lints before going to prod; this all works on the free tier.

**When it applies.** Every app on Supabase (free tier included) — RLS must be enabled and tested on every exposed table before launch.

**Sources:** <https://supabase.com/docs/guides/database/postgres/row-level-security> · <https://vibeappscanner.com/is-supabase-safe>

**Key references:** [MongoDB Security Checklist for Self-Managed Deployments](https://www.mongodb.com/docs/manual/administration/security-checklist/) · [MongoDB: Enable Access Control (enable authentication)](https://www.mongodb.com/docs/manual/tutorial/enable-authentication/) · [MongoDB Atlas: Configure IP Access List Entries](https://www.mongodb.com/docs/atlas/security/ip-access-list/) · [MongoDB Atlas: Private Endpoints (Free/Flex clusters not supported)](https://www.mongodb.com/docs/atlas/security-private-endpoint/) · [MongoDB: Client-Side Field Level Encryption (CSFLE)](https://www.mongodb.com/docs/manual/core/csfle/) · [Redis security (protected-mode, requirepass, bind, TLS)](https://redis.io/docs/latest/operate/oss_and_stack/management/security/) · [Redis ACL documentation](https://redis.io/docs/latest/operate/oss_and_stack/management/security/acl/) · [AWS: DynamoDB fine-grained access control with IAM condition keys (LeadingKeys)](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/specifying-conditions.html) · [AWS: DynamoDB preventative security best practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices-security-preventative.html) · [AWS: DynamoDB encryption at rest](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/EncryptionAtRest.html) · [OWASP NoSQL Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/NoSQL_Security_Cheat_Sheet.html) · [Supabase: Row Level Security (RLS) guide](https://supabase.com/docs/guides/database/postgres/row-level-security) · [vibeappscanner: Is Supabase Safe? (RLS misconfig stats, CVE-2025-48757)](https://vibeappscanner.com/is-supabase-safe) · [Flare: MongoDB ransom campaigns (3,100+ exposed, ~1,416 wiped, no auth)](https://flare.io/learn/resources/blog/mongodb-ransom) · [BleepingComputer: 2017 MongoDB ransom apocalypse (10,000+ then ~28,000 servers)](https://www.bleepingcomputer.com/news/security/mongodb-apocalypse-is-here-as-ransom-attacks-hit-10-000-servers/)

