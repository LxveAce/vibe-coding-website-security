# Master pre-ship checklist — go through EVERY line

> The complete, cross-cutting list for an AI-built app. **Nothing here is skipped by omission.**
> For every item: tick it if done, or mark it `N/A — <reason>`. The **tier** tells you what a simple
> site likely needs vs. what is for scale/regulated apps — but you still *consciously decide* on each
> line. Deep explanations, fixes, and sources are in the linked docs.
>
> **Tiers:** 🟢 every app · 🔵 once you have users/data · 🟠 at scale · 🔴 regulated / enterprise.
> A tier is the *floor* at which it becomes important — not permission to ignore it below that.

---

## A. Security — the 50 &nbsp; ([details → security/vulnerabilities.md](security/vulnerabilities.md))

> Assume 🟢 unless noted; on a static site many are genuinely N/A — mark them so, don't skip them.

## Secrets & configuration
- [ ] (1) No DB credential reachable from the browser or the repo
- [ ] (2) No `.env` committed or served (`/.env` → 404); secrets in the platform/secret store
- [ ] (3) No hardcoded API keys; secret keys live server-side only; secret scanner in CI
- [ ] (11) CI/build logs never print the environment or secrets
- [ ] (13) Git history is clean of secrets/PII (rotate anything ever committed)
- [ ] (14) No secret/token in the frontend JS bundle
- [ ] (30) Every default credential changed
- [ ] (35) Logs contain no tokens / passwords / PII
- [ ] (36) No source maps published to production

## Authentication, authorization & rate limiting
- [ ] (4) Real authentication on every non-public route
- [ ] (5) Server-side authorization on every action (not just "is logged in")
- [ ] (6) A user cannot read/write another user's data (test it)
- [ ] (9) Admin routes require an admin check, server-side
- [ ] (28) Rate limits on login, signup, password reset, and AI/API endpoints
- [ ] (32) Payment/subscription/entitlement checks enforced on the server
- [ ] (33) Object access is ownership-checked, not just ID-in-URL (IDOR)
- [ ] (34) Server never trusts a user-supplied id/role/`is_admin` from the client
- [ ] (49) Multi-tenant data is isolated per tenant (RLS / scoped queries)

## Injection & input validation
- [ ] (16) All input validated server-side (allow-list, type, length)
- [ ] (17) SQL via parameterized queries / ORM — never string concatenation
- [ ] (18) NoSQL queries reject operator injection (`$gt`, `$where`, …)
- [ ] (22) No user input in file paths; canonicalize + confine to a base dir

## Client-side web & headers
- [ ] (19) Output encoded for context; remote data never `innerHTML`-concatenated (use `textContent`)
- [ ] (20) State-changing requests carry anti-CSRF tokens / `SameSite` cookies
- [ ] (27) CORS is an explicit allow-list — never `*` with credentials
- [ ] (46) Real headers: HSTS, `X-Frame-Options`/`frame-ancestors`, `nosniff`, CSP, Referrer-Policy, Permissions-Policy
- [ ] (47) Session cookies are `HttpOnly` + `Secure` + `SameSite`

## Sessions, JWT & reset
- [ ] (24) Password reset uses single-use, expiring, unguessable tokens; no user enumeration
- [ ] (25) Session IDs random + rotated on login; idle/absolute timeout; server-side invalidation
- [ ] (26) JWT secret is strong + unique + server-only; `alg` pinned (no `none`); short-lived

## SSRF, webhooks & uploads
- [ ] (21) Uploads: validate type/size, store outside web root, randomized names, no execution
- [ ] (23) Server-side fetches use an allow-list; block internal IPs/metadata; validate redirects
- [ ] (31) Webhooks verify the provider signature (HMAC) before acting

## Data stores & cloud
- [ ] (7) No "anyone can read/write" rules; deny-by-default
- [ ] (8) Firebase Rules / Supabase RLS enabled; no public S3 buckets
- [ ] (41) App DB user has least privilege (not owner/superuser)
- [ ] (48) TLS in transit; sensitive data encrypted at rest

