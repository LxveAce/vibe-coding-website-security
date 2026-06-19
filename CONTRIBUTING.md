# Contributing

This is a living guardrail for AI-generated websites. Pull requests welcome — the goal is a resource an
AI can read and act on directly.

## What to add
- A new vulnerability or "missing piece" that's common in AI-generated / vibe-coded sites.
- A clearer or more correct **fix** for an existing item.
- A more authoritative **source**, or a replacement for a dead link.
- A new engineering concept worth knowing as projects grow into a backend.

## Rules for entries
- **Cite authoritative sources** — OWASP (Top 10, API Top 10, Top 10 for LLM Apps, ASVS, Cheat Sheets),
  MDN, CWE, NIST, or official vendor docs. Verify every link resolves.
- **Accurate, current, concrete.** Name the specific control, header, config, or pattern. Don't invent
  features or numbers. Prefer correcting a stale claim over adding an unsourced one.
- **Keep it generic.** No PII and nothing tied to one person's infrastructure (no real domains, paths,
  or accounts) — entries must be usable by anyone.
- **Match the format.** Vulnerabilities: *what it is / why AI-coded apps hit it / fix / sources.*
  Engineering: *what it is / why it matters / when to use it / when it's overkill / sources.*
- **Write for an assistant.** Short, imperative, actionable — an AI should be able to follow it without
  guessing.

## How
1. Fork and branch.
2. Make a focused change.
3. Open a PR with a one-paragraph rationale and your source(s).
