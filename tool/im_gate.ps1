# IM-11: full static + unit gate entrypoint
#
# Runs (in CI and locally):
#   - dart format         (format check on lib/src/services/im + test/im*)
#   - dart analyze        (static analysis, IM paths, --fatal-infos --fatal-warnings)
#   - flutter test        (IM suite: im04/im05/im06/im08/im09/im10/im_contracts)
#   - im10_migration_scan (setMessageList/messageListMap write-path scan)
#
# Usage:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File tool/im_gate.ps1
#   ./tool/im_gate.ps1 -SkipAnalyze
#   ./tool/im_gate.ps1 -SkipTest
#   ./tool/im_gate.ps1 -SkipScan
#
# Exit codes:
#   0 - all gates pass
#   1 - any gate failed
#
# ADR:  docs/im10_overlay_row_namespace.md
# CI:   .github/workflows/im-gate.yml

[CmdletBinding()]
param(
    [switch] $SkipFormat,
    [switch] $SkipAnalyze,
    [switch] $SkipTest,
    [switch] $SkipScan,
    [string] $FlutterRoot = 'D:\flutter_windows_3.44.1-stable\flutter'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$env:APPDATA     = Join-Path (Get-Location) '.dart-appdata'
$env:LOCALAPPDATA = Join-Path (Get-Location) '.dart-localappdata'

function Write-Section([string] $Name) {
    Write-Host ''
    Write-Host ('=== ' + $Name + ' ===') -ForegroundColor Cyan
}

function Resolve-FlutterToolsSnapshot {
    param([string] $RootPath)
    $candidates = @(
        (Join-Path $RootPath 'bin\cache\flutter_tools.snapshot'),
        (Join-Path $RootPath 'bin\internal\flutter_tools.snapshot')
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    throw ('flutter_tools.snapshot not found under ' + $RootPath)
}

function Resolve-IMPaths {
    # IM scope: lib/src/services/im/** + test/im*_*.dart (test files matching im prefix)
    $lib = @()
    if (Test-Path -LiteralPath 'lib/src/services/im') {
        $lib = @(Get-ChildItem -Path 'lib/src/services/im' -Filter '*.dart' -Recurse | ForEach-Object { $_.FullName.Substring($root.Length + 1) })
    }
    $tests = @(Get-ChildItem -Path 'test' -Filter 'im*_*.dart' | ForEach-Object { $_.FullName.Substring($root.Length + 1) })
    return (@($lib) + @($tests))
}

function Invoke-DartTool {
    param([string] $Tool, [string[]] $OtherArgs)
    $dartExe = Join-Path $FlutterRoot 'bin\cache\dart-sdk\bin\dart.exe'
    if (-not (Test-Path -LiteralPath $dartExe)) {
        throw ('dart.exe not found: ' + $dartExe)
    }
    if ($Tool -eq 'flutter') {
        $snap = Resolve-FlutterToolsSnapshot -RootPath $FlutterRoot
        $all = @('--disable-dart-dev', $snap) + $OtherArgs
    } else {
        $all = $OtherArgs
    }
    & $dartExe @all | Out-Host
    return [int] $LASTEXITCODE
}

$failures = New-Object System.Collections.Generic.List[string]

# === 1. dart format ============================================
if (-not $SkipFormat) {
    Write-Section 'dart format (lib/src/services/im + test/im*)'
    $targets = Resolve-IMPaths
    $code = Invoke-DartTool -Tool 'dart' -OtherArgs (@('format', '--output=none', '--set-exit-if-changed') + $targets)
    if ($code -ne 0) {
        $failures.Add('[format] dart format reported changes (run: dart format lib/src/services/im test/im*)')
    } else {
        Write-Host '[format] OK' -ForegroundColor Green
    }
} else {
    Write-Host '[skip] dart format' -ForegroundColor Yellow
}

# === 2. dart analyze ==========================================
if (-not $SkipAnalyze) {
    Write-Section 'dart analyze (lib/src/services/im + test/im*)'
    $targets = Resolve-IMPaths
    $code = Invoke-DartTool -Tool 'dart' -OtherArgs (@('analyze', '--fatal-infos', '--fatal-warnings') + $targets)
    if ($code -ne 0) {
        $failures.Add('[analyze] dart analyze reported issues (run: dart analyze lib/src/services/im test/im* to see)')
    } else {
        Write-Host '[analyze] OK' -ForegroundColor Green
    }
} else {
    Write-Host '[skip] dart analyze' -ForegroundColor Yellow
}

# === 3. flutter test (IM suite) ===============================
if (-not $SkipTest) {
    Write-Section 'flutter test (IM suite)'
    $testFiles = @(
        'test/im04_message_writer_contract_test.dart',
        'test/im05_persistence_test.dart',
        'test/im06_history_search_coordinator_test.dart',
        'test/im08_outgoing_send_coordinator_test.dart',
        'test/im09_c2c_receive_opt_service_test.dart',
        'test/im10_migration_scan_test.dart',
        'test/im_contracts_test.dart'
    )
    $missing = @()
    foreach ($f in $testFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $f))) {
            $missing += $f
        }
    }
    if ($missing.Count -gt 0) {
        Write-Host ('[test] missing test files: ' + ($missing -join ', ')) -ForegroundColor Red
        $failures.Add('[test] missing IM test files')
    } else {
        $testFailures = New-Object System.Collections.Generic.List[string]
        foreach ($f in $testFiles) {
            Write-Host ('[test] ' + $f)
            $code = Invoke-DartTool -Tool 'flutter' -OtherArgs (@('test', '--no-pub', $f))
            if ($code -ne 0) {
                $testFailures.Add($f)
            }
        }
        if ($testFailures.Count -gt 0) {
            foreach ($f in $testFailures) {
                $failures.Add(('[test] FAIL ' + $f))
            }
        } else {
            Write-Host ('[test] IM suite OK (' + $testFiles.Count + ' files)') -ForegroundColor Green
        }
    }
} else {
    Write-Host '[skip] flutter test' -ForegroundColor Yellow
}

# === 4. im10_migration_scan (static scan) ======================
if (-not $SkipScan) {
    Write-Section 'im10 migration scan'
    $scanScript = Join-Path $root 'tool\im10_migration_scan.ps1'
    if (-not (Test-Path -LiteralPath $scanScript)) {
        $failures.Add('[scan] tool/im10_migration_scan.ps1 not found')
    } else {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $scanScript
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            $failures.Add('[scan] im10_migration_scan reported violations')
        } else {
            Write-Host '[scan] OK' -ForegroundColor Green
        }
    }
} else {
    Write-Host '[skip] im10 migration scan' -ForegroundColor Yellow
}

# === 5. summary ===============================================
Write-Section 'IM-11 GATE SUMMARY'
if ($failures.Count -eq 0) {
    Write-Host '[IM-11] all gates PASS' -ForegroundColor Green
    exit 0
} else {
    Write-Host ('[IM-11] ' + $failures.Count + ' gate(s) FAIL:') -ForegroundColor Red
    foreach ($f in $failures) {
        Write-Host ('  - ' + $f)
    }
    exit 1
}