<#
.SYNOPSIS
  Adds/updates a Cloudflare "Modify Response Header" Transform Rule that injects HTTP security
  headers for a zone. Idempotent (replaces the http_response_headers_transform entrypoint ruleset).

.DESCRIPTION
  DESTRUCTIVE: This script issues a PUT to the http_response_headers_transform ENTRYPOINT ruleset,
  which REPLACES that ruleset wholesale. Any pre-existing response-header Transform Rules on the zone
  (e.g. ones added via the dashboard or other automation) are WIPED and replaced by the single rule
  defined here. Review the zone's existing rules before running.

.PREREQUISITES
  - The zone must be PROXIED (orange cloud) for these headers to take effect
    (see security/http-security-headers.md).
  - $env:CLOUDFLARE_API_TOKEN with: Zone:Read + Transform Rules:Edit on the zone.

.PARAMETER ConnectSrc
  The CSP `connect-src` value. The default (`https://api.github.com`) is EXAMPLE-SPECIFIC — it suits a
  static site that fetches the GitHub API. Adjust per site: pass the exact origins the site calls, or
  'none' if it makes no fetch/XHR calls.

.EXAMPLE
  $env:CLOUDFLARE_API_TOKEN = '<token>'
  ./apply-cloudflare-headers.ps1 -Domain example.com

.EXAMPLE
  ./apply-cloudflare-headers.ps1 -Domain example.com -ConnectSrc 'none'
#>
param(
  [Parameter(Mandatory = $true)][string]$Domain,
  # EXAMPLE-SPECIFIC default: tighten this to exactly the origins your site fetches (or 'none').
  [string]$ConnectSrc = 'https://api.github.com'
)

$ErrorActionPreference = 'Stop'

# --- DESTRUCTIVE-ACTION WARNING (shown before any API call) ---
Write-Warning 'DESTRUCTIVE: this REPLACES the entire http_response_headers_transform entrypoint ruleset.'
Write-Host  '  Any pre-existing response-header Transform Rules on this zone will be WIPED and replaced' -ForegroundColor Yellow
Write-Host  '  by the single rule defined in this script. Review the zone''s existing rules first.' -ForegroundColor Yellow

$token = $env:CLOUDFLARE_API_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) { throw 'Set $env:CLOUDFLARE_API_TOKEN first.' }
$headers = @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' }
$api = 'https://api.cloudflare.com/client/v4'

# 1) resolve zone id
$zone = Invoke-RestMethod -Uri "$api/zones?name=$Domain" -Headers $headers -Method GET
if (-not $zone.success -or $zone.result.Count -eq 0) { throw "Zone not found for $Domain (token scope?)." }
$zoneId = $zone.result[0].id
Write-Host "Zone $Domain -> $zoneId"

# 2) the security headers to set (same set for all static sites)
# NOTE: the `connect-src $ConnectSrc` below is EXAMPLE-SPECIFIC. The default (https://api.github.com)
#       suits a site that fetches the GitHub API; pass -ConnectSrc to match the origins YOUR site calls
#       (or -ConnectSrc 'none' if it makes no fetch/XHR requests).
$csp = "default-src 'none'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self'; connect-src $ConnectSrc; frame-ancestors 'none'; base-uri 'self'; form-action 'none'; upgrade-insecure-requests"
$permissions = "accelerometer=(), autoplay=(), camera=(), display-capture=(), encrypted-media=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), midi=(), payment=(), usb=(), interest-cohort=()"

$set = [ordered]@{
  'Strict-Transport-Security' = 'max-age=63072000; includeSubDomains; preload'
  'X-Frame-Options'           = 'DENY'
  'X-Content-Type-Options'    = 'nosniff'
  'Referrer-Policy'           = 'no-referrer'
  'Permissions-Policy'        = $permissions
  'Cross-Origin-Opener-Policy'= 'same-origin'
  'Content-Security-Policy'   = $csp
}
$hdrObj = [ordered]@{}
foreach ($k in $set.Keys) { $hdrObj[$k] = @{ operation = 'set'; value = $set[$k] } }

$body = @{
  rules = @(@{
    action = 'rewrite'
    action_parameters = @{ headers = $hdrObj }
    expression  = 'true'
    description = 'security-headers (managed by website-playbook)'
    enabled     = $true
  })
} | ConvertTo-Json -Depth 8

# 3) replace the response-header transform entrypoint ruleset
$uri = "$api/zones/$zoneId/rulesets/phases/http_response_headers_transform/entrypoint"
$res = Invoke-RestMethod -Uri $uri -Headers $headers -Method PUT -Body $body
if ($res.success) { Write-Host "OK: security headers applied to $Domain" -ForegroundColor Green }
else { $res.errors | ConvertTo-Json -Depth 6; throw "Cloudflare API returned errors for $Domain" }
