# 仅检查文件存在，不执行索引更新。
function Test-EntrypointFile {
    param([string]$Path)
    return (Test-Path -LiteralPath $Path -PathType Leaf)
}

$entrypoint = Join-Path $PSScriptRoot '..\update-semantic-index.ps1'
if (-not (Test-EntrypointFile -Path $entrypoint)) {
    throw 'update-semantic-index.ps1 not found'
}
