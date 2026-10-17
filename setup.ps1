param(
    [ValidateSet("install", "update", "doctor", "uninstall")]
    [string]$Action = "install"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $root ".env"
$envTemplate = Join-Path $root "env\.env.example"

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $Name"
    }
}

function Get-EnvValue([string]$Name) {
    if (-not (Test-Path $envFile)) { return $null }
    foreach ($line in [IO.File]::ReadAllLines($envFile)) {
        if ($line.StartsWith("$Name=")) { return $line.Substring($Name.Length + 1) }
    }
    return $null
}

function Set-EnvValue([string]$Name, [string]$Value) {
    $lines = [Collections.Generic.List[string]]::new()
    if (Test-Path $envFile) {
        foreach ($line in [IO.File]::ReadAllLines($envFile)) { [void]$lines.Add($line) }
    }
    $prefix = "$Name="
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].StartsWith($prefix)) {
            $lines[$i] = $prefix + $Value
            $found = $true
            break
        }
    }
    if (-not $found) { [void]$lines.Add($prefix + $Value) }
    [IO.File]::WriteAllLines($envFile, $lines, [Text.UTF8Encoding]::new($false))
}

function Resolve-ZoteroDataDir {
    $configured = Get-EnvValue "ZOTERO_DATA_DIR"
    if ($configured -and (Test-Path (Join-Path $configured "zotero.sqlite"))) { return $configured.Replace('\', '/') }

    $default = Join-Path $env:USERPROFILE "Zotero"
    if (Test-Path (Join-Path $default "zotero.sqlite")) { return $default.Replace('\', '/') }

    $entered = Read-Host "Zotero data directory (folder containing zotero.sqlite)"
    if ([string]::IsNullOrWhiteSpace($entered) -or -not (Test-Path (Join-Path $entered "zotero.sqlite"))) {
        throw "zotero.sqlite was not found in the selected directory."
    }
    return (Resolve-Path $entered).Path.Replace('\', '/')
}

function Resolve-ResourceUrl {
    $configured = Get-EnvValue "ZOTERO_MCP_RESOURCE_URL"
    if ($configured -and $configured -notmatch 'zotero-xxx') { return $configured.TrimEnd('/') }
    $entered = Read-Host "Assigned Zotero MCP URL (for example https://zotero-abc.chen-group.cn)"
    if ($entered -notmatch '^https://[^/]+') { throw "A valid https:// Zotero MCP URL is required." }
    return $entered.TrimEnd('/')
}

function Invoke-ComposeUp {
    & docker compose pull
    if ($LASTEXITCODE -ne 0) { throw "docker compose pull failed. Confirm GHCR login, then retry." }
    & docker compose up -d
    if ($LASTEXITCODE -ne 0) { throw "docker compose up failed." }
}

function Invoke-Doctor {
    Require-Command "docker"
    if (-not (Test-Path $envFile)) { throw ".env is missing. Run install first." }

    $dataDir = Get-EnvValue "ZOTERO_DATA_DIR"
    if (-not $dataDir -or -not (Test-Path (Join-Path $dataDir "zotero.sqlite"))) {
        throw "Configured ZOTERO_DATA_DIR does not contain zotero.sqlite."
    }
    $resourceUrl = Get-EnvValue "ZOTERO_MCP_RESOURCE_URL"
    if (-not $resourceUrl -or $resourceUrl -match 'zotero-xxx') { throw "ZOTERO_MCP_RESOURCE_URL is not configured." }

    & docker info *> $null
    if ($LASTEXITCODE -ne 0) { throw "Docker Desktop is not running." }
    $running = @(& docker compose ps --status running --services)
    if ($LASTEXITCODE -ne 0 -or "zotero-mcp" -notin $running) { throw "zotero-mcp container is not running." }
    if (-not (Get-Process zotero -ErrorAction SilentlyContinue)) { throw "Zotero Desktop is not running." }

    try {
        Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:23119/api/users/0/items?limit=1" -TimeoutSec 10 | Out-Null
    }
    catch {
        throw "Zotero local API is not reachable on 127.0.0.1:23119."
    }
    Write-Host "Zotero MCP check passed." -ForegroundColor Green
}

Set-Location $root

switch ($Action) {
    "install" {
        Require-Command "git"
        Require-Command "gh"
        Require-Command "docker"
        & gh auth status -h github.com
        if ($LASTEXITCODE -ne 0) { throw "GitHub CLI is not logged in. Run gh auth login first." }
        & docker info *> $null
        if ($LASTEXITCODE -ne 0) { throw "Docker Desktop is not running." }

        if (-not (Test-Path $envFile)) { Copy-Item $envTemplate $envFile }
        Set-EnvValue "ZOTERO_DATA_DIR" (Resolve-ZoteroDataDir)
        Set-EnvValue "ZOTERO_MCP_RESOURCE_URL" (Resolve-ResourceUrl)
        Invoke-ComposeUp
        Write-Host "Install complete. Start Zotero, then run setup.ps1 doctor." -ForegroundColor Green
    }
    "update" {
        Require-Command "git"
        Require-Command "docker"
        $dirty = & git status --porcelain
        if ($LASTEXITCODE -ne 0) { throw "git status failed." }
        if ($dirty) { throw "Repository has local changes. Commit or restore them before updating." }
        & git pull --ff-only origin main
        if ($LASTEXITCODE -ne 0) { throw "git pull failed." }
        Invoke-ComposeUp
        Write-Host "Update complete." -ForegroundColor Green
    }
    "doctor" { Invoke-Doctor }
    "uninstall" {
        Require-Command "docker"
        if (Test-Path $envFile) {
            & docker compose down
            if ($LASTEXITCODE -ne 0) { throw "docker compose down failed." }
        }
        Write-Host "Zotero MCP containers removed. .env and Zotero data were kept." -ForegroundColor Green
    }
}