## Exposure & environment
- [ ] (10) No debug pages/consoles in production
- [ ] (12) Generic error pages; stack traces server-side only
- [ ] (15) Security checks enforced server-side, not just hidden in the UI
- [ ] (29) Test/staging environments not publicly reachable (or behind auth)
- [ ] (45) No internal dashboards exposed to the internet

## AI features
- [ ] (39) Treat all LLM output as untrusted; isolate instructions from user/document data
- [ ] (40) AI tools/agents run with least privilege + per-action authorization (human-in-loop for risky ops)
- [ ] (50) A human reviewed the generated code — especially auth, payments, and data access

## Operations
- [ ] (37) Dependabot/SCA on; build fails on high/critical CVEs; SBOM produced
- [ ] (38) Packages kept current (Renovate/Dependabot version updates)
- [ ] (42) Security events logged (auth, authz failures, admin actions) — no secrets in logs
- [ ] (43) Monitoring + alerting on anomalies; uptime check; incident plan
- [ ] (44) Automated, encrypted, **tested** backups (3-2-1); restore actually works

## B. Login & authentication — the 5 &nbsp; ([details → security/login-and-auth.md](security/login-and-auth.md))

- [ ] 🟢 Auth tokens in localStorage/sessionStorage (XSS can steal them)
- [ ] 🟢 Authorization/role checks done on the client instead of the server
- [ ] 🟢 Treating email links/codes as strong MFA
- [ ] 🟢 No rate limiting / lockout / bot protection on auth endpoints
- [ ] 🟢 Allowing weak or known-breached passwords

## C. Production-readiness — the 26 &nbsp; ([details → production-readiness/](production-readiness/))

### Testing & quality engineering
- [ ] 🟢 Unit, integration, and end-to-end (E2E) tests
- [ ] 🟢 Regression tests
- [ ] 🔵 Load & stress testing
- [ ] 🟢 Chaos engineering & resilience testing
- [ ] 🟠 Test coverage thresholds enforced in CI
- [ ] 🟢 Code review process & standards

### Reliability & resilience patterns
- [ ] 🟢 Error handling & graceful degradation
- [ ] 🟢 Retry logic with exponential backoff + jitter, and idempotency
- [ ] 🟠 Circuit breakers & fallback behavior
- [ ] 🔵 Concurrency handling & race-condition prevention (locking, atomic ops)
- [ ] 🟠 Caching strategy and cache invalidation

### Data, privacy & regulatory compliance
- [ ] 🟢 PII handling: classification, minimization, encryption
- [ ] 🟢 Data retention & deletion policies (right to erasure)
- [ ] 🟢 GDPR compliance basics for developers
- [ ] 🔴 HIPAA compliance basics (PHI) for developers
- [ ] 🔴 Multi-tenancy & data isolation (tenant-scoped access)

### Operations, observability & recovery
- [ ] 🟢 Audit trails & tamper-evident logging
- [ ] 🟢 RTO and RPO — definitions & how to set them
- [ ] 🟢 Disaster recovery (DR) plan & backups (3-2-1, tested restores)

### Architecture, governance & accessibility
- [ ] 🟢 Architecture diagrams (C4 model)
- [ ] 🟢 ADRs — Architecture Decision Records
- [ ] 🟢 Web accessibility (WCAG 2.2, ARIA, semantic HTML, keyboard nav, contrast)

## D. Architecture & scale — decide as you grow &nbsp; ([details → engineering/beyond-code.md](engineering/beyond-code.md))

> Mostly 🟠 at-scale — a static site or small app needs almost none of these. But **decide** on each
> as the app grows; don't let them be forgotten. Detail + "when it's overkill" in the linked doc.

**Containers & orchestration:**
- [ ] Containerisation
- [ ] Docker
- [ ] Kubernetes

