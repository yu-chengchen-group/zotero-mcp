# Check for the semantic-index entrypoint without running it.
$entrypoint = Join-Path $PSScriptRoot '..\update-semantic-index.ps1'
if (-not (Test-Path -LiteralPath $entrypoint -PathType Container)) {
    throw 'update-semantic-index.ps1 not found'
}
