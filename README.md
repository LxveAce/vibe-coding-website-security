# vibe-coding-website-security

**Point your AI at this repo before you vibe-code a website or app.**

AI coding assistants are great at the happy path — and notorious for shipping the same security holes and
missing pieces every time: secrets in the client, insecure logins, no real authorization, IDOR, injection,
missing security headers, world-readable databases, prompt injection — and skipping the whole
production-readiness layer (testing, reliability, recovery). This repo is a compact, **assistant-readable**
guardrail: the common flaws *and* the engineering pieces AI forgets, each with a concrete fix and
authoritative sources.

<!-- STATUS-ROADMAP:START -->
## Status & Roadmap
**Status:** Healthy and stable — a docs-only AI-security guardrail (MIT); content is current, all internal links resolve, and there is no build to break.

**In progress / known issues:**
- `scripts/apply-cloudflare-headers.ps1` **replaces** the zone's response-header transform-rule entrypoint rather than appending — review existing Cloudflare rules before running. A clearer warning is being added to the script and docs.
- Fixing a stale cross-reference in the script comment (point it at [`security/http-security-headers.md`](security/http-security-headers.md)).
- The script's `connect-src` CSP is currently GitHub-specific; documenting/parameterizing it so it is reusable across sites.

**Roadmap:**
- Lightweight CI (GitHub Actions) running a Markdown link checker on push/PR.
- Extend link checking to validate intra-doc `#anchor` references, not just file existence.
- Parameterize `apply-cloudflare-headers.ps1` (`-ConnectSrc` / `-Csp`) for genuine cross-site reuse.
- Cut a tagged GitHub release only if/when pinned artifacts are ever shipped.
- Publish a rendered docs site (and set the repo homepage) only if one is ever built.
<!-- STATUS-ROADMAP:END -->

## Who it's for
- **AIs / coding agents** — read [`AGENTS.md`](AGENTS.md), follow the rules, and run the checklist before "done."
- **Humans using AI** — hand your assistant this repo so it stops shipping the usual holes.

## Use it in 30 seconds
1. **Point your AI at it** — paste this repo's URL into your tool's context, **or** drop
   [`AGENTS.md`](AGENTS.md) into your project (it doubles as `CLAUDE.md` or a Cursor rule), **or** feed
   [`llms.txt`](llms.txt) to your model.
2. Ask it to **build / refactor following `AGENTS.md`.**
3. Before shipping, have it run [`security/checklist.md`](security/checklist.md) and report what it fixed.

## What's inside
| File | What |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Rules an AI must follow + how to use this repo — **the entry point** |
| [`CHECKLIST.md`](CHECKLIST.md) | **Master pre-ship checklist** — *every* item (security + login + production-readiness + architecture), tier-tagged; tick or mark N/A so nothing is skipped |
| [`security/vulnerabilities.md`](security/vulnerabilities.md) | **The 50** common AI-coded vulnerabilities — what / why / fix / sources |
| [`security/login-and-auth.md`](security/login-and-auth.md) | The **5 login/auth mistakes** AI ships (tokens in localStorage, client-side authz, weak MFA, no rate limit, breached passwords) |
| [`security/checklist.md`](security/checklist.md) | Pre-ship checkbox checklist + per-deploy ship gate |
| [`security/ai-llm-security.md`](security/ai-llm-security.md) | **AI/LLM security** (if your app has an LLM/RAG/agent) — OWASP **LLM Top 10** + agent/MCP/slopsquatting |
| [`security/advanced-web-security.md`](security/advanced-web-security.md) | **Advanced & general web security** — TLS/DNS, CSP3/Trusted Types/SRI, OAuth/OIDC, **API Top 10**, email/SPF/DMARC, supply chain (SLSA/SBOM), governance |
| [`security/http-security-headers.md`](security/http-security-headers.md) | Real HTTP headers for static hosts (Cloudflare) + a script |
| [`engineering/beyond-code.md`](engineering/beyond-code.md) | "Engineering is more than just code" — the backend / system-design pieces AI omits |
| [`production-readiness/`](production-readiness/) | **Production-readiness** — testing, reliability, data/compliance, ops, governance & a11y, each tiered (🟢 every app → 🔴 regulated) |
| [`database-hosting/`](database-hosting/) | **Backend database security** — universal controls + per-provider guides; **Supabase free-tier** deep dive (RLS, keys, auth, storage, backups) |
| [`llms.txt`](llms.txt) | Machine-readable map of the repo for LLMs |

## Core principles (the TL;DR)
- AI optimizes for *"it works,"* not *"it's safe."* Assume generated code is permissive by default.
- **Never trust the client** — re-enforce every check (auth, authorization, validation, price, role) on the server.
- **Secrets never reach the browser or git.** A public key needs a real authorization boundary behind it (RLS / Security Rules).
- **Treat LLM output as untrusted; give AI tools least privilege.**
- A **human reviews** anything touching auth, payments, or other users' data.

## Sources
Every fix is grounded in OWASP (Top 10, API Security Top 10, Top 10 for LLM Apps, ASVS, Cheat Sheets), MDN,
CWE, NIST, and official vendor docs — each item links its own sources. Found a gap or a better fix?
See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License
[MIT](LICENSE) — use it, fork it, point your robots at it.