**Cloud, serverless, deployment & CI/CD:**
- [ ] Cloud (IaaS / PaaS / SaaS)
- [ ] Serverless
- [ ] AWS Lambda
- [ ] Deployments (blue-green / canary / rolling)
- [ ] Staging environments
- [ ] CI/CD

**AWS managed building blocks:**
- [ ] SQS (Simple Queue Service)
- [ ] S3 (object storage)
- [ ] DynamoDB

**Messaging, queues & real-time communication:**
- [ ] Kafka / RabbitMQ (message brokers)
- [ ] WebSockets
- [ ] Long polling vs short polling
- [ ] RPC (gRPC)

**Databases & data scaling:**
- [ ] Databases (SQL vs NoSQL)
- [ ] Embedded database (SQLite)
- [ ] Sharding
- [ ] Partitioning
- [ ] Caching (Redis / CDN)

**Networking, delivery, access control & encryption:**
- [ ] Load balancer
- [ ] Proxy / reverse proxy
- [ ] Firewall (network & WAF)
- [ ] FTP / SFTP
- [ ] Encryption (TLS in transit, at rest)

**Performance, scalability & reliability:**
- [ ] Optimisation
- [ ] QPS (queries per second)
- [ ] Throughput
- [ ] Availability (SLA / uptime)
- [ ] Rate limiting
- [ ] Error logging / observability

**Dev workflow, tooling & ML:**
- [ ] git / GitHub
- [ ] git cherry-pick
- [ ] PyCharm (IDE)
- [ ] TensorFlow (ML framework)

---

## E. Advanced — AI/LLM + general web security &nbsp; ([AI/LLM →](security/ai-llm-security.md) · [advanced web →](security/advanced-web-security.md))

> The deeper layer. Mostly 🟠/🔴 — but several are 🟢 even for a simple site (SRI, cookie prefixes,
> DMARC, security.txt, open-redirect/tabnabbing). If your app has an LLM, the AI/LLM block is 🟢. Decide on each.

### AI / LLM application security — OWASP LLM Top 10 (2025)
- [ ] 🟢 LLM01:2025 Prompt Injection — architectural defenses (direct, indirect, multimodal)
- [ ] 🟢 LLM02:2025 Sensitive Information Disclosure (training data, context, secrets)
- [ ] 🟢 LLM03:2025 Supply Chain (models, datasets, adapters, plugins)
- [ ] 🟢 LLM04:2025 Data & Model Poisoning
- [ ] 🟢 LLM05:2025 Improper Output Handling — LLM output is untrusted input
- [ ] 🟢 LLM06:2025 Excessive Agency — over-permissioned tools/agents
- [ ] 🟢 LLM07:2025 System Prompt Leakage
- [ ] 🔴 LLM08:2025 Vector & Embedding Weaknesses (RAG, cross-tenant leakage, inversion)
- [ ] 🟢 LLM09:2025 Misinformation / Overreliance / Hallucination (incl. slopsquatting)
- [ ] 🟢 LLM10:2025 Unbounded Consumption (cost/DoS & model extraction)

### AI coding agents, MCP & dependency hallucination
- [ ] 🟢 Slopsquatting / hallucinated-package supply-chain attacks
- [ ] 🔴 MCP tool poisoning & malicious tool descriptions
- [ ] 🔴 MCP confused deputy, token passthrough & over-broad OAuth scopes
- [ ] 🟢 Excessive agency: least-privilege, human-in-the-loop, sandboxed tool execution
- [ ] 🟢 Secrets & PII leaking into prompts, chat logs, and AI provider context
- [ ] 🟢 Insecure-by-default AI-generated code — catching it systematically (SAST + review)

