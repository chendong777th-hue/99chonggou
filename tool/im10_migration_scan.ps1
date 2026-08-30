<#
.SYNOPSIS
IM-10 Overlay/Row namespace 迁移扫描。

.DESCRIPTION
扫描 `setMessageList` 和 `messageListMap` 写路径，验证 lib/src/ 内所有命中
都在白名单中（白名单见 docs/im10_overlay_row_namespace.md §3.1）。
每个 IM-10 phase B..G 收口一个白名单项后必须从白名单移除。
IM-10 phase J（IM-11 静态门禁）期望白名单为空。

用法:
  pwsh -NoProfile -ExecutionPolicy Bypass -File tool/im10_migration_scan.ps1
#>

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$libScan = Join-Path (Get-Location) 'lib'
$docsFile = Join-Path (Get-Location) 'docs/im10_overlay_row_namespace.md'

# 临时白名单: lib/src 内允许的 setMessageList 调用方 (file:line)。
# 每收口一个必须从这里移除。IM-10 phase J 期望为空。
$allowList = @(
  'lib/src/chat.dart:3853'
  'lib/src/chat.dart:3862'
  'lib/src/chat.dart:8053'
  'lib/src/chat.dart:8422'
  'lib/src/chat.dart:9868'
  'lib/src/services/archive_im_local_persist_service.dart:344'
  'lib/src/services/archive_im_local_persist_service.dart:766'
  'lib/src/services/group_local/group_tips_operator_patch_service.dart:207'
  'lib/src/services/group_local/group_tips_operator_patch_service.dart:255'
  'lib/src/services/silent_archive_service.dart:235'
  'lib/src/utils/call_bubble_dedupe.dart:283'
)

$violations = @()
$hitCount = 0

# 1. setMessageList( 路径 (lib/src 内)
$setLines = rg -n --glob 'lib/src/**/*.dart' 'setMessageList\s*\(' lib/src 2>$null
foreach ($line in $setLines) {
  $hitCount++
  # rg 输出格式: path:line:content
  $parts = $line -split ':', 3
  if ($parts.Count -lt 3) { continue }
  $file = $parts[0] -replace '\\', '/'
  $lineNo = $parts[1]
  $key = "$file`:$lineNo"
  if ($allowList -notcontains $key) {
    $violations += "  [setMessageList] $key :: $($parts[2].Trim())"
  }
}

# 2. messageListMap[xxx] = 路径 (lib/src 内, 不允许直接写)
$writeLines = rg -n --glob 'lib/src/**/*.dart' 'messageListMap\s*\[' lib/src 2>$null
foreach ($line in $writeLines) {
  $parts = $line -split ':', 3
  if ($parts.Count -lt 3) { continue }
  $content = $parts[2].Trim()
  # 过滤掉纯读路径 (? / ?? / const)
  if ($content -match '\?\?|=.*messageListMap|const\s*<') { continue }
  if ($content -match '\[.*\]\s*=') {
    $violations += "  [messageListMap write] $($parts[0]):$($parts[1]) :: $content"
  }
}

Write-Host '=== IM-10 Migration Scan ==='
Write-Host "[scanned] setMessageList hits: $hitCount"
Write-Host "[allowList] $($allowList.Count) entries (see docs/im10_overlay_row_namespace.md §3.1)"

if ($violations.Count -gt 0) {
  Write-Host ''
  Write-Host '[FAIL] violations outside allow list:' -ForegroundColor Red
  foreach ($v in $violations) { Write-Host $v }
  exit 1
}

Write-Host ''
Write-Host '[OK] all setMessageList calls are inside the IM-10 allow list.' -ForegroundColor Green
exit 0
