# AGENTS.md

**If you are an AI coding agent building or editing a website, read this first.** AI-generated
("vibe-coded") sites ship the same handful of security holes and missing pieces over and over. This
repo is the antidote — follow the rules below, and **before you say "done," run the checklist.**

> **Humans:** drop this file into your project (as `AGENTS.md`, `CLAUDE.md`, or a `.cursor/rules/` file),
> or paste this repo's URL into your AI tool's context, and tell your assistant to follow it.

## How to use this repo
1. **Before coding** — skim [`security/checklist.md`](security/checklist.md). If it has **login/auth**,
   read [`security/login-and-auth.md`](security/login-and-auth.md). If it will have a backend or database,
   also skim [`engineering/beyond-code.md`](engineering/beyond-code.md) and [`database-hosting/`](database-hosting/)
   (esp. [`database-hosting/supabase.md`](database-hosting/supabase.md) if using Supabase). If it uses an
   LLM/RAG/agent, read [`security/ai-llm-security.md`](security/ai-llm-security.md). For anything past a
   demo, scan [`production-readiness/`](production-readiness/) and [`security/advanced-web-security.md`](security/advanced-web-security.md) and pick the tiers that fit.
2. **While coding** — apply the Rules below. When you touch auth, data access, file handling, or
   third-party keys, open the matching section of [`security/vulnerabilities.md`](security/vulnerabilities.md)
   and follow the fix.
3. **Before finishing** — go through the master [`CHECKLIST.md`](CHECKLIST.md). **Every line gets ticked
   or explicitly marked `N/A — <reason>` — never skipped by omission.** Fix every applicable item, then
   emit the Security Report (bottom of this file).

## The Rules — apply to every site you generate

### Secrets
- **NEVER** put a secret (API key, DB password, service token) in client-side code, a committed file, or
  git history. If a value can reach the browser, treat it as **public**.
- A key that is *meant* to be public (Supabase anon key, Firebase web config) is safe **only** behind a
  real authorization boundary — Supabase **Row Level Security on every exposed table**, Firebase
  **Security Rules** (never "test mode"). Never ship a `service_role`/admin key to a client.
- Add `.env` to `.gitignore` **before** creating it. Never `print`/`echo` env in CI logs. Never publish
  source maps to production.

### Trust & authorization
- **NEVER trust the client.** Re-check authentication, authorization, input validation, prices,
  quantities, and roles on the **server**. The UI is not a security control.
- **Ownership-check every object access** (stop IDOR): don't return `/api/orders/123` just because it was
  requested — verify the caller owns 123. Don't trust a client-sent `id`, `role`, or `is_admin`.
- Enforce admin checks **server-side** on every admin/internal route.

### Injection & input
- Use **parameterized queries / an ORM** — never assemble SQL/NoSQL by string concatenation.
- **Validate** input server-side (allow-lists, type, length) and **output-encode for context** to prevent
  XSS. Never `innerHTML`-concatenate untrusted data — use `textContent` or a safe template that escapes.
- Confine file paths to a base directory (reject `../`); validate upload type/size; store uploads outside
  the web root and never execute them.

### Web platform
- Set **real HTTP security headers**: HSTS, `X-Frame-Options`/CSP `frame-ancestors`,
  `X-Content-Type-Options: nosniff`, a strict `Content-Security-Policy`, `Referrer-Policy`,
  `Permissions-Policy`. On a static host, a `<meta>` CSP **cannot** do HSTS, framing, or Permissions-Policy
  — see [`security/http-security-headers.md`](security/http-security-headers.md).
- Cookies: `HttpOnly` + `Secure` + `SameSite`. CORS: an explicit allow-list, never `*` with credentials.
- **Rate-limit** login, signup, password reset, and any AI/expensive endpoint. Verify webhook signatures.

### AI features
- Treat **LLM output as untrusted input**; keep system instructions isolated from user/document content
  (prompt injection). Validate/clamp anything an LLM produces before acting on it.
- Give AI tools/agents **least privilege** and per-action authorization; require human approval for
  destructive or financial actions.

### Don't ship blind
- **You are not exempt.** Treat your own generated code as untrusted. Explicitly flag anything touching
  **auth, payments, or other users' data** for human review.
- Turn on Dependabot / SCA; don't ship known-vulnerable dependencies. Add logging, monitoring, and tested
  backups for anything stateful.

## The catalog
| File | Use it for |
|---|---|
| [`CHECKLIST.md`](CHECKLIST.md) | **The master pre-ship checklist** — every item across all areas, tier-tagged; tick or mark N/A, never skip |
| [`security/vulnerabilities.md`](security/vulnerabilities.md) | The 50 common AI-coded vulns — what / why / fix + sources |
| [`security/checklist.md`](security/checklist.md) | Pre-ship checklist + per-deploy ship gate |
| [`security/login-and-auth.md`](security/login-and-auth.md) | The 5 login/auth mistakes AI ships (localStorage tokens, client-side authz, weak MFA, no rate limit, breached passwords) |
| [`security/ai-llm-security.md`](security/ai-llm-security.md) | **If the app uses an LLM/RAG/agent** — OWASP LLM Top 10 (2025) + agent/MCP/slopsquatting |
| [`security/advanced-web-security.md`](security/advanced-web-security.md) | Deeper general web security — TLS/DNS, CSP3/Trusted Types/SRI, OAuth/OIDC, API Top 10, email/SPF/DMARC, supply chain, governance |
| [`security/http-security-headers.md`](security/http-security-headers.md) | Real HTTP headers (esp. static hosts behind Cloudflare) |
| [`engineering/beyond-code.md`](engineering/beyond-code.md) | The backend/system-design pieces AI forgets (containers, queues, caching, scaling, DBs) |
| [`production-readiness/`](production-readiness/) | Testing, reliability, data/compliance, ops, governance & a11y — tiered, so you build to the right level |
| [`database-hosting/`](database-hosting/) | **Backend DB security** — universal + per-provider; **Supabase free-tier** guide (RLS, keys, auth, storage, backups) |

## Security Report (emit this when you finish)
End your work with a short report:
- Walk **every section** of [`CHECKLIST.md`](CHECKLIST.md) (security, login/auth, production-readiness,
  architecture). For each item: **Done** / **N/A** (+one-line reason) / **TODO**. Nothing left unaddressed.
- A "needs human review" list for anything touching auth, payments, or other users' data.
- Any secret/key you introduced and where it lives (must be server-side).