### Transport, TLS, DNS & network security
- [ ] 🟢 Modern TLS configuration: TLS 1.3 + curated TLS 1.2, disable legacy, OCSP stapling
- [ ] 🔵 Certificate revocation in 2025: OCSP stapling sunset, CRLs, and short-lived certs
- [ ] 🟢 HSTS with preload (and the Certificate Transparency ecosystem)
- [ ] 🟢 DNS security: DNSSEC, CAA records (with account binding), registrar/registry lock, NS hygiene
- [ ] 🟠 Subdomain takeover via dangling CNAMEs: detection and prevention
- [ ] 🟢 Edge defense: DDoS protection, WAF managed rules, rate limiting, bot management, origin cloaking

### Advanced browser-platform hardening
- [ ] 🟢 Strict CSP: nonces + strict-dynamic (not host allowlists)
- [ ] 🔵 Trusted Types: require-trusted-types-for 'script' (DOM-XSS defense)
- [ ] 🔵 Subresource Integrity (SRI) for third-party scripts/styles
- [ ] 🟢 Cookie name prefixes __Host- / __Secure- and Partitioned (CHIPS)
- [ ] 🟢 Clickjacking defense: CSP frame-ancestors (+ X-Frame-Options fallback)
- [ ] 🟢 Reverse tabnabbing, open redirects, and postMessage origin checks
- [ ] 🟠 Cross-origin isolation: COOP / COEP / CORP

### Identity & account security (deep)
- [ ] 🟢 Breached-credential (Pwned Passwords) checks at password-set time, layered with MFA
- [ ] 🔵 Device / connection fingerprinting and adaptive, identifier-aware throttling
- [ ] 🟢 Account/user enumeration defense: uniform responses AND uniform timing
- [ ] 🟢 OAuth 2.0 / OIDC client hardening: PKCE S256, exact redirect-URI match, state, nonce, no implicit/ROPC
- [ ] 🔴 SAML service-provider validation: signature scope, XSW defense, audience/recipient/timestamps
- [ ] 🟢 Password-reset & email-change hardening, account recovery, and step-up auth

### API, GraphQL & realtime security — OWASP API Top 10 (2023)
- [ ] 🟢 API1 BOLA + API5 BFLA: per-object and per-function authorization
- [ ] 🟢 API3 Broken Object Property-Level Authorization (mass assignment + excessive data exposure)
- [ ] 🔵 API4 Unrestricted Resource Consumption (rate, payload, pagination & cost ceilings)
- [ ] 🔵 API6 sensitive business flows + API10 unsafe consumption of third-party APIs
- [ ] 🟠 GraphQL hardening: introspection off, depth/complexity caps, batching/alias limits, persisted/trusted queries
- [ ] 🟠 WebSocket security (Origin allowlist, handshake + per-message auth, message caps) and signed object-storage URLs

### Email & domain integrity
- [ ] 🟢 DMARC enforcement (p=reject) with correct SPF/DKIM identifier alignment
- [ ] 🔵 MTA-STS + TLS-RPT (and DANE) for SMTP transport encryption
- [ ] 🔴 BIMI with VMC/CMC for authenticated brand logo display
- [ ] 🟢 Transactional-email anti-phishing and link safety
- [ ] 🟢 Domain hijacking defense: registry lock, DNSSEC, and registrar account hardening

### Software supply chain & DevSecOps
- [ ] 🔴 SBOM generation & consumption (CycloneDX / SPDX) with VEX
- [ ] 🔴 SLSA build provenance & attestation (L1-L3)
- [ ] 🟢 Artifact & commit signing (Sigstore/cosign), signed git commits, branch protection
- [ ] 🟢 Dependency pinning, lockfile integrity, SHA-pinned Actions, least-privilege OIDC CI tokens
- [ ] 🔵 IaC scanning, container image scanning & minimal/distroless base images
- [ ] 🟢 Secrets management & rotation (Vault / cloud KMS) + SAST / DAST / fuzzing & secret scanning in CI

