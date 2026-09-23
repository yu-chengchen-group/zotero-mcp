$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

docker compose exec zotero-mcp `
    python /app/zotero_mcp_entrypoint.py update-db `
    --force-rebuild `
    --fulltext `
    --clear-fulltext-cache `
    --allow-mass-deletion

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
