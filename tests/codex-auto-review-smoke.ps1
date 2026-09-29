# 自动 PR 审查触发测试；此脚本不会执行语义索引更新。
$entrypoint = Join-Path $PSScriptRoot '..\update-semantic-index.ps1'
if (-not (Test-Path -LiteralPath $entrypoint -PathType Leaf)) {
    throw 'update-semantic-index.ps1 not found'
}
