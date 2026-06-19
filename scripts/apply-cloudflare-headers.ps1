<#
.SYNOPSIS
  Adds/updates a Cloudflare "Modify Response Header" Transform Rule that injects HTTP security
  headers for a zone. Idempotent (replaces the http_response_headers_transform entrypoint ruleset).

.PREREQUISITES
  - The zone must be PROXIED (orange cloud) for these headers to take effect (see cloudflare-headers.md).
  - $env:CLOUDFLARE_API_TOKEN with: Zone:Read + Transform Rules:Edit on the zone.

.EXAMPLE
  $env:CLOUDFLARE_API_TOKEN = '<token>'
  ./apply-cloudflare-headers.ps1 -Domain example.com
#>
param(
  [Parameter(Mandatory = $true)][string]$Domain
)

$ErrorActionPreference = 'Stop'
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
$csp = "default-src 'none'; script-src 'self'; style-src 'self'; font-src 'self'; img-src 'self'; connect-src https://api.github.com; frame-ancestors 'none'; base-uri 'self'; form-action 'none'; upgrade-insecure-requests"
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
