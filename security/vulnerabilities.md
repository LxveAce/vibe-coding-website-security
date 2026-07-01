# The 50 — Securing AI-coded / vibe-coded websites

> Extracted from a creator's list, *"50 vulnerabilities we look over in vibe-coded / AI-generated apps"*
> (captured from screenshots), then expanded with current best-practice fixes and cited authoritative
> sources via web research. **Item numbers match the original list.** Grouped by category.
>
> See [`checklist.md`](checklist.md) for the pre-ship version, and
> [`http-security-headers.md`](http-security-headers.md) for the HTTP-header hardening.

## Categories

1. **Secrets & configuration exposure** — items 1, 2, 3, 11, 13, 14, 30, 35, 36
2. **Authentication, authorization, access control & rate limiting** — items 4, 5, 6, 9, 28, 32, 33, 34, 49
3. **Injection & input validation** — items 16, 17, 18, 22
4. **Client-side web vulns & security headers** — items 19, 20, 27, 46, 47
5. **Sessions, JWT & password reset** — items 24, 25, 26
6. **SSRF, webhooks & file uploads** — items 21, 23, 31
7. **Data stores & cloud config (Firebase/Supabase/S3)** — items 7, 8, 41, 48
8. **Exposure & environment hygiene** — items 10, 12, 15, 29, 45
9. **AI-specific security (LLM features)** — items 39, 40, 50
10. **Operations: monitoring, dependencies, backups, audit logs** — items 37, 38, 42, 43, 44

---

## Secrets & configuration exposure

Secrets and configuration exposure is the single most common and most damaging class of bug in AI-coded/vibe-coded apps: a leaked database credential, API key, or service-role token typically grants instant, authenticated access with no further exploitation needed. AI coding assistants optimize for "make it work now," so they happily inline keys into source, commit .env files, suggest the all-powerful service_role key to silence a permissions error, leave default passwords, and ship source maps and verbose logs to production. The fix pattern is consistent across every item below: keep secrets server-side, never in the browser bundle or git history; rotate anything that has ever touched a repo, log, or build artifact; put a real authorization boundary (RLS/Security Rules, scoped tokens) behind any key that must be public; and add automated detection (secret scanning, pre-commit hooks) so leaks are caught before they ship. Note: pure static GitHub Pages sites have no server to hide secrets in, so the only safe answer there is "the site must contain no secret at all" -- any key in client JS is public.

### 1. Exposed database credentials

**What it is.** Database connection strings or credentials (host, user, password, or a key that talks directly to the DB) are reachable by an attacker -- in client-side code, a committed config file, an error page, or an over-privileged public key -- giving direct read/write access to the data store.

**Why AI-coded apps hit it.** AI assistants frequently wire the frontend straight to a backend-as-a-service (Supabase/Firebase) and, when a query fails due to authorization, commonly suggest using the all-powerful service_role key instead of fixing the access policy; they also paste real connection strings into committed config to make the demo run. The result is a DB-admin-equivalent secret shipped to the browser or repo.

**Fix.** Never let the browser hold a credential that can bypass authorization. With Supabase, only the publishable/anon key may reach the client, and ONLY with Row Level Security enabled on every table in an exposed schema (ALTER TABLE ... ENABLE ROW LEVEL SECURITY); the service_role key carries BYPASSRLS and must never be used in the browser or shipped to clients -- keep it server-side only (servers, Edge Functions, secured admin APIs). With Firebase, the web config is public by design but must be backed by restrictive Security Rules (deny-by-default). For Flask/Python backends, load DB credentials from environment/secret manager (AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault), enforce least-privilege DB roles, and never expose the DB to the public internet. If a credential ever leaked, rotate it immediately -- exposure equals compromise. N/A to pure static sites only if they genuinely have no database; the moment a static site talks to Supabase/Firebase, the RLS/Rules boundary is mandatory.

**Sources:** <https://supabase.com/docs/guides/database/postgres/row-level-security> · <https://supabase.com/docs/guides/getting-started/api-keys> · <https://owasp.org/Top10/2021/A05_2021-Security_Misconfiguration/>

### 2. Public .env files

