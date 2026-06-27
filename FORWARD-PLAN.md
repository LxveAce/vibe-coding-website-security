# vibe-coding-website-security - Forward Plan

> Status: GREEN / healthy. PUBLIC, MIT, docs-only AI-security guardrail. Single clean commit `637327e` on `main`, in sync with `origin/main`. 21 tracked files, all internal links resolve. Only real defects are 3 small footguns/stale refs in the lone PowerShell script + no link-rot CI. Last reviewed: 2026-06-27. (Update this date line each session.)

## Where this stands

**What it is.** Not a buildable software project. It is an "assistant-readable" guardrail you point an AI coding agent at before/while it builds a website: a catalog of the common security flaws and missing engineering pieces in AI-generated ("vibe-coded") sites, each with a concrete fix + authoritative sources.

- **Entry points:** `AGENTS.md` (doubles as CLAUDE.md / Cursor rule; defines the rules and the "Security Report" the AI must emit) and `llms.txt` (machine-readable repo map).
- **Master checklist:** `CHECKLIST.md` (6 sections, tier-tagged, "tick or mark N/A, never skip").
- **Content layout:** `security/` (vulnerabilities, login-and-auth, checklist, ai-llm-security, advanced-web-security, http-security-headers), `engineering/beyond-code.md`, `production-readiness/`, `database-hosting/` (universal controls + per-provider guides incl. a Supabase free-tier deep dive).
- **Only executable artifact:** `scripts/apply-cloudflare-headers.ps1` — standalone PowerShell that PUTs a Cloudflare response-header Transform Rule via the API.

**How to "build/run."** It does not compile — you consume the Markdown. The lone script runs standalone: needs PowerShell + `$env:CLOUDFLARE_API_TOKEN` (Zone:Read + Transform Rules:Edit), invoked as `./apply-cloudflare-headers.ps1 -Domain example.com`. No external module deps. No package manifest, no test suite, no CI (`.github/` absent).

**Current state (verified this session).** Clean working tree; local `main` == `origin/main` at `637327e` (the earlier "unpushed work" worry from stale `pushedAt` metadata is RESOLVED — nothing unpushed). 0 broken relative links across all `.md`. Script passes PowerShell AST parse. 0 GitHub issues, 0 releases. No genuine TODO/FIXME markers (only prose describing the vuln of leaving auth as a TODO).

## P0 - do first

There is **no true P0** — docs-only repo, no build, no live site to break. Highest-value first action is the cheap script-cleanup batch (all in `scripts/apply-cloudflare-headers.ps1`):

1. **Fix the broken cross-reference** at line 7: comment says "see cloudflare-headers.md" but that file does not exist in this public repo (it's the private companion's name). Point it at `security/http-security-headers.md`.
2. **Add a visible destructive-action warning** (in the script header AND in `README.md` / `security/http-security-headers.md`): running the script REPLACES the entire `http_response_headers_transform` entrypoint ruleset — any pre-existing transform rules on the zone are wiped.

> Template note: the "cyber-controller .exe/installer P0" does NOT apply here — this repo ships no executable/installer, only one standalone `.ps1`. Recorded as considered-and-out-of-scope.

## Surface bugs found

| Title | Location | Severity | Note |
|---|---|---|---|
| Script comment references `cloudflare-headers.md` (does not exist in public repo) | `scripts/apply-cloudflare-headers.ps1:7` | P2 | Public name is `security/http-security-headers.md` (README.md:33). One-line fix. Verified via grep this session. |
| Script PUTs the entrypoint ruleset — REPLACES (not appends) existing Cloudflare transform rules | `scripts/apply-cloudflare-headers.ps1:56-58` | P2 | Caveat only in `.SYNOPSIS` comment; surface it in README + headers doc. Destructive for reusers with existing rules. |
| CSP hard-codes `connect-src https://api.github.com` while labeled "same set for all static sites" | `scripts/apply-cloudflare-headers.ps1:31` | P3 | Breaks fetch/XHR on sites not calling that origin. Parameterize or document. |
| No CI / automated Markdown link + anchor checking | `.github/` (absent) | P3 | 0 broken links today, but cross-references are the whole value; a rename would break navigation silently. |
| `apply-cloudflare-headers.ps1` drifted between public & private repos (2839 vs 2785 bytes) | `scripts/apply-cloudflare-headers.ps1` vs `LxveAce/website-playbook` | P3 | Same filename, different content. Pick a single source of truth. |

## Features to add

**User directives:** none were supplied for this run (the USER DIRECTIVES section was empty). No features were invented. If the user later supplies directives, insert them here **verbatim** as planned work items before anything below.

