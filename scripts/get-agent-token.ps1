#Requires -Version 7.0
<#
.SYNOPSIS
    Generates a short-lived GitHub App installation token for settlespace-agent.

.DESCRIPTION
    Signs a JWT with the app private key, exchanges it for an installation access token
    scoped to the target repository, and writes the raw token to stdout.

    Requires PowerShell 7+ (.NET 5+). Run with pwsh, not powershell.

    Typical usage:
        $env:GH_TOKEN = (pwsh ./scripts/get-agent-token.ps1).Trim()
        gh pr create --title "..." --body "..."

.PARAMETER PemPath
    Path to the RSA private key .pem file.
    Defaults to the first *.pem found in the repository root.

.PARAMETER Repo
    Target repository in owner/name format. Defaults to salakist/settlespace.
#>
[CmdletBinding()]
param(
    [string]$PemPath,
    [string]$Repo = 'salakist/settlespace'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

# --- Resolve private key --------------------------------------------------

if (-not $PemPath) {
    $found = Get-ChildItem -Path $repoRoot -Filter '*.pem' -File | Select-Object -First 1
    if (-not $found) {
        Write-Error 'No .pem file found in repo root. Provide -PemPath or place the private key there.'
        exit 1
    }
    $PemPath = $found.FullName
}

if (-not (Test-Path $PemPath)) {
    Write-Error "PEM file not found: $PemPath"
    exit 1
}

# --- Read App ID from .env ------------------------------------------------

$envFile = Join-Path $repoRoot '.env'
if (-not (Test-Path $envFile)) {
    Write-Error ".env not found at $envFile. Expected GITHUB_APP_ID=<id>"
    exit 1
}

$appId = Get-Content $envFile |
    Where-Object   { $_ -match '^GITHUB_APP_ID\s*=' } |
    ForEach-Object { ($_ -split '=', 2)[1].Trim()   } |
    Select-Object  -First 1

if (-not $appId) {
    Write-Error 'GITHUB_APP_ID not found in .env'
    exit 1
}

# --- Load RSA private key -------------------------------------------------

$pemContent = Get-Content $PemPath -Raw
$rsa = [System.Security.Cryptography.RSA]::Create()
$rsa.ImportFromPem($pemContent)

# --- Build JWT ------------------------------------------------------------
# iat is backdated 60 s to tolerate clock skew; exp is iat + 9 min (GitHub max is 10 min)

function ConvertTo-Base64Url ([byte[]]$bytes) {
    [Convert]::ToBase64String($bytes) -replace '=+$', '' -replace '\+', '-' -replace '/', '_'
}

$now     = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$header  = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes('{"alg":"RS256","typ":"JWT"}'))
$payload = ConvertTo-Base64Url ([System.Text.Encoding]::UTF8.GetBytes(
    "{`"iat`":$($now - 60),`"exp`":$($now + 540),`"iss`":`"$appId`"}"
))

$sigInput  = [System.Text.Encoding]::UTF8.GetBytes("$header.$payload")
$signature = ConvertTo-Base64Url ($rsa.SignData(
    $sigInput,
    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
    [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
))

$jwt = "$header.$payload.$signature"

# --- GitHub API helpers ---------------------------------------------------

$apiHeaders = @{
    Authorization          = "Bearer $jwt"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}

# --- Find the app installation for the target owner ----------------------

$owner    = ($Repo -split '/')[0]
$repoName = ($Repo -split '/')[1]

$installations = Invoke-RestMethod `
    -Uri     'https://api.github.com/app/installations' `
    -Headers $apiHeaders

$installation = $installations |
    Where-Object { $_.account.login -eq $owner } |
    Select-Object -First 1

if (-not $installation) {
    Write-Error (
        "salakist-agent is not installed on '$owner'. " +
        "Install it at https://github.com/apps/salakist-agent."
    )
    exit 1
}

# --- Exchange JWT for a repo-scoped installation access token ------------

$tokenResponse = Invoke-RestMethod `
    -Uri         "https://api.github.com/app/installations/$($installation.id)/access_tokens" `
    -Method      Post `
    -Headers     $apiHeaders `
    -Body        (ConvertTo-Json @{ repositories = @($repoName) } -Compress) `
    -ContentType 'application/json'

# Write token only — no extra output so callers can capture with $()
# Explicit trim prevents trailing newline/CRLF from corrupting the Authorization header
Write-Output $tokenResponse.token.Trim()
