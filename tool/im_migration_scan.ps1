[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$OutputJson,
  [switch]$EnforceAdapterBoundary
)

$patterns = @(
  @{ Name = 'messageListMap'; Pattern = 'messageListMap|_messageListMap' },
  @{ Name = 'setMessageList'; Pattern = '\bsetMessageList\s*\(' },
  @{ Name = 'history'; Pattern = 'getHistoryMessageList(?:WithComplete|V2)?\s*\(' },
  @{ Name = 'advancedListener'; Pattern = '(?:add|remove)AdvancedMsgListener\s*\(' },
  @{ Name = 'sendMessage'; Pattern = '\bsendMessage\s*\(' }
)

$roots = @(
  (Join-Path $RepoRoot 'lib'),
  (Join-Path $RepoRoot 'third_party/tencent_cloud_chat_uikit/lib')
)
$files = Get-ChildItem -LiteralPath $roots -Recurse -File -Filter '*.dart' |
  Where-Object { $_.FullName -notmatch '[\\/]generated[\\/]' }

$rows = foreach ($file in $files) {
  $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
  for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
    foreach ($entry in $patterns) {
      if ($lines[$lineIndex] -match $entry.Pattern) {
        $relative = $file.FullName.Substring($RepoRoot.Length).TrimStart([char]92, [char]47)
        [pscustomobject]@{
          category = $entry.Name
          file = $relative -replace '[\\/]', '/'
          line = $lineIndex + 1
          text = $lines[$lineIndex].Trim()
          classification = if ($relative -match '^third_party/tencent_cloud_chat_uikit/lib/(data_services/message|business_logic/view_models)/') { 'legacy-tui-entry' } else { 'app-entry' }
        }
      }
    }
  }
}

$rows = @($rows | Sort-Object category, file, line)
$summary = $rows | Group-Object category | ForEach-Object {
  [pscustomobject]@{ category = $_.Name; count = $_.Count }
}

if ($OutputJson) {
  $outputPath = if ([IO.Path]::IsPathRooted($OutputJson)) {
    $OutputJson
  } else {
    Join-Path $RepoRoot $OutputJson
  }
  $parent = Split-Path -Parent $outputPath
  New-Item -ItemType Directory -Force -Path $parent | Out-Null
  [pscustomobject]@{
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    repoRoot = $RepoRoot
    summary = @($summary)
    entries = @($rows)
  } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $outputPath -Encoding UTF8
  Write-Output "json=$outputPath"
}

Write-Output 'IM migration static baseline'
Write-Output "repoRoot=$RepoRoot"
$summary | Format-Table -AutoSize | Out-String | Write-Output
Write-Output 'entries:'
$rows | ConvertTo-Json -Depth 3 | Write-Output

if ($EnforceAdapterBoundary) {
  $allowed = @(
    '^lib/src/services/im/',
    '^third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart$'
  )
  $violations = @($rows | Where-Object {
      $path = $_.file
      -not ($allowed | Where-Object { $path -match $_ })
    })
  if ($violations.Count -gt 0) {
    Write-Error "Adapter boundary violations: $($violations.Count)"
    exit 2
  }
}