### Security governance, monitoring & process
- [ ] 🟢 Threat modeling with STRIDE (security) + LINDDUN (privacy), data-flow diagrams, and attack trees
- [ ] 🟢 Centralized, tamper-evident security logging with detection & alerting (OWASP A09:2025)
- [ ] 🟢 Incident response plan & runbooks (NIST SP 800-61r3, CSF 2.0)
- [ ] 🟢 Responsible-disclosure path: security.txt (RFC 9116), VDP, and a vuln-management SLA
- [ ] 🟢 Privacy & consent engineering: cookie consent, data minimization, and DSAR/erasure
- [ ] 🟢 Business-logic abuse testing: workflow bypass, price/quantity tampering, race conditions

## F. Backend database & hosting &nbsp; ([guides → database-hosting/](database-hosting/))

> Only if your app has a backend DB. **The one rule:** a client-reachable key (Supabase anon, Firebase
> web config) needs row-level access control on every table; the admin/`service_role`/secret key is
> server-only, never in a client bundle. Supabase (free tier) is the deep guide.

### Universal (every database)
- [ ] 🟢 Never expose the DB to the public internet; never put credentials/connection strings in client code
- [ ] 🟢 Least-privilege database roles (app user is not owner/superuser; separate read/write/migration roles)
- [ ] 🟢 Encryption in transit (TLS/SSL required) and encryption at rest
- [ ] 🟢 Parameterized queries / ORM only — never string-concatenated SQL or NoSQL (injection)
- [ ] 🟢 Tenant isolation / row-level access control for multi-user data
- [ ] 🟢 Secrets management for DB credentials (env / secret manager, rotation) — not in the repo
- [ ] 🟢 Backups + point-in-time recovery + TESTED restores; migrations under version control
- [ ] 🟢 Connection pooling, query timeouts, and resource caps to resist DoS
- [ ] 🔴 Audit logging, monitoring & alerting on the data layer; PII classification, retention & deletion

### Supabase (free tier) ⭐
- [ ] 🟢 Row Level Security (RLS) on EVERY exposed table — the #1 vibe-coded mistake
- [ ] 🟢 API keys: publishable/anon (client-safe with RLS) vs service_role/secret (server-only, BYPASSRLS)
- [ ] 🟢 Supabase Auth — email confirmation, MFA/TOTP, leaked-password protection, password strength, sessions
- [ ] 🟢 Custom claims & RBAC via the Custom Access Token auth hook
- [ ] 🟢 Storage security — private buckets, folder-scoped RLS, signed URLs, size/MIME limits
- [ ] 🟢 Edge Functions — JWT verification, secrets, CORS, keeping service_role server-side
- [ ] 🟢 Realtime authorization — private channels gated by RLS on realtime.messages
- [ ] 🟢 Postgres roles & SECURITY DEFINER / function search_path cautions
- [ ] 🔴 Network & connection security — enforce SSL, network/IP restrictions, DB password, Supavisor pooling
- [ ] 🟢 Security Advisor / database Linter + CLI migrations to catch RLS-disabled tables
- [ ] 🔵 FREE TIER specifics — limits, project PAUSING, and NO automated backups (backups are YOUR job)

### Firebase
- [ ] 🟢 Deny-by-default Security Rules with request.auth + ownership checks (never ship test mode)
- [ ] 🟢 The public web API key is not a secret — but it MUST be backed by locked-down rules
- [ ] 🔵 Firebase App Check (attestation) so only your real apps can reach the backend
- [ ] 🟢 Storage rules, Cloud Functions security, and least-privilege service accounts
- [ ] 🟢 Data validation in rules, capping reads against cost/DoS, and testing with the Emulator

