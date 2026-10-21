param([string]$ToolRoot = 'D:/Codex/PocketFlowTools')
# Current-process environment only. Reuses installed tools and local caches.
$ErrorActionPreference = 'Stop'
$env:FLUTTER_ROOT = Join-Path $ToolRoot '3.47.7/flutter'
$env:JAVA_HOME = Join-Path $ToolRoot 'jdk17/jdk-17.0.20.1+1'
$env:ANDROID_HOME = Join-Path $ToolRoot 'android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = Join-Path $ToolRoot 'cache/android'
$env:PUB_CACHE = Join-Path $ToolRoot 'cache/pub'
$env:GRADLE_USER_HOME = Join-Path $ToolRoot 'cache/gradle'
$env:GRADLE_OPTS = '-Dorg.gradle.offline=true'
$env:CI = 'true'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:TEMP = Join-Path $PSScriptRoot '../.local/tmp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force -Path $env:TEMP | Out-Null
$env:PATH = (Join-Path $env:FLUTTER_ROOT 'bin') + ';' + (Join-Path $env:JAVA_HOME 'bin') + ';' + (Join-Path $env:ANDROID_HOME 'platform-tools') + ';' + $env:PATH
function Invoke-CoffeeFlutter {
    & (Join-Path $env:FLUTTER_ROOT 'bin/cache/dart-sdk/bin/dart.exe') (Join-Path $env:FLUTTER_ROOT 'bin/cache/flutter_tools.snapshot') @args
}
