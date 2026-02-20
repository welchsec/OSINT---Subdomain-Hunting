# Subdomain Lookup Tool - PowerShell Version
# Queries ALL three sources and merges into one deduplicated list:
#   1. crt.sh         (certificate transparency logs)
#   2. HackerTarget   (free, no API key needed)
#   3. AlienVault OTX (free, no API key needed)
# Works natively on Windows PowerShell 5.1+ or PowerShell 7+

function Get-CleanDomains {
    param([string[]]$RawList, [string]$FilterDomain)
    $RawList |
        ForEach-Object { $_ -split "`n" } |
        ForEach-Object { $_.Trim() -replace '^\*\.', '' } |
        Where-Object { $_ -ne '' -and $_ -ne $null -and $_ -notmatch '^\s*$' } |
        Where-Object { $_ -match [regex]::Escape($FilterDomain) } |
        Sort-Object -Unique
}

# ── Source 1: crt.sh ────────────────────────────────────────────────────────
function Query-CrtSh {
    param([string]$Domain)
    $url = "https://crt.sh/?q=%25.$Domain&output=json"
    $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 25 -ErrorAction Stop
    if (-not $resp -or $resp.Count -eq 0) { throw "Empty response" }
    return Get-CleanDomains ($resp | ForEach-Object { $_.name_value }) $Domain
}

# ── Source 2: HackerTarget ──────────────────────────────────────────────────
function Query-HackerTarget {
    param([string]$Domain)
    $url = "https://api.hackertarget.com/hostsearch/?q=$Domain"
    $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 25 -ErrorAction Stop
    if ($resp -match "error|API count") { throw "HackerTarget error: $resp" }
    $lines = $resp -split "`n" | Where-Object { $_ -ne '' }
    $subdomains = $lines | ForEach-Object { ($_ -split ',')[0].Trim() }
    if ($subdomains.Count -eq 0) { throw "Empty response" }
    return Get-CleanDomains $subdomains $Domain
}

# ── Source 3: AlienVault OTX ────────────────────────────────────────────────
function Query-AlienVault {
    param([string]$Domain)
    $allHostnames = @()
    $page = 1

    do {
        $url = "https://otx.alienvault.com/api/v1/indicators/domain/$Domain/passive_dns?page=$page"
        $resp = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 25 -ErrorAction Stop
        if (-not $resp.passive_dns -or $resp.passive_dns.Count -eq 0) { break }
        $allHostnames += $resp.passive_dns | ForEach-Object { $_.hostname }
        $page++
        # OTX pages results; stop if fewer than 20 returned (last page)
    } while ($resp.passive_dns.Count -ge 20)

    if ($allHostnames.Count -eq 0) { throw "Empty response" }
    return Get-CleanDomains $allHostnames $Domain
}

# ── Main ─────────────────────────────────────────────────────────────────────

$domain = Read-Host "Enter domain to look up (e.g. example.com)"

if ([string]::IsNullOrWhiteSpace($domain)) {
    Write-Host "No domain entered. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Looking up subdomains for: $domain" -ForegroundColor Cyan
Write-Host "Querying all sources in parallel, please wait..." -ForegroundColor Gray
Write-Host "-----------------------------------"

$allResults = @()
$sourceSummary = @()

$sources = @(
    @{ Name = "crt.sh";         Func = { Query-CrtSh $domain } },
    @{ Name = "HackerTarget";   Func = { Query-HackerTarget $domain } },
    @{ Name = "AlienVault OTX"; Func = { Query-AlienVault $domain } }
)

foreach ($source in $sources) {
    try {
        $found = & $source.Func
        $count = if ($found) { @($found).Count } else { 0 }
        $allResults += $found
        $sourceSummary += "  [+] $($source.Name): $count result(s)" 
    } catch {
        $sourceSummary += "  [-] $($source.Name): Failed - $($_.Exception.Message)"
    }
}

# Final deduplicated sorted list across all sources
$finalResults = $allResults |
    Where-Object { $_ -ne '' -and $_ -ne $null } |
    Sort-Object -Unique

Write-Host ""
Write-Host "Source Summary:" -ForegroundColor Cyan
$sourceSummary | ForEach-Object {
    if ($_ -match '^\s*\[+\]') {
        Write-Host $_ -ForegroundColor Green
    } else {
        Write-Host $_ -ForegroundColor Yellow
    }
}

Write-Host ""
if (-not $finalResults -or $finalResults.Count -eq 0) {
    Write-Host "No results found for '$domain' from any source." -ForegroundColor Red
    exit 1
}

Write-Host "$($finalResults.Count) unique subdomain(s) found (all sources combined):" -ForegroundColor Cyan
Write-Host "-----------------------------------"
$finalResults | ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host "Done." -ForegroundColor Green
