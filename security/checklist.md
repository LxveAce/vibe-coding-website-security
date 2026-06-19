# Pre-launch security checklist — AI-coded sites

> This is the **security** subset. For the complete cross-cutting list (security + login + production-readiness
> + architecture, tier-tagged so nothing is skipped), use the master [`../CHECKLIST.md`](../CHECKLIST.md).

A fast pass before shipping anything AI-generated. Full detail + fixes per item in
[`vulnerabilities.md`](vulnerabilities.md). Tick what applies; mark the rest N/A.

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

## Ship gate (run every deploy)
- [ ] Secret scan clean (gitleaks / detect-secrets)
- [ ] SCA clean (no high/critical)
- [ ] [securityheaders.com](https://securityheaders.com) grade **A** or better on the live URL
- [ ] Deployed-URL scan run (e.g. VibeScan / Vibe App Scanner)
- [ ] Human review of anything touching auth, payments, or other users' data