Optional, evidence-backed enhancements:
- Lightweight CI (`.github/workflows`) running a Markdown link checker (lychee / markdown-link-check) on push/PR.
- Extend that check to validate intra-doc `#anchor` links (recon only checked file existence).
- Parameterize `apply-cloudflare-headers.ps1` (`-ConnectSrc` / `-Csp`) so it is genuinely reusable across sites.
- Only if ever shipping pinned artifacts: cut a tagged GitHub release (currently 0; llms.txt/AGENTS.md rely on always-latest raw URLs).
- Set About `homepageUrl` only if a rendered docs site is ever published (none today).

## Red-team / hardening

- **Most impactful:** prominent non-comment warning that the script REPLACES the response-header transform entrypoint ruleset — reusers must review existing rules first.
- Reinforce minimal token scope (Zone:Read + Transform Rules:Edit, single zone), rotation, and "never commit the token" (it's read from `$env:CLOUDFLARE_API_TOKEN` — keep it that way, never add a default).
- Document why `connect-src` is GitHub-only so consumers don't blind-copy a CSP that breaks their origins.
- PUBLIC-repo discipline (standing rule): keep all vuln/OWASP-LLM/auth content as defensive hardening with fixes + sources; NO exploit recipes; NO maintainer PII (only the LxveAce alias in LICENSE is allowed public).
- Consider branch protection on `main` (not confirmed set) so future edits pass PR + the proposed link-check CI.
- Execute the script once against a throwaway zone to verify request-body shape before recommending widely (recon only static-parsed it).

## Dig deeper (next dedicated session)

1. Run the script end-to-end against a disposable Cloudflare zone (with a dummy pre-existing transform rule) to empirically confirm replace-vs-append and the exact ruleset-entrypoint semantics.
2. Line-by-line diff the script vs `LxveAce/website-playbook`'s copy (2839 vs 2785 bytes); classify drift (whitespace vs logic); choose canonical.
3. Anchor-level link check across all `.md` bodies (not just file existence).
4. Content fact-check pass: re-fetch external source URLs; verify cited breach counts / CVE refs and the "50 vulns" / "~237 checklist items" counts against the actual files (those came from SESSION.md/memory, not a re-count).
5. Audit the private companion's cross-links (older filenames, missing docs) so a future public rename doesn't silently break the private README — read-only, no private-repo edits.
6. Inspect git history depth (only `637327e` visible) to confirm no squashed/reset history retained sensitive content in earlier objects pre-public.
7. Query per-repo settings: branch protection, Pages, secret scanning/push protection (org-wide baseline confirmed; per-repo for THIS repo not).

## Dependencies & cross-repo context

- **PRIVATE companion:** `LxveAce/website-playbook` — personal mapping (`security/my-stack-status.md`) + open to-do list (`MANUAL-ACTIONS.md`). Leaner/older subset with divergent filenames (`ai-coded-vulnerabilities.md`, `cloudflare-headers.md`). Public repo is canonical. Do NOT plan private-repo edits from this plan.
- **Shared artifact (drifted):** `scripts/apply-cloudflare-headers.ps1` in both repos.
- **Continuity (read-only):** `C:/Users/mmrla/repos/session-context/SESSION.md` + private `MANUAL-ACTIONS.md`. NOT related: `C:/Users/mmrla/Projects/CLAUDE-TRANSFER.md` (cyberdeck).
- **Script runtime deps:** PowerShell + `$env:CLOUDFLARE_API_TOKEN`; no external modules; Cloudflare API v4.
- **Standing commit rules (OVERRIDE defaults):** commit as **LxveAce**, **NO** `Co-Authored-By: Claude` trailer; no real name/email/phone on public repos.
- **Informing-context only (NOT flagship-repo work):** live static sites still lack enforced HSTS/frame-ancestors/nosniff/Permissions-Policy (Cloudflare grey-cloud/DNS-only); blocked on a Cloudflare token + flipping records to proxied — which is exactly what this repo's script solves once a token exists.

## Open questions

- Was `connect-src https://api.github.com` intentional (maintainer sites render GitHub releases) or a leftover to generalize?
- Are the private companion's older filenames intentional legacy or out-of-sync? (Undocumented; inferred.)
- Does the maintainer ever intend GitHub releases or a hosted docs site? (Absence may be by design.)
- Is branch protection / per-repo secret scanning / Pages configured on THIS repo? (Org-wide baseline only confirmed.)
- Does the script's Cloudflare call succeed end-to-end live? (Only static-parsed.)
- Exact nature of the script drift between repos? (Only byte sizes compared.)