### Relational (Postgres/MySQL/PlanetScale/Neon)
- [ ] 🟢 Enable + FORCE Row-Level Security on every Postgres table (and write auth.uid() policies)
- [ ] 🟢 Least-privilege GRANTs and dedicated app roles (no superuser/root for the app)
- [ ] 🟢 SECURITY DEFINER functions: always pin search_path
- [ ] 🟢 Enforce TLS with certificate verification (Postgres sslmode=verify-full, MySQL REQUIRE SSL)
- [ ] 🟢 Keep the database off the public internet (private subnet / IP-allow / PrivateLink) and harden auth method
- [ ] 🟢 Connection poolers & serverless HTTP drivers: authenticate properly, don't expose them
- [ ] 🔴 Managed-provider hygiene: IAM auth, private access, and clean preview/branch data
- [ ] 🟢 MySQL/MariaDB secure defaults: disable LOCAL INFILE and lock down server settings
- [ ] 🔴 Backups, PITR, and secrets management (Supabase free-tier: NO backups, NO PITR)
- [ ] 🔴 Migration safety: no destructive migrations without review (lock_timeout + expand-contract)

### NoSQL & cache (MongoDB/Redis/DynamoDB)
- [ ] 🟢 MongoDB: enable authentication and never bind to the public internet
- [ ] 🟢 MongoDB Atlas: empty IP allowlist (never 0.0.0.0/0), private endpoints, TLS, RBAC
- [ ] 🔴 MongoDB: field-level / queryable encryption for sensitive fields
- [ ] 🟢 Redis: NOT internet-facing — protected-mode, requirepass/ACL, bind, TLS
- [ ] 🔵 Redis: per-app ACL users with least privilege; disable dangerous commands
- [ ] 🟢 Redis as session/token store: cache poisoning, key namespacing, validation
- [ ] 🟢 DynamoDB: IAM least-privilege with item-level condition keys (dynamodb:LeadingKeys)
- [ ] 🟢 DynamoDB: encryption at rest (KMS), no sensitive keys, private access
- [ ] 🟢 NoSQL injection: block client-supplied query operators ($where, $ne, $gt, $regex)
- [ ] 🔵 General NoSQL: schema validation, pagination, and resource caps
- [ ] 🟢 Adjacent reference (Supabase free tier): RLS is OFF by default behind a public anon key

### Embedded/edge & OSS BaaS
- [ ] 🟢 SQLite file permissions and OS-level isolation
- [ ] 🔵 Encryption at rest: SQLCipher and libSQL/Turso encryption
- [ ] 🟢 Turso / libSQL edge auth tokens — scope to read-only and least privilege
- [ ] 🟢 Cloudflare D1 — bindings, scoped API tokens, and proxy Workers
- [ ] 🟢 PocketBase access rules (API rules) and self-host hardening
- [ ] 🟢 Appwrite permissions (collection + document/row-level security) and server-key danger
- [ ] 🟢 Convex and Nhost authorization models (code-based and Hasura/Postgres)
- [ ] 🟢 Supabase Row Level Security — enable it on EVERY exposed table (free-tier specific)
- [ ] 🟢 Choosing a backend: Supabase free tier vs Postgres/Neon/PlanetScale/Firebase
- [ ] 🔴 Migration and vendor lock-in: Postgres portability vs proprietary stores
- [ ] 🟢 Real-world cautionary failures: open MongoDB/Redis and missing-RLS exposures

## Ship gate — run on every deploy
- [ ] Secret scan clean (gitleaks / detect-secrets)
- [ ] Dependency/SCA scan clean (no high/critical)
- [ ] [securityheaders.com](https://securityheaders.com) grade **A** or better on the live URL
- [ ] Tests green; coverage threshold met (if configured)
- [ ] Deployed-URL scan run (e.g. VibeScan / Vibe App Scanner)
- [ ] Every item above is ticked **or** explicitly marked `N/A — <reason>` (nothing left blank)
- [ ] Advanced layer (section E) reviewed — each item ticked or marked N/A
- [ ] Backend DB (section F): RLS/auth on every table, no admin key in the client, backups planned (esp. Supabase free tier)\n- [ ] Human review of anything touching auth, payments, or other users' data
