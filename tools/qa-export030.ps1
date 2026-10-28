param(
    [Parameter(Mandatory)][string]$Serial,
    [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]+$')][string]$Name
)
# Synthetic QA only. Requires Settings open in this task's isolated AVD.
$ErrorActionPreference = 'Stop'
$qaRoot = Split-Path $PSScriptRoot -Parent
$qaAdb = 'D:/Codex/PocketFlowTools/android-sdk/platform-tools/adb.exe'
$qaAvdName = (& $qaAdb -s $Serial emu avd name | Select-Object -First 1).Trim()
if ($qaAvdName -ne 'CoffeeJournal_QA030') { throw 'Not the isolated Coffee Journal 0.3 QA device.' }
$env:ANDROID_SERIAL = $Serial
$env:COFFEE_EVIDENCE = Join-Path $qaRoot 'deliverables/v0.3.0/evidence'
$qaHelper = Join-Path $PSScriptRoot 'device.cjs'
& node $qaHelper tap '导出豆仓备份'
if ($LASTEXITCODE -ne 0) { throw 'Export action failed.' }
$qaNodes = & node $qaHelper nodes | ConvertFrom-Json
$qaFile = ($qaNodes | Where-Object { $_.class -eq 'android.widget.EditText' } | Select-Object -First 1).text
if ($qaFile -notmatch '^coffee-journal-v2-[0-9]+\.zip$') { throw 'Unexpected export filename.' }
& node $qaHelper tap SAVE
if ($LASTEXITCODE -ne 0) { throw 'System picker save failed.' }
Start-Sleep -Seconds 1
& $qaAdb -s $Serial pull "/sdcard/Download/$qaFile" (Join-Path $env:COFFEE_EVIDENCE "$Name.zip")
if ($LASTEXITCODE -ne 0) { throw 'Synthetic export copy failed.' }
