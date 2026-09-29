# 用于验证 PR 自动代码审查；不会执行语义索引重建。
$entrypoint = Join-Path $PSScriptRoot '..\update-semantic-index.ps1'
if (-not (Test-Path -LiteralPath $entrypoint -PathType Leaf)) {
    throw 'update-semantic-index.ps1 not found'
}