**What it is.** A .env file containing secrets is served by the web server (e.g. https://site/.env returns it) or committed to the repository, letting anyone fetch the API keys, DB passwords, and tokens inside.

**Why AI-coded apps hit it.** AI scaffolds put secrets in a .env at the project root and don't reliably add it to .gitignore or block dotfile serving, so the file gets committed or deployed as a static asset. Many vibe-coded projects also copy .env into the deploy directory.

**Fix.** Add .env (and .env.*) to .gitignore BEFORE creating it, and verify it is untracked. Configure the web server to deny dotfiles (Apache .htaccess RedirectMatch/Files block, nginx 'location ~ /\. { deny all; }'); behind Cloudflare you can add a WAF rule blocking requests to /.env and similar paths. In production, prefer your platform's encrypted env-var store (Vercel/Netlify/Railway/Cloudflare Workers secrets) or a secrets manager over shipping a .env file at all -- OWASP notes environment variables are generally accessible to all processes and may surface in logs/dumps, so they are a fallback, not a vault. For static GitHub Pages there is no server-side .env: any value placed in the repo is public, so secrets simply cannot live there. If a .env was ever public or committed, rotate every secret in it.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html> · <https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/01-Information_Gathering/05-Review_Web_Page_Content_for_Information_Leakage>

### 3. Hardcoded API keys

**What it is.** Secret API keys (payment, email, cloud, third-party) are written as literals in source code rather than injected from a secure store, so they leak with the code wherever it goes (repo, bundle, build artifact).

**Why AI-coded apps hit it.** LLMs generate runnable examples with the key inlined ('const stripeKey = "sk_live_..."') because that is the simplest working code; without explicit instruction they don't introduce a secrets-loading layer. OWASP MASWE-0005 documents API keys hardcoded in the app package/source as a recurring weakness.

**Fix.** Treat any secret key as server-side-only: store it in a secrets manager or platform env store and read it at runtime; never commit it. For third-party APIs that must be called from the browser, route the call through a backend (Backend-for-Frontend) or serverless function that holds the secret and the client sends only a user/session token -- the client never sees the key. Distinguish publishable/restricted keys (safe to expose, e.g. Stripe publishable key) from secret keys (never expose, e.g. sk_live). Add a pre-commit secret scanner (gitleaks, Yelp detect-secrets) and CI scanning so a hardcoded key is caught before merge. For a pure static site, the only safe API key is one explicitly designed to be public AND locked down by referrer/origin or scope restrictions on the provider side. Rotate any key that was ever hardcoded.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html> · <https://mas.owasp.org/MASWE/MASVS-AUTH/MASWE-0005/> · <https://blog.gitguardian.com/stop-leaking-api-keys-the-backend-for-frontend-bff-pattern-explained/>

### 11. Build logs leaking secrets

**What it is.** Secrets appear in CI/CD build or deploy logs -- via a debug step that prints the environment, a tool that echoes a connection string, or a value transformed so the platform's masking misses it -- and anyone with log read access can harvest them.

**Why AI-coded apps hit it.** Generated CI configs and AI-suggested debugging steps often add 'env'/'printenv' or echo variables to troubleshoot failing builds, dumping every variable to the log. Masking is also defeated by transformations the AI introduces (base64/URL-encoding, JSON blobs), which vibe-coded pipelines do casually.

**Fix.** Never print the environment in CI; remove 'run: env'/'printenv' debug steps. Treat masking as a convenience, not a security boundary -- GitHub only redacts exact matches of registered secret values, so don't pack secrets into JSON/XML/YAML blobs (redaction fails) and re-register any transformed value as a secret. For non-GitHub-secret sensitive values use ::add-mask::VALUE. Prefer short-lived, identity-based auth (OIDC federation to AWS/GCP/Azure) over long-lived stored secrets, and apply least-privilege workflow permissions (GITHUB_TOKEN read-only by default). Manually review logs after runs to confirm nothing leaked, and restrict who can read build logs. Rotate any secret seen in a log. Mostly relevant to Flask/Electron apps with real CI; a static GitHub Pages deploy still uses Actions, so the same rules apply to its build workflow.

**Sources:** <https://docs.github.com/en/actions/reference/security/secure-use> · <https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html>

### 13. Leaked GitHub repos or commit history

**What it is.** A secret that was committed (even if later deleted) remains in git history forever and is retrievable from any clone; making a repo public, or a previously committed key in an open-source repo, exposes it. Git's full history is a credential store attackers mine.

**Why AI-coded apps hit it.** Vibe-coded projects iterate fast and commit working state including keys/.env, then 'fix' it by deleting the file in a later commit -- which does nothing, the secret is still in history. Repos are also flipped public without an audit of past commits.

**Fix.** First, ROTATE/revoke the leaked secret -- once committed it is compromised, and scrubbing history does not un-leak it (GitHub's own guidance makes revoking the credential the first step). Then purge it from history with git filter-repo (GitHub's recommended tool) or BFG Repo-Cleaner, force-push, and have collaborators re-clone; note forks and cached commit views may persist, which is why rotation comes first. Prevent recurrence: enable GitHub Secret Scanning with Push Protection (blocks commits containing known secret patterns), add pre-commit secret scanning (gitleaks), and keep secrets out of the repo entirely via .gitignore and a secrets manager. Periodically scan your own history with gitleaks. Applies to every project type, including static sites -- a key committed to a GitHub Pages repo is public and in history.

**Sources:** <https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository> · <https://github.com/gitleaks/gitleaks> · <https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html>

### 14. Secrets included in frontend JavaScript

**What it is.** API keys, internal endpoints, or credentials are embedded in client-side JavaScript. Anything in the bundle is fully visible via View Source / DevTools, so it is not secret at all -- bundling or 'env var' framework prefixes do not hide it.

**Why AI-coded apps hit it.** A pervasive misconception (which AI reproduces) is that REACT_APP_/VITE_/NEXT_PUBLIC_ env vars are secure; in reality the build inlines them into the JS strings. OWASP WSTG notes programmers commonly hardcode API keys, internal IPs, and credentials into frontend JS variables.

**Fix.** Assume the client bundle is public: never put a secret in it. Move any privileged call behind a backend/Backend-for-Frontend or serverless proxy that holds the secret server-side; the browser sends only a user/session token. Frameworks that split server/client code (Next.js API routes, SvelteKit/Remix server endpoints) keep secrets out of the client bundle -- use them for third-party calls and mutations. Only values intentionally public (Firebase web config, Stripe publishable key, a Supabase anon key WITH RLS) may ship to the client, and each must be backed by a server-side authorization boundary or provider-side restriction (origin/referrer allowlist, scope limits). For a pure static GitHub Pages site this is the hard constraint: if a feature needs a secret, it needs a backend (e.g. a Cloudflare Worker) -- it cannot be done safely in static JS alone.

**Sources:** <https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/01-Information_Gathering/05-Review_Web_Page_Content_for_Information_Leakage> · <https://blog.gitguardian.com/stop-leaking-api-keys-the-backend-for-frontend-bff-pattern-explained/> · <https://supabase.com/docs/guides/getting-started/api-keys>

### 30. Default credentials left unchanged

**What it is.** An application, admin panel, database, or service is deployed with its well-known default username/password (admin/admin, etc.) still active, letting an attacker log in with documented credentials and no exploitation. This is CWE-1392 (Use of Default Credentials) / CWE-798 and an OWASP A05 Security Misconfiguration indicator.

**Why AI-coded apps hit it.** AI scaffolds and quick-start templates ship with seeded default admin accounts, sample users, or boilerplate passwords to get the app running, and vibe-coded deploys rarely include the hardening step of forcing a credential change before going live. OWASP lists default accounts still enabled and unchanged among the most common misconfigurations.

**Fix.** Before exposing anything, change every default credential and remove sample/seed accounts; enforce a forced password change on first login for admin accounts. Apply a repeatable hardening process and a minimal install (no unnecessary features, components, documentation, sample apps, default accounts, or demo pages) per OWASP A05. This covers your Flask admin panels, database/service accounts, any self-hosted tooling, router/IoT-style devices, and CMS/admin dashboards. Add an automated check that verifies no default creds remain across environments. Generally N/A to a pure static site (no login), but very relevant to any backend, admin UI, or self-hosted service you runs.

**Sources:** <https://cwe.mitre.org/data/definitions/1392.html> · <https://owasp.org/Top10/2021/A05_2021-Security_Misconfiguration/> · <https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/04-Authentication_Testing/02-Testing_for_Default_Credentials>

### 35. Logs containing tokens, emails, passwords, or private user data

**What it is.** Application logs record sensitive values -- access/session tokens, passwords, connection strings, encryption keys, PII like emails, or payment data. Anyone who reads the logs (ops, a log-aggregation breach, an exposed log endpoint) then has those secrets and that PII.

**Why AI-coded apps hit it.** AI debugging code logs whole request/response objects, full error contexts, and auth payloads ('log the user object', 'print the token') to make problems visible, with no redaction layer. Vibe-coded apps also ship verbose/debug logging straight to production.

**Fix.** Per the OWASP Logging Cheat Sheet, do NOT log: authentication passwords, session identification values, access tokens, database connection strings, encryption keys and other primary secrets, sensitive PII, or bank/payment card holder data -- exclude, mask, sanitize, hash, or pseudonymize them instead, and de-identify PII where the identity isn't needed. Implement central redaction/scrubbing before logs are stored or displayed. Lower production log verbosity, never log full auth payloads, and protect/access-control the log store; do not expose log files via the web server. For Flask, configure structured logging with field filters/formatters that drop sensitive keys; for Electron, scrub renderer/main logs and crash reports before upload. Largely N/A to static sites (no server logs), though client-side error reporters (Sentry, etc.) should be configured to scrub tokens/PII before sending.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html> · <https://mas.owasp.org/MASWE/MASVS-STORAGE/MASWE-0001/>

### 36. Source maps exposed in production

**What it is.** Production builds ship .map files (or reference them), letting anyone reconstruct the original, unminified source -- comments, internal API endpoints, app logic, and sometimes hardcoded secrets. OWASP WSTG notes a source map connects minified assets back to the original authored source, making it human-readable.

**Why AI-coded apps hit it.** Default build configs from AI-generated setups (CRA, many Vite/webpack scaffolds) emit source maps, and vibe-coded deploys push the whole build output without stripping them. The convenience-by-default behavior means maps ship unless someone deliberately turns them off.

**Fix.** Don't serve source maps publicly in production. In webpack set devtool: false (or 'hidden-source-map' to keep maps for error reporting without referencing them in the bundle); for Create React App set GENERATE_SOURCEMAP=false; for Vite set build.sourcemap to false (the default) or 'hidden' (generates the map but suppresses the sourcemap comment in the bundle). If you need maps for an error service (Sentry/Rollbar), generate them, upload privately, and delete or block them from the public deploy (e.g. don't publish .map files, or block /*.map at the CDN/Cloudflare). Strip sourcesContent from any maps you do keep. Because exposed maps can reveal hardcoded secrets, also remove secrets from the codebase (see items 3/14). Applies to any built frontend, including static GitHub Pages sites and Electron renderers that bundle JS.

**Sources:** <https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/01-Information_Gathering/05-Review_Web_Page_Content_for_Information_Leakage> · <https://blog.sentry.security/abusing-exposed-sourcemaps/> · <https://vite.dev/config/build-options>

**Key references for this category:** [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html) · [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) · [OWASP WSTG - Review Web Page Content for Information Leakage (source maps, frontend secrets)](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/01-Information_Gathering/05-Review_Web_Page_Content_for_Information_Leakage) · [OWASP Top 10 A05:2021 Security Misconfiguration](https://owasp.org/Top10/2021/A05_2021-Security_Misconfiguration/) · [CWE-1392: Use of Default Credentials](https://cwe.mitre.org/data/definitions/1392.html) · [OWASP MASWE-0005: API Keys Hardcoded in the App Package](https://mas.owasp.org/MASWE/MASVS-AUTH/MASWE-0005/) · [OWASP MASWE-0001: Insertion of Sensitive Data into Logs](https://mas.owasp.org/MASWE/MASVS-STORAGE/MASWE-0001/) · [Supabase - Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security) · [Supabase - Understanding API keys (anon vs service_role)](https://supabase.com/docs/guides/getting-started/api-keys) · [GitHub Actions - Secure use reference (masking, OIDC, least privilege)](https://docs.github.com/en/actions/reference/security/secure-use) · [GitHub Docs - Removing sensitive data from a repository](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository) · [GitGuardian - Backend-for-Frontend pattern to stop leaking API keys](https://blog.gitguardian.com/stop-leaking-api-keys-the-backend-for-frontend-bff-pattern-explained/) · [Gitleaks - secret scanning tool](https://github.com/gitleaks/gitleaks) · [Sentry - Abusing Exposed Sourcemaps](https://blog.sentry.security/abusing-exposed-sourcemaps/) · [Vite - Build Options (build.sourcemap)](https://vite.dev/config/build-options)

---

## Authentication, authorization, access control & rate limiting

Broken access control is the most common and most damaging class of web/API vulnerability: it tops both the OWASP Top 10 (2021, A01) and the OWASP API Security Top 10 (2023, where BOLA and Broken Function Level Authorization are #1 and #5). AI/vibe-coded apps are especially prone to it because the LLM scaffolds a working "happy path" UI and CRUD endpoints but rarely adds the server-side ownership, role, and tenant checks that no test exercises, defaults to insecure backends (Firebase test mode, Supabase tables without RLS), trusts client-supplied IDs/roles, and almost never adds rate limiting. The unifying fix is to enforce every access decision on the server, deny by default, scope every query to the authenticated principal, and rate-limit every sensitive and AI endpoint. Most of this is N/A to pure static GitHub Pages sites (no server, no auth) but becomes critical the moment a Flask/Electron backend, a serverless function, or a BaaS like Firebase/Supabase is added.

### 4. Weak or missing authentication

**What it is.** Endpoints or pages that perform sensitive actions without verifying who the caller is, or that verify identity with broken/guessable mechanisms (no password hashing, predictable tokens, credentials in URLs, no MFA, no reauthentication for sensitive changes). OWASP tracks this as API2:2023 Broken Authentication.

**Why AI-coded apps hit it.** LLMs generate a login form and a working CRUD flow but frequently leave the actual auth check as a TODO, store passwords in plaintext or with a fast hash, or roll a bespoke token scheme instead of using a vetted library; the app 'works' in a demo so the gap is never noticed.

**Fix.** Use a vetted auth library/service rather than hand-rolling (e.g. Flask: Flask-Login/Authlib, or an IdP via OIDC). Store passwords with a slow, memory-hard adaptive hash: OWASP's first choice is Argon2id, then scrypt, with bcrypt for legacy environments where the others aren't available - never plaintext and never a fast hash like MD5/SHA1/SHA-256. Transmit credentials only over TLS and never in URLs/query strings. Validate JWT signature, issuer, audience, and expiry on every request; use short-lived tokens and invalidate sessions server-side on logout. Offer MFA (Microsoft data cited by OWASP: MFA stops ~99.9% of account-compromise attacks) and require reauthentication for sensitive changes (email/password). Use generic error messages ('Invalid user ID or password') to prevent user enumeration. N/A to static GitHub Pages (no server to authenticate against); critical for Flask/Electron backends and any BaaS-backed app.

**Sources:** <https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/> · <https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html> · <https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html>

### 5. No authorization checks

**What it is.** The app authenticates the user but never checks whether that user is allowed to perform the requested action. Authorization (what you can do) is distinct from authentication (who you are); A01:2021 lists missing function-level checks and least-privilege violations as core access-control failures.

**Why AI-coded apps hit it.** Generated code commonly stops at 'is the user logged in?' and never adds per-action permission logic; the LLM has no model of your roles/policies, so it emits handlers that act on any authenticated request.

**Fix.** Enforce authorization server-side on every request, denying by default and requiring an explicit grant. Centralize the decision in one reusable module/middleware invoked from all business functions rather than scattering ad-hoc checks (OWASP: implement access control once and re-use it throughout the application). Apply least privilege and RBAC/ABAC. In Flask, wrap routes in a decorator that asserts the required permission before the handler runs; never assume a logged-in user is an authorized user. N/A to static sites; essential for any backend or serverless endpoint.

**Sources:** <https://owasp.org/Top10/2021/A01_2021-Broken_Access_Control/> · <https://owasp.org/API-Security/editions/2023/en/0xa5-broken-function-level-authorization/>

### 6. Users able to access other users' data (BOLA)

**What it is.** Broken Object Level Authorization (API1:2023, the #1 API risk) - an endpoint that operates on an object identified by a client-supplied ID but never checks that the authenticated user owns or may access that specific object. Changing /orders/123 to /orders/124 returns someone else's data.

**Why AI-coded apps hit it.** Generated handlers typically do `Order.find(id)` straight from the request and return it; the ownership predicate is invisible in a single-user demo and the LLM omits it. Real incidents (T-Mobile, Optus, vehicle-control APIs) all stem from this pattern.

**Fix.** On every endpoint that takes an object ID, verify the authenticated principal is authorized for that exact object before acting. Scope the query to the user instead of filtering after fetch: use `current_user.orders.find(id)` (or `WHERE user_id = :current_user`) rather than `Order.find(id)`. With Supabase/Postgres, enforce this at the database with Row Level Security policies (e.g. `user_id = auth.uid()`). Prefer unpredictable IDs (UUIDs) as defense-in-depth, but never rely on obfuscation alone. Add automated tests that attempt cross-user access. N/A to static sites; critical for any multi-user backend or BaaS.

**Sources:** <https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/> · <https://supabase.com/docs/guides/database/postgres/row-level-security>

### 9. Admin routes left unprotected

**What it is.** Broken Function Level Authorization (API5:2023) - administrative or privileged endpoints that have no server-side role check, so any authenticated (or even unauthenticated) user who discovers the URL can call them, e.g. GET /api/admin/users/all or POST /api/invites/new with {"role":"admin"}.

**Why AI-coded apps hit it.** Vibe-coded apps hide the admin button in the UI but leave the backend route open, assuming 'no link = no access.' The LLM doesn't infer that /admin/* needs a guard, and endpoints are often guessable.

**Fix.** Apply explicit role/permission checks at the controller or middleware layer on every admin route - never rely on the UI hiding a button. Have all administrative controllers inherit from a base administrative controller that enforces the role check (OWASP recommendation), and audit admin handlers buried inside otherwise-regular controllers. Deny by default. Don't infer privilege from the URL path. Consider network-level restrictions (allowlist IPs / put admin behind auth at the Cloudflare/edge layer) as defense-in-depth. N/A to static sites; critical for any app with privileged functions.

**Sources:** <https://owasp.org/API-Security/editions/2023/en/0xa5-broken-function-level-authorization/> · <https://owasp.org/Top10/2021/A01_2021-Broken_Access_Control/>

### 28. Rate limits missing on login, signup, APIs, and AI endpoints

**What it is.** No throttling on sensitive or expensive endpoints, enabling credential stuffing / brute force on login, OTP and reset brute force, signup/spam abuse, scraping, and for AI endpoints 'Unbounded Consumption' (LLM10:2025) / Denial-of-Wallet where attackers run up huge inference bills.

**Why AI-coded apps hit it.** Rate limiting is operational plumbing the LLM never adds unless asked; the generated endpoint accepts unlimited requests, and AI-backed apps that proxy a paid LLM API are directly exposed to cost-amplification abuse.

**Fix.** Add per-account and per-IP throttling with account lockout (threshold + observation window + exponential backoff) on login, signup, password reset, OTP, and email-change; OWASP advises this anti-brute-force mechanism be stricter than your regular rate limiting. Pair with CAPTCHA and MFA against credential stuffing. Return HTTP 429 when limits are exceeded. Watch for batching bypasses (e.g. GraphQL query batching defeating per-request limits). For AI/LLM endpoints, apply strict per-user, per-session, and per-tenant quotas (daily/monthly), cap max input/output tokens and max agent iterations, set request timeouts, and add anomaly detection on consumption. In Flask use Flask-Limiter; at the edge, Cloudflare Rate Limiting Rules / WAF can throttle login and API paths even in front of static-ish apps. The Cloudflare edge layer is the one place a mostly-static GitHub Pages site can still benefit (e.g. protecting a contact-form or AI proxy function).

**Sources:** <https://genai.owasp.org/llmrisk/llm102025-unbounded-consumption/> · <https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/> · <https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html>

### 32. Payment or subscription checks only done on the frontend

**What it is.** Entitlement/paywall logic enforced only in client-side JS (hiding a feature, checking a 'pro' flag in the browser) while the backend serves the premium resource to anyone who calls it directly. Also includes trusting unverified webhook payloads to grant access.

**Why AI-coded apps hit it.** The LLM wires up Stripe Checkout and gates the UI, but the server endpoint that delivers the paid content has no entitlement check; client-side gates are trivially bypassed by editing JS or calling the API directly.

**Fix.** Treat the client as untrusted: verify entitlement server-side on every request for paid functionality, reading subscription state from your database, not from a client flag. Update that state only from Stripe webhooks whose signatures you verify with the official library (construct the event from the raw body + Stripe-Signature header + endpoint signing secret); use the raw/unparsed body for verification. Stripe's official constructEvent enforces a default 5-minute (300s) timestamp tolerance that blocks replay - keep it non-zero. Make event processing idempotent by storing processed event IDs. Never grant access based on a client-reported 'payment succeeded.' N/A to purely static sites with no backend; critical the moment a server/serverless function gates paid content.

**Sources:** <https://docs.stripe.com/webhooks> · <https://docs.stripe.com/webhooks/signature> · <https://owasp.org/Top10/2021/A01_2021-Broken_Access_Control/>

### 33. Insecure direct object references (IDOR)

**What it is.** The web/UI counterpart of BOLA: a request exposes a direct reference to an object (a DB key in a URL, parameter, or hidden field) and the app fails to verify the user is allowed that object, so manipulating the identifier accesses or edits another user's record. Listed explicitly under A01:2021.

**Why AI-coded apps hit it.** Generated routes pass `params[:id]` straight to a global lookup and render the result; without an ownership check this is IDOR, and it's invisible until a second user exists.

**Fix.** Per the OWASP IDOR Cheat Sheet, access-control validation is the primary defense - verify the user's permission on every object access. Scope lookups to the authenticated user's dataset (`current_user.projects.find(id)`), not the global table. Derive identity from the session, not from a client-supplied field. Use random/UUID identifiers as defense-in-depth only - obfuscation is not access control. Pass IDs through server-side session state in multi-step flows rather than user-editable parameters. N/A to static sites; critical for any backend that exposes record IDs.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Insecure_Direct_Object_Reference_Prevention_Cheat_Sheet.html> · <https://owasp.org/Top10/2021/A01_2021-Broken_Access_Control/>

### 34. API endpoints that trust user-controlled IDs or roles

**What it is.** Endpoints that bind client-supplied fields directly to internal objects, letting an attacker set fields they shouldn't - classically a mass-assignment privilege escalation by sending {"role":"admin"} or {"is_admin":true} in a profile/update request, or trusting a user_id/tenant_id from the request body. OWASP now tracks this as API3:2023 Broken Object Property Level Authorization (formerly Mass Assignment).

**Why AI-coded apps hit it.** ORM-style scaffolding the LLM emits often does `update(**request.json)` / `Model(**body)`, binding every field including sensitive ones; the model has no notion that role/is_admin/owner must be server-controlled.

**Fix.** Never trust client input to set authorization-relevant fields. Use an allowlist of bindable fields (explicit DTO/schema/serializer with read-only fields like role, is_admin, balance, tenant_id excluded) instead of blanket object binding - this is the OWASP mass-assignment mitigation. Avoid functions that automatically bind client input to object properties. Derive identity and tenant from the authenticated session/JWT claims, not from request parameters. Set privileged fields only through dedicated, role-checked admin paths. Validate and type-check all incoming data. N/A to static sites; critical for any write API.

**Sources:** <https://owasp.org/API-Security/editions/2023/en/0xa3-broken-object-property-level-authorization/> · <https://owasp.org/API-Security/editions/2019/en/0xa6-mass-assignment/>

### 49. Poor tenant isolation in multi-user apps

**What it is.** In multi-tenant/SaaS apps, one organization's users can read or modify another tenant's data because queries aren't reliably scoped by tenant, or the backend datastore is wide-open by default (Firebase test-mode rules `allow read, write: if true`; Supabase tables with RLS disabled, where the anon key can read/write everything).

**Why AI-coded apps hit it.** Vibe-coded apps lean on BaaS defaults: Firebase scaffolds in test mode (a leading cause of Firebase data exposure) and Supabase tables are exposed via the auto-generated Data API unless RLS is explicitly enabled - the LLM rarely writes the policies, and app-level tenant filters are easy to forget on one query.

**Fix.** Enforce tenant isolation at the data layer, not just in app code. For Supabase/Postgres, enable Row Level Security on every exposed table and write policies that match the tenant claim (e.g. `tenant_id = auth.jwt()->>'org_id'` or `user_id = auth.uid()`), index the columns the policies reference for performance, and test policies as different authenticated users (use the SQL Editor's role-impersonation feature or the client SDK - the SQL Editor runs as the postgres superuser and bypasses RLS by default, giving a false sense of security). Keep the service_role key strictly server-side - it bypasses all policies, so never ship it to the client. For Firebase, replace test-mode rules with authenticated, ownership/tenant-scoped Security Rules before deploying. Add a tenant_id/org_id to every table and verify cross-tenant access is denied with tests. N/A to static sites; critical for any multi-tenant backend or BaaS.

**Sources:** <https://firebase.google.com/docs/rules/insecure-rules> · <https://supabase.com/docs/guides/database/postgres/row-level-security>

**Key references for this category:** [OWASP API Security Top 10 2023 - API1:2023 Broken Object Level Authorization](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/) · [OWASP API Security Top 10 2023 - API2:2023 Broken Authentication](https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/) · [OWASP API Security Top 10 2023 - API3:2023 Broken Object Property Level Authorization](https://owasp.org/API-Security/editions/2023/en/0xa3-broken-object-property-level-authorization/) · [OWASP API Security Top 10 2023 - API5:2023 Broken Function Level Authorization](https://owasp.org/API-Security/editions/2023/en/0xa5-broken-function-level-authorization/) · [OWASP Top 10 2021 - A01 Broken Access Control](https://owasp.org/Top10/2021/A01_2021-Broken_Access_Control/) · [OWASP Cheat Sheet - Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html) · [OWASP Cheat Sheet - Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html) · [OWASP Cheat Sheet - Insecure Direct Object Reference (IDOR) Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Insecure_Direct_Object_Reference_Prevention_Cheat_Sheet.html) · [OWASP Top 10 for LLM Applications 2025 - LLM10:2025 Unbounded Consumption](https://genai.owasp.org/llmrisk/llm102025-unbounded-consumption/) · [OWASP API Security - API6:2019 Mass Assignment](https://owasp.org/API-Security/editions/2019/en/0xa6-mass-assignment/) · [Stripe Docs - Receive Stripe events in your webhook endpoint](https://docs.stripe.com/webhooks) · [Stripe Docs - Webhook signature verification](https://docs.stripe.com/webhooks/signature) · [Supabase Docs - Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security) · [Firebase Docs - Avoid insecure rules](https://firebase.google.com/docs/rules/insecure-rules)

---

## Injection & input validation

Injection flaws (OWASP A03:2021) happen whenever untrusted input is interpreted as code or query structure by a downstream interpreter: SQL, NoSQL/Mongo operators, OS shells, or the filesystem path resolver. They share one root cause: mixing data and command/structure in the same string. AI/vibe-coded apps are unusually prone to this because LLMs default to the shortest "happy path" pattern, which is almost always string concatenation or interpolation (f-strings, template literals) rather than parameter binding, and they routinely skip server-side validation because the generated UI "looks done." Independent 2025 analysis (Veracode) found roughly 45% of AI-generated code samples introduced a known OWASP-class weakness, with injection and missing input handling prominent among them. For you, the static GitHub Pages sites are largely out of scope (no server-side interpreter to inject into), but the Python/Flask and Electron apps are squarely in scope and are where these controls must be enforced.

### 16. Missing input validation

**What it is.** Input validation is checking that incoming data matches an expected type, length, range, format and set of allowed values before the app acts on it. "Missing" validation means the app trusts whatever the client sends (query params, JSON bodies, form fields, headers, file names), which is the precondition that lets injection, path traversal, type-confusion and business-logic abuse succeed. OWASP frames validation as a secondary defense layer, not the primary fix for injection, but its absence amplifies every other bug in this cluster.

**Why AI-coded apps hit it.** LLMs generate the visible client-side validation (HTML required attributes, a regex in JS) and stop there, because that satisfies the prompt and the demo. They rarely re-validate on the server, and OWASP is explicit that any client-side check can be trivially bypassed. Vibe-coded handlers also tend to pass req.body / request.json straight into logic with no schema, so unexpected types (arrays, objects, nulls) flow downstream unchecked.

**Fix.** Validate on the SERVER, before any processing, using an allowlist (define what IS allowed; reject everything else) rather than a denylist of "bad" characters. Prefer schema/type-driven validation libraries over hand-rolled regex: Pydantic or marshmallow for Flask, Zod/Joi for Node/Electron IPC, Django's built-in validators. Check type, length (e.g. {1,25}), numeric range, and for fixed sets require an exact match to one allowed value. Use whole-string anchored regexes (^...$) and bounded quantifiers to avoid ReDoS. Do syntactic validation (format) AND semantic validation (e.g. start date before end date). Keep client-side validation only as a UX nicety. N/A for purely static GitHub Pages sites that have no server endpoint; fully relevant to Flask routes and Electron main-process IPC handlers, which must treat every renderer/client message as untrusted.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html> · <https://top10proactive.owasp.org/the-top-10/c3-validate-input-and-handle-exceptions/> · <https://owasp.org/Top10/2021/A03_2021-Injection/>

### 17. SQL injection

**What it is.** SQL injection (CWE-89, part of OWASP A03:2021) occurs when user-supplied data is concatenated into a SQL statement so the input can change the query's structure, letting an attacker read, modify, or delete data, bypass auth, or in some cases run commands. It remains one of the highest-impact and most common web flaws.

**Why AI-coded apps hit it.** AI assistants overwhelmingly emit string-built queries like f"SELECT * FROM users WHERE email='{email}'" or cursor.execute("... " + name) because that is the most frequent pattern in training data and the most compact to generate. Veracode's 2025 testing found AI frequently failed to use safe parameterization in database code, and SQL injection via concatenation is a flagged AI-introduced pattern. The same risk now arrives second-hand via OWASP LLM05 Improper Output Handling, where an app runs SQL that the model itself generated without parameterizing.

**Fix.** Use parameterized queries / prepared statements for EVERY query, always binding values as parameters and never concatenating user input into the SQL string. In Python use cursor.execute("SELECT * FROM users WHERE email=%s", (email,)) (or ? for sqlite3) and never % / f-string formatting; or use an ORM (SQLAlchemy, Django ORM) which parameterizes by default. Bind parameters even inside LIKE clauses. Where a value cannot be bound because it is structural (table/column/ORDER BY direction), do NOT escape it; instead map the user input through an allowlist to a known-safe literal. Run the DB account with least privilege (no DDL/admin for the app user) and suppress raw DB error messages to clients. Treat any LLM-generated SQL as untrusted and parameterize it too. N/A to static sites with no database; relevant to Flask + any SQL backend and Electron apps using local SQLite.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html> · <https://owasp.org/Top10/2021/A03_2021-Injection/> · <https://genai.owasp.org/llmrisk/llm052025-improper-output-handling/>

### 18. NoSQL injection

**What it is.** NoSQL injection is the unsafe construction of query objects or query strings from untrusted input against document/key-value stores (MongoDB, etc.). Because queries are often JSON/BSON objects, the classic attack is operator injection: an attacker submits a value like {"$ne": null} or {"$gt": ""} (or a $where / $regex / $expr expression) so a field that should be a string becomes a query operator, bypassing auth or dumping data. $where and server-side JavaScript can even lead to remote code execution and CPU exhaustion.

**Why AI-coded apps hit it.** Generated Express/Mongo handlers commonly do db.collection.find({ username: req.body.username, password: req.body.password }) and pass req.body straight through. If the client sends JSON, req.body.username can itself be an object like {"$ne": null}, turning the lookup into an operator query. The model has no notion that the value's *type* is attacker-controlled, so it never type-checks or strips $ keys.

**Fix.** Type-check every value before it enters a query: ensure fields that should be strings/numbers are actually strings/numbers, not objects/arrays (e.g. reject if typeof !== 'string'). Reject operator injection by disallowing keys that begin with $ (and dotted keys) in client input; OWASP shows the blunt guard if (JSON.stringify(req.body).includes('"$')) throw Error("Invalid input"). Prefer enforcing this through the ODM rather than middleware: use Mongoose strict schemas (which cast/strip values that do not match the declared type) and Mongoose 8's sanitizeFilter:true option (wraps user-supplied values in $eq), or validate at the app layer with Zod/Joi/express-validator. Note: the once-common express-mongo-sanitize middleware is effectively unmaintained (no release since 2022) and breaks on Express 5, where req.query is read-only, so do not rely on it. Never accept raw JSON query fragments from the client to run as a query. Do not enable or expose $where, mapReduce, or server-side JS (these are deprecated as of MongoDB 8.0 and disabled by default; db.eval was removed in 4.2); avoid $regex / $expr on user input unless validated. Use the high-level ODM (Mongoose/Spring Data) query builders rather than hand-built query objects, and enforce TLS to the DB. N/A to static sites; relevant to any Flask/Node/Electron app talking to MongoDB or similar.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/NoSQL_Security_Cheat_Sheet.html> · <https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/07-Input_Validation_Testing/05.6-Testing_for_NoSQL_Injection> · <https://portswigger.net/web-security/nosql-injection>

### 22. Path traversal bugs

**What it is.** Path traversal (directory traversal, CWE-22) lets an attacker supply path sequences such as ../, encoded variants (%2e%2e%2f, ..%c0%af), absolute paths, or null-byte tricks (secret%00.pdf) so a file operation escapes the intended directory and reads or writes arbitrary files (e.g. /etc/passwd, app source, secrets). It is a frequent flaw in download, upload, template-include, and "serve this file" endpoints.

**Why AI-coded apps hit it.** When asked for a download/serve route, models generate the direct form, e.g. Flask open(os.path.join(UPLOAD_DIR, request.args['file'])) or send_file(some_path_with_user_input), with no canonicalization or base-directory check. They also use the user-supplied filename verbatim on upload. The naive os.path.join still resolves ../ and absolute paths, so the generated code looks correct but is exploitable. OWASP LLM05 also lists path traversal as a downstream risk when model output is used to build file paths.

**Fix.** Prefer not to put user input in filesystem paths at all: serve by an opaque ID mapped through a server-side allowlist/dictionary to the real filename. When you must use a name, canonicalize then verify containment: base = Path(UPLOAD_DIR).resolve(); target = (base / name).resolve(); if not target.is_relative_to(base): abort(404)  (is_relative_to requires Python 3.9+). In Flask, use send_from_directory() (it calls werkzeug safe_join internally) instead of send_file() with a built path, and run uploaded names through werkzeug.utils.secure_filename() before storing — note secure_filename only sanitizes the stored name, it does not by itself authorize the serve path, so keep the base-directory containment check too, and keep Werkzeug patched (safe_join has had bypass CVEs, e.g. CVE-2024-49766). Never decode-then-trust: validate after normalization, and reject names containing path separators, .., null bytes, or absolute roots. Avoid letting the user control the whole path; surround it with your own fixed prefix. In Electron, apply the same base-directory containment to any fs call driven by renderer input. N/A to static GitHub Pages (Cloudflare/GitHub serves files, no user-driven file API); directly relevant to Flask file routes and Electron file handling.

**Sources:** <https://owasp.org/www-community/attacks/Path_Traversal> · <https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html> · <https://portswigger.net/web-security/file-path-traversal>

**Key references for this category:** [OWASP Top 10:2021 A03 Injection](https://owasp.org/Top10/2021/A03_2021-Injection/) · [OWASP SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) · [OWASP NoSQL Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/NoSQL_Security_Cheat_Sheet.html) · [OWASP Input Validation Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html) · [OWASP Path Traversal (www-community)](https://owasp.org/www-community/attacks/Path_Traversal) · [PortSwigger Web Security Academy: File path traversal](https://portswigger.net/web-security/file-path-traversal) · [OWASP GenAI LLM05:2025 Improper Output Handling](https://genai.owasp.org/llmrisk/llm052025-improper-output-handling/)

---

## Client-side web vulns & security headers

This cluster covers the browser-facing attack surface: injection that runs in the victim's browser (XSS), forged authenticated requests (CSRF), the cross-origin trust boundary (CORS), and the response/cookie metadata that hardens all of the above (security headers, cookie flags). AI-generated code is especially prone here because LLMs reach for the shortest "make it work" path: string-concatenated HTML, innerHTML, permissive `cors(...)` defaults, and cookies set without flags. None of these break a demo, so they sail through "vibe coding" and only surface under attack. Note the audience split: a purely static GitHub Pages site behind Cloudflare has no server session, so CSRF/CORS/HttpOnly are largely N/A, but it still needs XSS discipline in its JS and a real set of security headers; the Flask and Electron apps need the full backend treatment.

### 19. Cross-site scripting (XSS)

**What it is.** An attacker injects HTML/JavaScript that executes in another user's browser session, letting them steal cookies/tokens, perform actions as the victim, or rewrite the page. Variants are reflected, stored, and DOM-based (the latter runs entirely client-side via unsafe sinks).

**Why AI-coded apps hit it.** LLMs frequently generate code that writes user/data-derived strings straight into the DOM with element.innerHTML, document.write, jQuery .html(), or React's dangerouslySetInnerHTML, and Flask/Jinja templates with autoescaping disabled or using the |safe filter. These patterns 'work' in the demo and the model has no awareness of the rendering context, so the encoding step is silently skipped.

**Fix.** Rely on framework auto-escaping (Jinja2 autoescape on, React/Vue/Angular default binding) and never reach for the escape hatches (|safe, dangerouslySetInnerHTML, bypassSecurityTrustHtml). Apply contextual output encoding for the exact sink (HTML body, attribute, JS, URL, CSS). For DOM code, prefer safe sinks: use textContent / setAttribute / insertAdjacentText instead of innerHTML; avoid eval, new Function, and setTimeout(string). When you must render user-authored HTML, sanitize with DOMPurify (client) or a vetted server sanitizer (e.g. bleach in Python) rather than hand-rolled regex. Add a strict Content-Security-Policy as defense-in-depth (nonce/hash-based script-src, 'strict-dynamic', object-src 'none', base-uri 'self') and consider Trusted Types (require-trusted-types-for 'script') on Chromium to block string-to-sink assignments. This applies fully to static GitHub Pages sites too, since DOM XSS lives entirely in client JS. Electron: enable contextIsolation, disable nodeIntegration, and never load remote content into a privileged renderer.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html> · <https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html> · <https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html>

### 20. Cross-site request forgery (CSRF)

**What it is.** A malicious page causes the victim's browser to send an authenticated state-changing request (using cookies the browser auto-attaches) to your app without the user's intent, e.g. changing an email or transferring funds.

**Why AI-coded apps hit it.** Generated backends commonly expose state-changing endpoints that authenticate purely via a session cookie and omit any anti-CSRF token. AI scaffolds (raw Flask routes, Express handlers) often skip CSRF middleware entirely, and models tend to assume SameSite cookies alone are sufficient, which OWASP explicitly says they are not in most deployments.

**Fix.** Use a synchronizer token (CSRF token) for cookie-authenticated, form/server-rendered apps: Flask-WTF / flask-seasurf generate a per-session unpredictable token validated on every POST/PUT/PATCH/DELETE. For stateless/SPA backends use the HMAC signed double-submit cookie pattern (the naive double-submit is bypassable by an attacker who can write cookies on the target domain). Never perform state changes on GET. As defense-in-depth, set session cookies SameSite=Lax (or Strict) and verify the Origin/Referer header against an allowlist. For pure JSON APIs called via fetch, require a custom header (e.g. X-CSRF-Token or X-Requested-With) which forces a CORS preflight and blocks simple cross-site form posts. Largely N/A to static GitHub Pages sites (no server-side session/state to forge); fully relevant to the Flask apps. Token-based bearer auth in an Authorization header (not a cookie) is inherently not CSRF-able.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html> · <https://owasp.org/www-community/attacks/csrf> · <https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie>

### 27. Overly permissive CORS

**What it is.** Cross-Origin Resource Sharing headers that are too loose let arbitrary websites read responses from your API. The dangerous patterns are reflecting any Origin back, Access-Control-Allow-Origin: * on authenticated endpoints, combining credentials with a wildcard, or trusting the null origin.

**Why AI-coded apps hit it.** When a developer hits a CORS error in the console, models 'fix' it by pasting the broadest possible config: app.use(cors()) with no options, CORS_ORIGINS='*', or reflecting request.headers.origin straight back into Access-Control-Allow-Origin while also setting Allow-Credentials: true. This silences the error but opens the API to every origin. Reflecting the origin while allowing credentials is functionally equivalent to wildcard-with-credentials, the exact case browsers try to forbid.

**Fix.** Maintain an explicit server-side allowlist of exact origins (scheme+host+port); echo the request Origin only after it matches, otherwise send no CORS headers. Add Vary: Origin so caches don't serve one origin's response to another. Never combine Access-Control-Allow-Credentials: true with Access-Control-Allow-Origin: * (browsers reject it) and never reflect arbitrary origins when credentials are on. Do not trust the null origin. Avoid loose regex like /example\.com$/ that also matches evil-example.com. Restrict Allow-Methods and Allow-Headers to what's actually used. In Flask use flask-cors with an explicit origins=[...] list, not the default. Mostly N/A to a static GitHub Pages site that serves its own assets (same-origin); relevant whenever the Flask/Electron apps expose an API consumed from another origin.

**Sources:** <https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS> · <https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS/Errors/CORSNotSupportingCredentials> · <https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Access-Control-Allow-Credentials>

### 46. Missing security headers

**What it is.** Browsers harden a site based on response headers. Absent headers like Content-Security-Policy, Strict-Transport-Security (HSTS), X-Content-Type-Options, X-Frame-Options, Referrer-Policy, and Permissions-Policy leave the app exposed to XSS, clickjacking, MIME sniffing, protocol downgrade, and referrer/feature leakage.

**Why AI-coded apps hit it.** Header configuration is invisible at the application logic level, so it almost never appears in AI-generated code unless explicitly requested. Default framework responses and unconfigured static hosts ship none of these, and a working site gives no signal that they're missing.

**Fix.** Apply the OWASP Secure Headers baseline: Strict-Transport-Security: max-age=63072000; includeSubDomains (add preload once verified — preload requires max-age >= 31536000 and includeSubDomains); Content-Security-Policy starting from default-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; X-Content-Type-Options: nosniff; Referrer-Policy: no-referrer or strict-origin-when-cross-origin; a restrictive Permissions-Policy disabling unused features (camera, geolocation, microphone). For clickjacking, prefer CSP frame-ancestors 'none' (the modern replacement) and additionally send X-Frame-Options: DENY for older browsers. Also strip information-disclosure headers (Server, X-Powered-By). For static GitHub Pages sites this is the single highest-leverage hardening step and is best done at the edge: Cloudflare Transform Rules / response-header rules (or a _headers file on some hosts) can inject all of these without touching the site. For Flask, use flask-talisman or an after_request hook. Verify with the Mozilla Observatory or securityheaders.com.

**Sources:** <https://owasp.org/www-project-secure-headers/> · <https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html> · <https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Strict-Transport-Security>

### 47. Cookies missing HttpOnly, Secure, or SameSite

**What it is.** Session/auth cookies set without protective attributes can be stolen by JavaScript (no HttpOnly), sent over plaintext HTTP (no Secure), or attached to cross-site requests enabling CSRF (no SameSite).

**Why AI-coded apps hit it.** Code that sets cookies via low-level calls (response.set_cookie(...), res.cookie(...), document.cookie) defaults to none of these flags, and AI samples typically show the bare minimal call. The cookie works identically with or without the flags during testing, so the omission is never noticed.

**Fix.** Set session/auth cookies with HttpOnly (blocks document.cookie / XSS theft), Secure (HTTPS-only), and SameSite=Lax or Strict (CSRF defense-in-depth). SameSite=None must always be paired with Secure or browsers reject it. Prefer the __Host- prefix (e.g. Set-Cookie: __Host-session=...; Secure; HttpOnly; Path=/; SameSite=Strict), which forces Secure, Path=/, and no Domain, binding the cookie to the exact origin. In Flask set SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SECURE=True, SESSION_COOKIE_SAMESITE='Lax', and use REMEMBER_COOKIE_* equivalents. Note HttpOnly cookies are still sent by fetch/XHR, so it does not break API calls. Mostly N/A to static GitHub Pages sites (no server-set session cookies); essential for the Flask apps. Caveat: tokens you must read from JS (some SPA patterns) can't be HttpOnly, so prefer keeping session identifiers in HttpOnly cookies rather than localStorage.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html> · <https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie> · <https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/06-Session_Management_Testing/02-Testing_for_Cookies_Attributes>

**Key references for this category:** [OWASP Cheat Sheet Series - Cross Site Scripting Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html) · [OWASP Cheat Sheet Series - DOM based XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html) · [OWASP Cheat Sheet Series - Cross-Site Request Forgery Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html) · [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/) · [OWASP Cheat Sheet Series - HTTP Security Response Headers](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html) · [OWASP Cheat Sheet Series - Content Security Policy](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html) · [OWASP Cheat Sheet Series - Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) · [MDN Web Docs - Cross-Origin Resource Sharing (CORS)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS) · [MDN Web Docs - Set-Cookie header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie) · [OWASP Web Security Testing Guide - Testing for Cookies Attributes](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/06-Session_Management_Testing/02-Testing_for_Cookies_Attributes)

---

## Sessions, JWT & password reset

Authentication state is where AI-generated code most often goes wrong, because LLMs reproduce the "happy path" tutorial pattern (sign a token, email a link, set a cookie) without the security invariants that make it safe: single-use hashed reset tokens, server-side session regeneration, strict algorithm pinning, and high-entropy secrets pulled from a vault rather than a hard-coded literal. These three items are tightly coupled: a weak reset flow, a guessable/non-rotating session, or a forgeable JWT each independently yields full account takeover. The fixes below are grounded in the OWASP Forgot Password, Session Management, and JWT cheat sheets, the OWASP Web Security Testing Guide, the OWASP API Security Top 10 (2023, API2 Broken Authentication), and PortSwigger's JWT research. Note for you: items 24-26 are almost entirely backend concerns (Flask sessions/auth, any Electron app talking to an API). They are N/A to a pure static GitHub Pages site that has no login, no server-side session, and issues no tokens; they become relevant the moment a Flask/serverless backend or third-party auth (Supabase/Firebase/Auth0) is added.

### 24. Broken password reset flows

**What it is.** Flaws in the forgot-password / account-recovery path that let an attacker take over an account: predictable or long-lived reset tokens, tokens stored in plaintext, tokens that are reusable, reset endpoints with no rate limiting (so 4-6 digit SMS/email codes can be brute-forced), account enumeration via different responses or timings, and host-header / referrer leakage of the reset link. OWASP API Security Top 10 (2023) folds these into API2:2023 Broken Authentication and recommends treating credential-recovery/forgot-password endpoints as login endpoints for brute-force, rate-limiting, and lockout protections.

**Why AI-coded apps hit it.** LLMs emit the canonical tutorial reset flow (generate a token, email a {{host}}-based link, look it up, set the new password) which omits hashing the stored token, single-use invalidation, expiry, rate limiting, and constant-time/enumeration-safe responses. Generated code also commonly builds the reset URL from the request Host header and auto-logs the user in after reset, both of which the model copies from blog examples that prioritized brevity over safety.

**Fix.** Backend/dynamic apps only (N/A to a static GitHub Pages site with no accounts). Generate the token with a CSPRNG (Python: secrets.token_urlsafe(32) yields 32 random bytes / 256 bits, well above the 128-bit floor); store only a SHA-256 hash of it (so a DB leak cannot be replayed) and compare hashes in constant time on validation. A fast hash like SHA-256 is fine here because the token is already high-entropy and random (unlike a password, it does not need a slow hash like bcrypt/Argon2). Make tokens single-use and short-lived (15-60 min) and invalidate them after use or after a new request. Rate-limit reset requests per-account and per-IP and add CAPTCHA on repeated attempts to stop token/PIN brute force; for SMS PINs use 6+ digits plus a short-lived reset-only session, never a 4-digit code without throttling. Prevent enumeration: return one identical 'if that account exists we sent a link' message and keep response timing uniform for existing vs non-existing accounts. Do not build the reset link from the user-controllable Host header - hard-code the canonical base URL or validate against an allowlist, force HTTPS, and send Referrer-Policy: no-referrer so the token does not leak to third parties. After a successful reset, send a confirmation email (never the new password), require the user to log in again rather than auto-authenticating, and invalidate all of that user's existing sessions. Re-prompt for the current password before sensitive changes (email/password/2FA). Prefer a vetted library/provider (Flask-Security, Django auth, Supabase/Auth0/Firebase Auth) over hand-rolling the flow.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html> · <https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/> · <https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/04-Authentication_Testing/09-Testing_for_Weak_Password_Change_or_Reset_Functionalities>

### 25. Weak session management

**What it is.** Sessions that an attacker can guess, steal, or fixate: low-entropy or predictable session IDs, missing cookie protections (no Secure/HttpOnly/SameSite), session IDs passed in URLs, session tokens kept in localStorage (XSS-readable), failure to regenerate the session ID on login/privilege change (session fixation), and missing idle/absolute timeouts or server-side invalidation on logout. The OWASP Session Management Cheat Sheet treats these as the core controls; getting any one wrong can yield account takeover.

**Why AI-coded apps hit it.** Generated auth scaffolding frequently sets a session or JWT cookie without the Secure/HttpOnly/SameSite attributes, stores the token in localStorage because that is the simplest JS pattern, and never regenerates the session on login - so session fixation and XSS theft are wide open. Models also rarely add idle/absolute timeouts or a real server-side logout, since the tutorial 'login works' demo does not need them.

**Fix.** Backend/dynamic apps (N/A to a static site that stores no session). Use the framework's built-in session manager (Flask's signed session with Flask-Login, or Django sessions) rather than rolling your own; ensure session IDs come from a CSPRNG with >=64 bits of entropy (OWASP minimum) and carry no meaning. Set cookies as: Secure; HttpOnly; SameSite=Strict (or Lax); use the __Host- name prefix (e.g. Set-Cookie: __Host-session=...; Secure; HttpOnly; SameSite=Strict; Path=/) so the cookie is locked to the origin with no Domain. Never put the session ID in a URL and never store auth/session tokens in localStorage or sessionStorage (XSS-exfiltratable) - prefer HttpOnly cookies or a Backend-for-Frontend. Regenerate/rotate the session ID on every login and privilege change to kill session fixation. Note Flask's default session is a signed client-side cookie with no server-side ID to rotate, and there is no session.regenerate() method: either use Flask-Login (login_user() plus its session-protection mode, and clear the session on logout) or use server-side sessions via Flask-Session and call current_app.session_interface.regenerate(session) after populating the new identity (Django: request.session.cycle_key() / django.contrib.auth.login). Enforce a server-side idle timeout (15-30 min typical, 2-5 min for high-value) and an absolute timeout (e.g. 4-8 h); on logout call the server-side invalidation method (e.g. session.clear() / logout_user(), Django's logout()) - do not merely delete the cookie client-side. Serve everything over HTTPS with HSTS, and emit Cache-Control: no-store on authenticated responses. For static-only sites these controls are not applicable, but enabling Cloudflare 'Always Use HTTPS' + HSTS is still good baseline hygiene.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html> · <https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie> · <https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/>

### 26. JWT secrets that are weak, leaked, or reused

**What it is.** JSON Web Tokens whose integrity can be broken: HMAC (HS256) signing keys that are short, default ('secret', 'changeme'), committed to the repo, or reused across environments and therefore brute-forceable; acceptance of the alg:none token (no signature); algorithm-confusion where an RS256 verifier is tricked into treating the public key as an HMAC secret; using decode() without verification so the signature is never checked; and jku/jwk/kid header injection pointing the verifier at attacker-controlled keys. Any of these lets an attacker forge a token for any user. OWASP API2:2023 lists accepting unsigned/weakly-signed JWTs (alg:none) and not validating expiry as broken authentication.

**Why AI-coded apps hit it.** AI code routinely hard-codes a placeholder HMAC secret (JWT_SECRET = 'secret') or reads one with a weak default, and that literal often ends up committed to GitHub where it is both reused and leaked. Generated verification code frequently fails to pin the algorithm (or calls a decode path without verification), and stuffs sensitive data into the base64 payload assuming it is encrypted - all patterns the model learned from quick-start snippets that never hardened.

**Fix.** Backend/dynamic apps that issue or verify tokens (N/A to a static site that issues none). For HMAC, use a CSPRNG-generated secret of at least 256 bits / 32 bytes (the OWASP JWT cheat sheet suggests at least 64 characters); never use a default, never commit it - load it from an env var or secret manager (Vault, AWS Secrets Manager, Cloudflare Workers secrets) and rotate it. Use a distinct secret per environment and per service - never reuse. Prefer asymmetric signing (RS256/ES256) for anything multi-service so the signing key is not shared with verifiers. Pin the accepted algorithm explicitly on verification and reject alg:none and any unexpected alg (PyJWT: always pass algorithms, e.g. jwt.decode(token, key, algorithms=['HS256']); note PyJWT's decode() does verify the signature by default and raises on a bad/none signature - the danger is verify=False or an unpinned algorithms list, which enables alg:none and RS256->HS256 confusion). Validate exp, plus iss and aud claims; keep access tokens short-lived and pair with refresh tokens. Constrain or ignore attacker-controllable header params - allowlist hosts for jku, do not honor inline jwk, and sanitize kid against path-traversal/SQLi. Treat the payload as readable (base64, not encrypted): put no secrets in it, or use JWE/AES-GCM if confidentiality is needed. Maintain a revocation/denylist (store a hash of revoked tokens or their jti) so logout and password reset can actually invalidate tokens. Scan the repo and CI with a secret scanner (gitleaks, GitHub secret scanning) to catch leaked JWT keys.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_Cheat_Sheet.html> · <https://portswigger.net/web-security/jwt> · <https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/06-Session_Management_Testing/10-Testing_JSON_Web_Tokens>

**Key references for this category:** [OWASP Forgot Password Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html) · [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) · [OWASP JSON Web Token for Java Cheat Sheet (canonical OWASP JWT cheat sheet)](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html) · [OWASP API Security Top 10 (2023) - API2 Broken Authentication](https://owasp.org/API-Security/editions/2023/en/0xa2-broken-authentication/) · [OWASP WSTG - Testing JSON Web Tokens](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/06-Session_Management_Testing/10-Testing_JSON_Web_Tokens) · [PortSwigger Web Security Academy - JWT attacks](https://portswigger.net/web-security/jwt) · [MDN - Set-Cookie header (cookie attributes)](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie)

---

## SSRF, webhooks & file uploads

These three flaws share one root cause: the backend acts on attacker-controlled input (an uploaded file, a URL to fetch, or a webhook payload) without authenticating or validating it first. LLMs scaffold the happy path that works on test data and omit the security checks. This category is critical for any app with a server backend that processes external input, but is largely irrelevant to purely static sites with no server-side request handling.

### 21. Insecure file uploads

**What it is.** An upload endpoint that stores arbitrary files without validation enables webshell RCE, stored XSS, path traversal, and zip-bomb DoS.

**Why AI-coded apps hit it.** LLMs trust the easily spoofed Content-Type header or a weak client-side extension regex, and rarely add content (magic-byte) validation, off-webroot storage, or auth.

**Fix.** Allowlist permitted extensions (never blocklist); validate the file's actual content/magic bytes server-side, not the spoofable Content-Type; rename to a server-generated UUID so attacker input never reaches the path; store outside the webroot (ideally on a separate host or object store) and serve with Content-Disposition: attachment and X-Content-Type-Options: nosniff; enforce size limits; scan with antivirus/sandbox where available; and require authentication and authorization to upload. Defense in depth - no single control is sufficient.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html> · <https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload>

### 23. Server-side request forgery (SSRF)

**What it is.** Fetching an attacker-supplied URL without validation lets the server reach internal services or the cloud metadata endpoint (169.254.169.254) to steal IAM credentials. OWASP Top 10 A10:2021.

**Why AI-coded apps hit it.** LLMs scaffold URL-fetch features (image proxies, link previews, webhooks-out) with no allowlist and default HTTP clients that follow redirects.

**Fix.** Prefer an allowlist of permitted scheme/host/port. For arbitrary-URL features, resolve the hostname and reject any address in private, loopback, or link-local ranges (127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, and IPv6 equivalents) before connecting, and pin that validated IP for the actual request to defeat DNS-rebinding/TOCTOU bypass. Disable HTTP redirect following. Enforce network-layer egress restrictions/segmentation so the app cannot reach internal hosts or the metadata service. On AWS, require IMDSv2.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html> · <https://owasp.org/Top10/A10_2021-Server-Side_Request_Forgery_%28SSRF%29/>

### 31. Webhook endpoints without signature verification

**What it is.** Processing a webhook without proving its origin or preventing replay lets attackers forge events (e.g. a fake 'payment succeeded') to trigger fulfillment or unlock paid features.

**Why AI-coded apps hit it.** LLMs ship a JSON handler that works against test events and skip the signing-secret check, raw-body requirement, and replay protection.

**Fix.** Verify the signature with the provider's SDK over the exact raw request bytes (frameworks that re-serialize JSON break verification); use a constant-time comparison; enforce a timestamp tolerance (e.g. Stripe's default 5 minutes, never 0) to reject replays; deduplicate by event ID so retried/duplicated deliveries are idempotent; and require HTTPS. Treat the payload as untrusted until the signature is validated.

**Sources:** <https://docs.stripe.com/webhooks> · <https://docs.svix.com/receiving/verifying-payloads/why>

**Key references for this category:** [OWASP File Upload Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html) · [OWASP SSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html) · [OWASP Top 10 A10:2021 - Server-Side Request Forgery](https://owasp.org/Top10/A10_2021-Server-Side_Request_Forgery_%28SSRF%29/) · [Stripe - Verify webhook signatures](https://docs.stripe.com/webhooks)

---

## Data stores & cloud config (Firebase/Supabase/S3)

Backend-as-a-service platforms (Firebase, Supabase) and object stores (S3) push the authorization boundary all the way to the client: the database is reachable directly from the browser using a publishable key, so the *only* thing standing between an attacker and your data is the rules/policies you configure. AI-coding tools and "vibe-coded" apps routinely ship the permissive "test mode" defaults the assistant scaffolds, leak admin-grade keys into client bundles, and skip Row Level Security entirely. This is not theoretical: in May 2025 security researcher Matt Palmer disclosed CVE-2025-48757 (NVD-published, CVSS 9.3 critical, though disputed by Lovable), and his accompanying scan found 303 endpoints across 170+ AI-generated Lovable/Supabase apps (about 10.3% of the ~1,645 scanned) with tables readable by unauthenticated requests; a separate vendor analysis attributes roughly 83% of Supabase exposures to missing/misconfigured RLS. For you, these four items are mostly relevant when a project actually has a backend (Supabase/Firebase, an S3 bucket, or a Flask DB); they are largely N/A to pure static GitHub Pages sites, which have no data store to misconfigure.

### 7. Open database read/write permissions

**What it is.** The data store accepts reads and/or writes from anyone with no authorization gate, so any visitor (or anyone who guesses the project ID) can list, modify, or delete records. In Firebase this is rules like `.read: true` / `allow read, write: if true`; in Supabase it is a table with Row Level Security disabled (or never enabled) that is reachable through the public anon key; in S3 it is a bucket policy or ACL granting `Principal: *`.

**Why AI-coded apps hit it.** AI assistants generate 'quick start' / 'test mode' rules that allow unrestricted access so the demo works on the first try, and you ships before tightening them. Firebase test mode and Supabase's RLS-off default (tables created via SQL or the Table Editor have RLS off) both leave the door open unless the developer takes a deliberate second step the assistant rarely prompts for.

**Fix.** Backend/BaaS only (N/A to pure static sites). Firebase: never deploy `allow read, write: if true` or `.read/.write: true`; require `request.auth != null` AND scope every rule to the owning user/record, e.g. `allow read, write: if request.auth.uid == userId` (Firestore) or `"$uid": { ".write": "auth.uid === $uid" }` (RTDB). Remember RTDB rules cascade: a permissive parent path overrides stricter child paths (children can only add access, never restrict it). Validate with the Firebase Emulator/Rules Simulator before deploy. Supabase: run `alter table <t> enable row level security;` on every table in an exposed schema, then add explicit policies (see item 41). Verify by querying the table unauthenticated with the anon key over the REST/client API (the SQL editor runs as a privileged role and bypasses RLS, so do NOT test there) and confirming it returns 0 rows. S3: enable Block Public Access and remove any `Principal: "*"` or `Action: "*"` statements (see item 8).

**Sources:** <https://firebase.google.com/docs/rules/insecure-rules> · <https://supabase.com/docs/guides/database/postgres/row-level-security> · <https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/>

### 8. Misconfigured Firebase / Supabase / S3 buckets

**What it is.** The specific platform-level misconfigurations that expose data even when an app 'looks' secure: Supabase tables left without RLS but reachable via the public anon key; the Supabase service_role key (which bypasses RLS entirely) shipped in client-side JavaScript; Firebase rules left in test mode; and S3 buckets made public via ACLs or a wildcard bucket policy. CVE-2025-48757 and the associated Lovable scan catalogued this exact pattern across 170+ AI-generated apps.

**Why AI-coded apps hit it.** Vibe-coding stacks (Lovable, Replit, Bolt + Supabase/Firebase) embed keys and DB config directly into the JS bundle, where they are visible to anyone who views source, and developers frequently confuse the safe anon/publishable key with the admin service_role key, pasting the latter into frontend code and handing attackers full database access. Older S3 buckets (pre-April 2023) and ones created by ad-hoc scripts may not have Block Public Access on.

**Fix.** Supabase: the anon (publishable) key is safe in the browser ONLY when RLS is enabled on every exposed table; grep your entire frontend/repo for `service_role` and ensure zero hits in any client-shipped code, it belongs only in server-side code/Edge Functions/secrets. Review policies under Authentication -> Policies. Firebase: the API key in the web config is not a secret, but it is harmless only if Security Rules are locked down; move off test mode and scope rules to auth + ownership. S3: turn on all four Block Public Access settings (BlockPublicAcls, IgnorePublicAcls, BlockPublicPolicy, RestrictPublicBuckets) at BOTH the account and bucket level (Security Hub control S3.8); disable ACLs via S3 Object Ownership = Bucket owner enforced; remove `Principal: "*"` policies; use IAM Access Analyzer for S3 and AWS Config rules `s3-bucket-public-read-prohibited`/`s3-bucket-public-write-prohibited` as ongoing detective controls. For a public static site, prefer keeping the bucket private and serving via CloudFront with Origin Access Control rather than making the bucket public. For your GitHub Pages + Cloudflare setup, there is typically no bucket to manage, so this is N/A unless a project adds Supabase/Firebase/S3.

**Sources:** <https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html> · <https://supabase.com/docs/guides/api/securing-your-api> · <https://firebase.google.com/docs/rules/insecure-rules>

### 41. Excessive database permissions for the app user

**What it is.** The credentials the application connects with have far more power than the app needs, e.g. a Postgres superuser or the Supabase service_role, or a single Firebase rule that grants blanket access to authenticated users. This violates least privilege: a SQL-injection bug, a leaked key, or a logic flaw then has the blast radius of an admin rather than of one feature. It also overlaps with OWASP API1:2023 BOLA, where any logged-in user can reach objects they don't own.

**Why AI-coded apps hit it.** Generated backends default to the most permissive role so everything 'just works', service_role keys in serverless functions, `allow read, write: if request.auth != null` (any logged-in user can read everyone's data), or a Flask app connecting as the DB owner. The assistant optimizes for the happy path, not for scoping a dedicated low-privilege role per app.

**Fix.** Backend/DB apps (N/A to static sites). Postgres/Flask: create a dedicated app role, never connect as superuser or the DB owner; revoke defaults and grant only what's needed (CONNECT, plus SELECT/INSERT/UPDATE/DELETE on specific tables; a separate read-only role for reporting). Set sane default privileges for future tables (ALTER DEFAULT PRIVILEGES). Use parameterized/prepared statements for all queries regardless of role (never string-concatenate SQL). Supabase: grant each role (anon/authenticated) the minimum table privileges, keep RLS as the row-level gate, and use WITH CHECK on INSERT/UPDATE and USING on SELECT/DELETE so users can only touch their own rows (e.g. `using ((select auth.uid()) = user_id)`); use the `(select auth.uid())` wrapper so Postgres caches the result per statement instead of per row (large performance win on big tables). Firebase: scope rules to ownership/role rather than mere authentication, and use document lookups (`get(/databases/$(db)/documents/users/$(uid)).data.role`) for RBAC. Across all of these, follow OWASP API1:2023: in every endpoint that takes a client-supplied ID, verify the authenticated user actually owns that object, never trust the ID, and prefer unguessable UUIDs over sequential IDs. Add automated tests that fail the build if an unauthorized access path succeeds.

**Sources:** <https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/> · <https://supabase.com/docs/guides/database/postgres/row-level-security> · <https://www.postgresql.org/docs/current/ddl-priv.html>

### 48. Unencrypted sensitive data (at rest / in transit)

**What it is.** Sensitive data (credentials, PII, tokens, financial data) transmitted or stored in plaintext, or protected with weak/absent cryptography, OWASP A02:2021 Cryptographic Failures (formerly 'Sensitive Data Exposure'). Covers serving content over HTTP, storing passwords without strong hashing, and storing secrets/PII unencrypted at rest.

**Why AI-coded apps hit it.** Generated apps commonly store passwords with a fast/plain hash (or none), persist API keys and PII in plaintext in the DB or in localStorage, return sensitive data with cacheable responses, and skip HSTS, because the assistant produces a working flow, not a hardened one. The 'it works over localhost' mindset carries unencrypted patterns into production.

**Fix.** In transit (applies to ALL sites, including static): serve everything over HTTPS/TLS only and enforce it, for you's Cloudflare-fronted GitHub Pages sites, set SSL/TLS mode to Full (strict), enable 'Always Use HTTPS', and add a Strict-Transport-Security header (e.g. `max-age=63072000; includeSubDomains; preload`) via a Cloudflare Transform/Response Header rule. For S3-served content, deny non-TLS requests with a bucket policy condition on `aws:SecureTransport: false`. At rest (backend/DB apps): classify data and don't store what you don't need; hash passwords with a strong adaptive, salted KDF (Argon2id, scrypt, bcrypt, or PBKDF2), never MD5/SHA-1/SHA-256-alone; encrypt sensitive columns/blobs with authenticated encryption (AEAD such as AES-GCM); manage keys outside the app (a secrets manager / KMS), never hardcoded. S3 encrypts new objects with SSE-S3 by default; use SSE-KMS for sensitive buckets. Supabase/Postgres and Firebase encrypt at rest by default at the platform level, but that does NOT protect a field that is readable through bad rules, so pair encryption with items 7/41. Also set `Cache-Control: no-store` on responses containing sensitive data. Verify TLS config with SSL Labs and confirm HSTS is present.

**Sources:** <https://owasp.org/Top10/2021/A02_2021-Cryptographic_Failures/> · <https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html> · <https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Strict-Transport-Security>

**Key references for this category:** [OWASP API Security Top 10 2023 — API1:2023 Broken Object Level Authorization](https://owasp.org/API-Security/editions/2023/en/0xa1-broken-object-level-authorization/) · [OWASP Top 10:2021 — A02 Cryptographic Failures](https://owasp.org/Top10/2021/A02_2021-Cryptographic_Failures/) · [Supabase Docs — Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security) · [Supabase Docs — Securing your API (anon vs service_role, grants + RLS)](https://supabase.com/docs/guides/api/securing-your-api) · [Firebase — Avoid insecure rules](https://firebase.google.com/docs/rules/insecure-rules) · [AWS — Blocking public access to your Amazon S3 storage (four BPA settings)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html) · [AWS — Security best practices for Amazon S3 (encryption, TLS, least privilege)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html) · [MDN — Strict-Transport-Security (HSTS) header](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Strict-Transport-Security) · [NVD — CVE-2025-48757 (Lovable insufficient RLS; disputed)](https://nvd.nist.gov/vuln/detail/CVE-2025-48757)

---

## Exposure & environment hygiene

This cluster covers the ways AI-coded and vibe-coded apps accidentally leak their internals or ship developer conveniences to the public internet: live debug pages, verbose stack traces, security logic that exists only in the browser, "temporary" staging/test deployments that never get locked down, and internal dashboards left reachable from anywhere. These map directly to OWASP A05:2021 Security Misconfiguration and API8/API9:2023, and they matter because AI assistants optimize for "make it run" over "make it safe": they default to debug mode, echo exceptions to the user, validate only client-side, and never configure environment separation or access controls the user didn't explicitly ask for. The fixes are mostly configuration and architecture, not code, and several are partly N/A to purely static GitHub Pages sites but critical for the Flask and Electron backends.

### 10. Debug pages exposed in production

**What it is.** An interactive debugger or developer error page is reachable in a live, internet-facing deployment. The worst case is Flask/Werkzeug's debugger, which renders an in-browser console that executes arbitrary Python on the server when an unhandled exception occurs; it is only PIN-protected and Flask explicitly says that PIN must not be relied on for security. Django's DEBUG=True and similar dev modes leak settings, environment variables, and stack traces the same way.

**Why AI-coded apps hit it.** AI scaffolds almost universally start an app with debug enabled because it makes local development work out of the box: generated Flask code commonly ends in app.run(debug=True), and templates set FLASK_DEBUG=1 (or the now-removed FLASK_ENV=development in older snippets). Vibe-coders copy the working dev command straight to the server, so the debugger and its remote-code-execution console ship to production. Patreon was breached in 2015 (a ~15 GB dump of live data was posted) precisely through an exposed Werkzeug debugger that had been visible on Shodan for weeks.

**Fix.** Never run the development server or built-in debugger in production. For Flask set debug=False and gate any debug on an explicit env var (e.g. app.run(debug=os.environ.get('FLASK_DEBUG')=='1')); note FLASK_ENV was removed in Flask 2.3, so use FLASK_DEBUG or the flask run --debug flag, not FLASK_ENV. Serve behind a real WSGI server (gunicorn/uWSGI) rather than app.run; for Django set DEBUG=False and configure ALLOWED_HOSTS. Capture errors with a logging/monitoring tool such as Sentry instead of an in-browser debugger. Add a CI/static-analysis gate (CodeQL py/flask-debug, Bandit) that fails the build if debug mode is detected. Audit your routes/inventory for leftover debug or test endpoints (OWASP API9 Improper Inventory). N/A to pure static GitHub Pages sites, which have no server-side debugger; for Electron, disable the remote DevTools/inspector in packaged builds. This is OWASP A05:2021 Security Misconfiguration ('unnecessary features such as debugging enabled').

**Sources:** <https://owasp.org/Top10/2021/A05_2021-Security_Misconfiguration/> · <https://flask.palletsprojects.com/en/stable/debugging/> · <https://codeql.github.com/codeql-query-help/python/py-flask-debug/>

### 12. Verbose error messages leaking stack traces

**What it is.** When an exception occurs, the application returns the full stack trace, framework/library versions, SQL queries, file paths, or even secrets to the end user instead of a generic message. Stack traces are not vulnerabilities themselves but they hand attackers a reconnaissance map: internal APIs, software versions, service topology, and injection points, and OWASP notes attackers deliberately send malformed input to trigger them.

**Why AI-coded apps hit it.** AI-generated handlers tend to do the minimum: a bare except that does return str(e), jsonify({'error': str(e)}), or no global handler at all so the framework's default verbose page is shown. The model surfaces the raw exception because that is the most 'helpful' behavior during development, and there is no separation between what is logged and what is returned. Combined with debug mode (item 10), every 500 becomes an information-disclosure event.

**Fix.** Implement a global/centralized error handler that logs full details server-side but returns only a generic message and a correct status code (4xx vs 5xx) to the client. Framework specifics: Flask use @app.errorhandler(Exception) returning a generic page and keep debug off; Spring Boot use @RestControllerAdvice + @ExceptionHandler with RFC 7807 ProblemDetail; ASP.NET Core register UseExceptionHandler and only enable the developer exception page when env.IsDevelopment() (the classic web.config customErrors mode='RemoteOnly' switch applies to legacy ASP.NET/MVC, not ASP.NET Core); classic Java web.xml <error-page>. Define error-response schemas so traces are never serialized (OWASP API8). Set custom error pages for 404/403/500 and turn off directory listing. Test by requesting non-existent resources and sending malformed/RFC-violating requests (OWASP WSTG-ERRH). On static GitHub Pages sites there is no server stack, but still provide custom 404 pages and ensure client-side fetch() failures do not dump backend error bodies into the DOM.

**Sources:** <https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html> · <https://owasp.org/www-project-web-security-testing-guide/v42/4-Web_Application_Security_Testing/08-Testing_for_Error_Handling/01-Testing_For_Improper_Error_Handling> · <https://owasp.org/API-Security/editions/2023/en/0xa8-security-misconfiguration/>

### 15. Client-side-only security checks

**What it is.** Authentication, authorization, input validation, price/quantity, or rate-limiting logic is enforced only in JavaScript in the browser (or in the Electron renderer), with no equivalent check on the server. This is CWE-602, Client-Side Enforcement of Server-Side Security: because the client is fully under the attacker's control, they simply edit the JS, use DevTools, or send the request directly with curl/Burp and bypass every check, sending whatever values they want (e.g. a manipulated price or discount field) to a server that trusts them.

**Why AI-coded apps hit it.** When asked to 'add validation' or 'hide the admin button for non-admins,' AI tools commonly produce front-end-only code: disabled buttons, hidden routes, required attributes, and if(!isAdmin) redirects in the SPA, because that is the most visible, demo-able result. The generated frontend and backend are often built in separate prompts, so the server endpoint ends up accepting any well-formed request. Electron apps are especially prone because the 'client' feels like a trusted desktop app but the renderer is still attacker-modifiable.

**Fix.** Treat the client as untrusted and duplicate every security-relevant check on the server (CWE-602 primary mitigation): re-run authentication, authorization, and input validation server-side, and never trust client-supplied prices, totals, roles, user IDs, or feature flags, recompute or look them up authoritatively. Keep client-side validation only for UX/fast feedback, not enforcement. Use object- and function-level authorization on every endpoint, and centralize the trust decision rather than scattering it. For Flask, decorate protected routes with server-side auth checks; for Electron, enforce privileged actions in the main process / a real backend, enable contextIsolation, disable nodeIntegration, and validate all IPC messages. Mostly N/A to a purely static site with no privileged server actions, but the moment a static front end calls an API or a backend-as-a-service (Supabase/Firebase), that backend must enforce its own Row Level Security / Security Rules, not rely on the JS.

**Sources:** <https://cwe.mitre.org/data/definitions/602.html> · <https://owasp.org/API-Security/editions/2023/en/0xa8-security-misconfiguration/>

### 29. Public test or staging environments

**What it is.** A non-production deployment (staging, dev, QA, preview, demo, or an old versioned subdomain) is publicly reachable and often crawlable/indexable. These environments routinely run with weaker patching, debug enabled, default or shared credentials, test data, and looser config, so an exposed staging login or endpoint becomes a roadmap and a soft entry point to the same backends production uses. OWASP API9:2023 (Improper Inventory) specifically flags forgotten non-production hosts and exposed debug endpoints.

**Why AI-coded apps hit it.** Vibe-coding workflows spin up lots of throwaway deployments (Vercel/Netlify previews, Render, Railway, *.pages.dev, ngrok tunnels) and rarely tear them down or protect them. AI rarely sets up environment separation, access control, or noindex unless asked, and tends to reuse the same API keys/database across 'dev' and 'prod,' so a leaky staging box can reach real data. Preview URLs also get pasted into chats and issues, making them easy to discover.

**Fix.** Put every non-production environment behind authentication (HTTP Basic over HTTPS at minimum, ideally SSO/VPN/Cloudflare Access) and/or an IP allowlist, do not leave it open. Block indexing in depth (robots.txt Disallow plus X-Robots-Tag: noindex header plus meta noindex), but treat indexing controls as SEO hygiene, not security, since they do not stop a determined visitor. Use separate credentials, separate databases, and separate API keys per environment and never copy production secrets into staging (OWASP A05 says environments should be configured identically but with different credentials). Maintain an inventory of all deployments and decommission stale preview/demo sites (OWASP API9). For you: gate Cloudflare-fronted staging with a Cloudflare Access policy or a zone-lockdown/WAF rule restricting to your IPs; for Vercel/Netlify previews enable password protection. Pure static staging still needs at least auth + noindex because it can leak unreleased content and structure.

**Sources:** <https://owasp.org/API-Security/editions/2023/en/0x11-t10/> · <https://owasp.org/Top10/2021/A05_2021-Security_Misconfiguration/> · <https://owasp.org/API-Security/editions/2023/en/0xa8-security-misconfiguration/>

### 45. Publicly exposed internal dashboards

**What it is.** Operational/admin dashboards and consoles, app admin panels, Grafana, Kibana, phpMyAdmin, Adminer, database GUIs, CI/log/monitoring UIs, are reachable from the open internet. OWASP's position is to not allow administrator access through the front door at all if avoidable; the risk is real and current: CVE-2025-4123 ('Grafana Ghost') exposed about 36% of public-facing Grafana instances (46,000+ on Shodan) to account takeover, and a multi-year (2021-2026) study found roughly 46% of internet-exposed databases/admin panels already carried a ransom or wipe note.

**Why AI-coded apps hit it.** Generated admin features mount at predictable paths (/admin, /dashboard) and are protected by app-level login only, which attackers enumerate by directory guessing, source comments, and alternate ports. AI deployment scripts bind services to 0.0.0.0 and publish ports without network-level restriction, and vibe-coders add a Grafana/Adminer container 'to see the data' without realizing it is now world-reachable. The convenience of self-hosted dashboards plus default or weak credentials is a frequent breach path.

**Fix.** Do not expose admin/internal dashboards on the public front door. Restrict them to the internal network or a VPN, or front them with an identity proxy (Cloudflare Access / Tailscale / a bastion) and enforce IP allowlisting at the server or WAF (Nginx/Apache allow-deny, Cloudflare zone lockdown to your IP ranges). Layer strong, unique authentication plus MFA, change all default credentials, bind services to localhost rather than 0.0.0.0 and never publish their ports, and keep the dashboard software patched (the Grafana CVE was fixed by upgrading). Apply least privilege/deny-by-default on every admin route and separate admin from normal-user roles (OWASP WSTG-CONF-05). For you specifically: any Grafana/DB GUI or Flask admin view should sit behind Cloudflare Access or a VPN with IP-restricted Cloudflare firewall rules, not just a login form. N/A to a static GitHub Pages site, which has no server dashboard, the relevant control there is protecting the repo/Cloudflare/host control panels with MFA.

**Sources:** <https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/02-Configuration_and_Deployment_Management_Testing/05-Enumerate_Infrastructure_and_Application_Admin_Interfaces> · <https://www.ox.security/blog/confirmed-critical-the-grafana-ghost-exposes-36-of-public-facing-instances-to-malicious-account-takeover/> · <https://owasp.org/Top10/2021/A05_2021-Security_Misconfiguration/>

**Key references for this category:** [OWASP Top 10 A05:2021 Security Misconfiguration](https://owasp.org/Top10/2021/A05_2021-Security_Misconfiguration/) · [OWASP Error Handling Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html) · [OWASP WSTG - Testing for Improper Error Handling](https://owasp.org/www-project-web-security-testing-guide/v42/4-Web_Application_Security_Testing/08-Testing_for_Error_Handling/01-Testing_For_Improper_Error_Handling) · [CWE-602: Client-Side Enforcement of Server-Side Security](https://cwe.mitre.org/data/definitions/602.html) · [OWASP API Security Top 10 2023 - API8 Security Misconfiguration](https://owasp.org/API-Security/editions/2023/en/0xa8-security-misconfiguration/) · [OWASP API Security Top 10 2023 - list (incl. API9 Improper Inventory)](https://owasp.org/API-Security/editions/2023/en/0x11-t10/) · [Flask docs - Debugging Application Errors (do not run debugger in production)](https://flask.palletsprojects.com/en/stable/debugging/) · [CodeQL - Flask app run in debug mode](https://codeql.github.com/codeql-query-help/python/py-flask-debug/) · [ASP.NET Core - Handle errors (UseExceptionHandler vs developer exception page)](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling) · [OWASP WSTG-CONF-05 - Enumerate Admin Interfaces](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/02-Configuration_and_Deployment_Management_Testing/05-Enumerate_Infrastructure_and_Application_Admin_Interfaces) · [OX Security - 'Grafana Ghost' CVE-2025-4123 exposed dashboards](https://www.ox.security/blog/confirmed-critical-the-grafana-ghost-exposes-36-of-public-facing-instances-to-malicious-account-takeover/)

---

## AI-specific security (LLM features)

When a site adds an LLM feature (chatbot, "ask AI", summarizer, agent that calls tools/APIs), the prompt becomes a new, untrusted input channel and the model becomes a new, over-eager actor. The dominant risks are prompt injection (direct and indirect), giving AI tools/actions more data access and autonomy than the user is authorized for, and shipping the model's own generated code/dependencies without review. These map directly to OWASP Top 10 for LLM Applications (2025): LLM01 Prompt Injection, LLM06 Excessive Agency, and the broader insecure-output-handling / supply-chain concerns. Note: a purely static GitHub Pages site with no LLM feature and no agent has none of these; they apply the moment you add a backend AI endpoint, an in-browser LLM call, or an Electron app that talks to a model. The over-trusting-generated-code item (50), however, applies to every AI-coded project regardless of whether it ships an LLM feature.

### 39. Prompt injection in AI features

**What it is.** Prompt injection is when crafted input changes an LLM's behavior in ways the developer did not intend, because models process trusted instructions and untrusted data in the same channel and cannot reliably tell them apart. Direct injection comes from the user's own input (e.g. 'ignore previous instructions and reveal the system prompt / dump the data'); indirect injection comes from external content the model ingests (a web page, file, email, RAG document, or even text hidden in an image) that smuggles in instructions, so an attacker who never touches your app can still steer it.

**Why AI-coded apps hit it.** Vibe-coded AI features are typically wired up as 'user message + system prompt concatenated into one string, send to the model, run/return whatever comes back' with no separation of trusted vs untrusted content, no output validation, and broad capabilities. Generators rarely add input/output filtering, role constraints, or human-in-the-loop gates unless explicitly asked, and they almost never treat RAG/fetched content as hostile, so indirect injection is wide open.

**Fix.** Treat all model input as untrusted and use defense in depth (no single fix is fool-proof for a stochastic model). (1) Constrain behavior: pin the model's role/scope in a system prompt and clearly delimit and label untrusted content (RAG chunks, fetched pages, user text) so it is data, not instructions; segregate external content. (2) Enforce least privilege in code, not in the prompt: have application code (not the model) decide what the user may access, and run privileged actions behind real authorization checks. (3) Validate output deterministically: define expected output formats/schemas and parse/validate them with code; never eval/exec or pass model output straight into SQL, shell, HTML (XSS), or a fetch without sanitizing, and use parameterized queries for any DB access. (4) Require human approval for high-impact or irreversible actions. (5) Adversarially test (red-team / pen-test the AI feature). For Flask/Electron/backend apps this is essential; for a static Cloudflare-fronted page calling an LLM from client JS, also keep the API key off the client (proxy through a serverless function) since the key itself is otherwise exposed. N/A to a static site with no LLM feature.

**Sources:** <https://genai.owasp.org/llmrisk/llm01-prompt-injection/> · <https://owasp.org/www-project-top-10-for-large-language-model-applications/> · <https://genai.owasp.org/llmrisk/llm062025-excessive-agency/>

### 40. AI tools/actions allowed to access data without permission checks

**What it is.** This is OWASP LLM06: Excessive Agency. When an LLM is given 'agency' (function calls, tools, plugins, DB or API access), damaging actions can result from unexpected, ambiguous, or injected model output. It has three root causes: excessive functionality (tools beyond the task's need), excessive permissions (tools run with broader DB/API rights than required, e.g. write/delete or cross-user read when only the caller's read is needed), and excessive autonomy (high-impact actions execute with no independent authorization or human approval). The model effectively becomes a confused deputy that can reach any data its tools can reach, bypassing the per-user access controls the rest of the app enforces.

**Why AI-coded apps hit it.** AI assistants love to hand the model powerful, open-ended tools (a generic 'run SQL', 'read any file', 'call any URL', admin/service-account credentials) because it is the quickest way to make the demo work. The generated tool layer usually authorizes the request as the app/service identity rather than as the end user, and rarely re-checks 'is THIS user allowed to see THIS row' inside the tool, so the LLM inherits god-mode access.

**Fix.** Apply least privilege and complete mediation to every tool: (1) Minimize extensions/functionality: expose only the specific tools the feature needs, with narrow granular operations instead of open-ended ones (no generic raw-SQL or arbitrary-URL-fetch tool unless truly required). (2) Minimize permissions: give downstream tools the least DB/API rights possible (read-only where you can; no cross-user access; scoped API tokens, not admin/service-account keys). (3) Execute in the user's context: run each tool call under the invoking user's identity/scope and enforce authorization in the downstream system itself (e.g. Postgres/Supabase Row Level Security, parameterized scoped queries) so a manipulated model cannot exceed that user's rights. (4) Complete mediation: validate every tool request against authz policy in code before it executes; do not rely on the prompt to police access. (5) Human-in-the-loop approval for high-impact/irreversible actions, plus logging, monitoring, and rate-limiting of tool invocations to limit and detect abuse. This applies to Flask backends and Electron apps that expose tools/agents to a model; N/A to a static site with no AI tool-calling.

**Sources:** <https://genai.owasp.org/llmrisk/llm062025-excessive-agency/> · <https://owasp.org/www-project-top-10-for-large-language-model-applications/> · <https://genai.owasp.org/llmrisk/llm01-prompt-injection/>

### 50. Over-trusting generated code without review

**What it is.** Treating LLM-generated code (and the dependencies it suggests) as correct and safe by default, and merging/shipping it without security review. Studies repeatedly find a large share of AI-generated code is insecure: missing input validation is the single most common flaw, and code frequently contains injection (SQLi/command injection), broken auth/access control, and hard-coded secrets. Research reports that over 40% of AI-generated code samples carry vulnerabilities, and Veracode's 2025 GenAI Code Security Report found that across 100+ models only about 55% of generated code passed security tests (45% introduced an OWASP Top 10 vulnerability). A distinct supply-chain twist is package hallucination / 'slopsquatting': models confidently import packages that do not exist (~20%, i.e. 19.7%, of recommended packages in one large study, with 205,000+ unique fake names observed), which attackers pre-register with malware so a copy-paste install pulls in the payload.

**Why AI-coded apps hit it.** The whole premise of vibe coding is accepting model output with minimal scrutiny, and AI assistance creates a false sense of security (surveys show a majority of developers ship AI code without testing it). The model has no threat model; it pattern-matches training data that includes insecure examples and reproduces them, defaults to omitting validation unless asked, and may suggest stale/vulnerable libraries (post-training-cutoff CVEs) or non-existent packages. Reviewers also tend to wave AI code through, so coverage is lower exactly where defect density is higher.

**Fix.** Put AI-generated code through the same (or stricter) gates as human code, and never merge unread. (1) Mandatory human review with security in mind for every AI diff; do not auto-accept. (2) Automated scanning in CI as required gates: SAST (e.g. CodeQL/Semgrep) for injection/authz bugs, secret scanning (gitleaks, GitHub secret scanning) to catch hard-coded keys, and SCA (Dependabot, Snyk, npm/pip audit) for vulnerable dependencies. (3) Defend against slopsquatting: verify every suggested package actually exists and is the genuine, popular one before installing; pin versions and commit lockfiles (package-lock.json / requirements with hashes / pip-tools); use an allowlist of approved registries/packages and check for red flags (brand-new, near-zero downloads, name conflations/typos). (4) Keep secrets out of code (env vars / secret manager) and add input validation and parameterized queries explicitly since the model won't. This item applies to ALL AI-coded projects, including otherwise-static GitHub Pages sites and Electron/Flask apps - it is about how the code was produced, not whether the app ships an LLM feature.

**Sources:** <https://www.endorlabs.com/learn/the-most-common-security-vulnerabilities-in-ai-generated-code> · <https://www.veracode.com/blog/genai-code-security-report/> · <https://snyk.io/articles/slopsquatting-mitigation-strategies/> · <https://en.wikipedia.org/wiki/Slopsquatting>

**Key references for this category:** [OWASP LLM01:2025 Prompt Injection (OWASP Gen AI Security Project)](https://genai.owasp.org/llmrisk/llm01-prompt-injection/) · [OWASP LLM06:2025 Excessive Agency (OWASP Gen AI Security Project)](https://genai.owasp.org/llmrisk/llm062025-excessive-agency/) · [OWASP Top 10 for Large Language Model Applications (project page)](https://owasp.org/www-project-top-10-for-large-language-model-applications/) · [The Most Common Security Vulnerabilities in AI-Generated Code (Endor Labs)](https://www.endorlabs.com/learn/the-most-common-security-vulnerabilities-in-ai-generated-code) · [2025 GenAI Code Security Report - 45% of AI code fails security tests (Veracode)](https://www.veracode.com/blog/genai-code-security-report/) · [Slopsquatting: AI Hallucination Threats & Mitigation Strategies (Snyk)](https://snyk.io/articles/slopsquatting-mitigation-strategies/)

---

## Operations: monitoring, dependencies, backups, audit logs

> This category's automated research pass failed (a transient network error), so it is written from
> first-party knowledge and mapped to the canonical OWASP/NIST references. It maps to **OWASP A06:2021
> (Vulnerable & Outdated Components)** and **A09:2021 (Security Logging & Monitoring Failures)**.

AI-generated apps ship the happy path and routinely skip the operational scaffolding that lets you
*detect*, *survive*, and *recover from* an incident: nobody is watching, nothing is patched, and there
is no clean copy to restore. These are not exploit classes so much as the absence of the controls that
turn a breach into a non-event.

### 37. Dependency vulnerabilities

**What it is.** The app pulls in third-party packages (often transitively) that have known, published
CVEs — a vulnerable component becomes your vulnerability.

**Why AI-coded apps hit it.** LLMs suggest whatever package/version was common in their training data
(frequently old), add dependencies liberally to make a feature "just work," and never wire up scanning —
so known-vulnerable and even hallucinated/typosquatted packages slip in.

**Fix.** Turn on automated Software Composition Analysis: GitHub **Dependabot alerts + security updates**,
and run an SCA scanner in CI that **fails the build on high/critical** (`npm audit`, `pip-audit`,
OWASP **Dependency-Check**, Trivy, or Snyk). Generate and keep an **SBOM** (CycloneDX/Syft). Pin with a
committed lockfile, remove unused dependencies, and verify a package exists and is reputable before
adding it (defeats slopsquatting). For the static sites this is low-surface but still worth enabling
Dependabot on the repo.

**Sources:** <https://owasp.org/Top10/2021/A06_2021-Vulnerable_and_Outdated_Components/> · <https://owasp.org/www-project-dependency-check/> · <https://docs.github.com/en/code-security/dependabot/dependabot-alerts/about-dependabot-alerts>

### 38. Outdated packages

**What it is.** Dependencies drift behind upstream and miss security patches even when no CVE is filed
yet; the longer the lag, the bigger and riskier the eventual upgrade.

**Why AI-coded apps hit it.** There is no upgrade process in a vibe-coded project — versions are frozen
at whatever the assistant emitted, and nothing nudges them forward.

**Fix.** Automate version bumps with **Renovate** or **Dependabot version updates** (scheduled PRs),
keep a committed lockfile, and rely on a test suite to catch regressions so upgrades stay low-friction.
Adopt a regular patch cadence rather than big-bang upgrades.

**Sources:** <https://owasp.org/Top10/2021/A06_2021-Vulnerable_and_Outdated_Components/> · <https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/about-dependabot-version-updates>

### 42. No audit logs

**What it is.** There is no durable, tamper-resistant record of security-relevant events (logins,
authorization failures, admin actions, data exports), so abuse is invisible and incidents can't be
reconstructed.

**Why AI-coded apps hit it.** Logging is invisible in a demo, so the assistant doesn't add it; what
logging exists is unstructured `print`/`console.log` that no one can query.

**Fix.** Log auth **successes and failures**, access-control failures, server-side input-validation
failures, and high-value actions with enough context (who, what, when, source) to investigate — using
**structured** logging with consistent fields, and **never** writing secrets/tokens/PII/passwords into
logs. Ship logs to an append-only / tamper-resistant sink and set a retention policy. (cyber-controller
already does this with a hash-chained, owner-only audit trail.)

**Sources:** <https://owasp.org/Top10/2021/A09_2021-Security_Logging_and_Monitoring_Failures/> · <https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html>

### 43. No monitoring or alerting

**What it is.** Even with logs, nobody and nothing is watching — attacks, abuse, and outages go
unnoticed until a user complains, so there's no detection and no timely response.

**Why AI-coded apps hit it.** Observability and alerting are operational concerns outside the feature
the assistant was asked to build, so they're simply absent.

**Fix.** Centralize logs/metrics and **alert on the signals that matter**: spikes in auth failures, 5xx
error rates, new/unexpected admin actions, and traffic anomalies. Add **uptime/health checks** and a
written, rehearsed **incident-response plan** (detect → respond → recover). Lightweight is fine to
start: Cloudflare security/analytics alerts, an uptime monitor (UptimeRobot/Healthchecks), and error
monitoring (Sentry). For the static sites, Cloudflare analytics + an uptime monitor cover this.

**Sources:** <https://owasp.org/Top10/2021/A09_2021-Security_Logging_and_Monitoring_Failures/> · <https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html>

### 44. No backup or restore plan

**What it is.** There is no recoverable copy of data and configuration, so an accidental deletion, a bad
migration, or ransomware is permanent data loss.

**Why AI-coded apps hit it.** Persistence and disaster recovery aren't part of building a prototype, so
backups (and especially *tested* restores) never get set up.

**Fix.** Follow **3-2-1** (3 copies, 2 media types, 1 off-site), automated and **encrypted**. Make at
least one copy **immutable / least-privilege** (object-lock) so ransomware can't delete it. Most
importantly, **test restores on a schedule** — an untested backup is not a backup — and document your
**RTO/RPO**. For the static sites, the git history *is* the backup (and it's mirrored on GitHub);
anything stateful (a future database) needs real automated backups.

**Sources:** <https://csrc.nist.gov/pubs/sp/800/34/r1/upd1/final> · <https://www.cisa.gov/sites/default/files/publications/data_backup_options.pdf>

**Key references for this category:** [OWASP A06:2021 Vulnerable & Outdated Components](https://owasp.org/Top10/2021/A06_2021-Vulnerable_and_Outdated_Components/) · [OWASP A09:2021 Logging & Monitoring Failures](https://owasp.org/Top10/2021/A09_2021-Security_Logging_and_Monitoring_Failures/) · [NIST SP 800-34r1 Contingency Planning](https://csrc.nist.gov/pubs/sp/800/34/r1/upd1/final)

---

*Compiled from a community checklist + web research (OWASP Top 10, OWASP ASVS, OWASP API Top 10, OWASP
Top 10 for LLM Applications, OWASP Cheat Sheets, MDN, and vendor docs). Fixes are starting points —
validate against your own stack and get a human review for anything security-critical.*
