# HTTP security headers (for static / GitHub Pages sites behind Cloudflare)

Static hosts like **GitHub Pages cannot set custom HTTP response headers.** A site can ship a strong
`Content-Security-Policy` in a `<meta http-equiv>` tag, which covers most CSP directives — **but several
important controls are silently ignored when delivered via `<meta>`:**

| Control | Works in `<meta>`? | If missing |
|---|---|---|
| `Content-Security-Policy` (most directives) | ✅ yes | enforced |
| **`frame-ancestors`** (anti-clickjacking) | ❌ **ignored in meta** | the site can be framed → clickjacking |
| **`Permissions-Policy`** | ❌ **ignored in meta** | the meta tag is a no-op |
| `Strict-Transport-Security` (HSTS) | ❌ header-only | first-visit HTTPS-downgrade risk |
| `X-Content-Type-Options: nosniff` | ❌ header-only | MIME-sniffing not blocked |

So real HTTP headers are a **genuine security gain**, not cosmetic — a site can have a perfect-looking
meta CSP and still be frame-able and MIME-sniffable. For a static host, the place to add them is the CDN
in front: **Cloudflare**.

---

## Prerequisite: the hostname must be PROXIED (orange cloud)

Cloudflare can only add/modify response headers on **proxied (orange-cloud)** traffic. GitHub Pages custom
domains are often left **DNS-only (grey cloud)**, in which case traffic goes straight to GitHub and
Cloudflare can't touch the response. To enable header injection:

1. **SSL/TLS → Overview → set the mode to `Full (strict)`.** GitHub Pages serves a valid Let's Encrypt
   cert for the custom domain, so `Full (strict)` works and avoids redirect loops. *Never use `Flexible`
   with Pages.*
2. **DNS → switch the GitHub Pages `A`/`AAAA` records (and the `www` `CNAME`) to Proxied (orange).**
   - Pages `A` records: `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - `AAAA`: `2606:50c0:8000::153` … `8003::153`
3. In the repo's **Settings → Pages**, keep **"Enforce HTTPS" enabled.** (If GitHub's cert shows
   "unavailable" after proxying, toggle the custom domain off/on in Pages settings to re-provision — a
   known GitHub + Cloudflare ordering quirk.)
4. Add the **Transform Rule** / run the script below.

---

## Recommended response headers

| Header | Value | Why |
|---|---|---|
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains; preload` | force HTTPS for 2y; preload-eligible |
| `X-Frame-Options` | `DENY` | clickjacking protection the meta `frame-ancestors` can't enforce |
| `X-Content-Type-Options` | `nosniff` | stop MIME-type sniffing |
| `Referrer-Policy` | `no-referrer` | a static marketing site rarely needs to leak referrers |
| `Permissions-Policy` | `accelerometer=(), autoplay=(), camera=(), display-capture=(), encrypted-media=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), midi=(), payment=(), usb=(), interest-cohort=()` | deny powerful features site-wide (real header; meta is ignored) |
| `Cross-Origin-Opener-Policy` | `same-origin` | isolate the browsing context |
| `Content-Security-Policy` | see below | also deliver as a real header so `frame-ancestors` is enforced |

**A solid baseline CSP for a static site that fetches a public JSON API** (e.g. live GitHub release data):

```
default-src 'none'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self'; connect-src https://api.github.com; frame-ancestors 'none'; base-uri 'self'; form-action 'none'; upgrade-insecure-requests
```

Tighten `connect-src`/`img-src`/`script-src` to exactly what the site uses; if it makes no `fetch`/XHR
calls, use `connect-src 'none'`. When both a `<meta>` CSP and a header CSP are present, the browser
enforces the **intersection** (most restrictive per directive), so keeping both is safe defense-in-depth —
the header is what makes `frame-ancestors` real.

---

## Apply via the Cloudflare dashboard (no code)

Per zone: **Rules → Transform Rules → Modify Response Header → Create rule**
- Match: **All incoming requests** (or `hostname` = apex + `www`).
- **Set static** — one entry per header from the table.
- Deploy.

HSTS can also be turned on at **SSL/TLS → Edge Certificates → HSTS** once HTTPS is stable.

## Apply via the Cloudflare API (script)

[`scripts/apply-cloudflare-headers.ps1`](../scripts/apply-cloudflare-headers.ps1) creates the
response-header Transform Rule for a zone. Needs a token with **Zone:Read + Transform Rules:Edit**.

```powershell
$env:CLOUDFLARE_API_TOKEN = '<token>'   # set in the env; never hardcode
./scripts/apply-cloudflare-headers.ps1 -Domain example.com
```

## Verify

```bash
curl -sI https://example.com | grep -iE 'strict-transport|x-frame|x-content-type|referrer|permissions-policy|content-security|cross-origin'
```

Or scan at <https://securityheaders.com> (target **A/A+**) and submit to <https://hstspreload.org> once the
HSTS header is live with `preload; includeSubDomains`.

> **Dynamic app instead of a static host?** Set these headers in your application/response middleware
> (Flask `after_request`, Express `helmet`, etc.) rather than at the CDN.
