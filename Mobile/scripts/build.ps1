param([string]$ApiBaseUrl = 'http://mc.ainfinitythecoder.cn', [switch]$Demo)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\env.ps1"
Set-Location $env:DEERAFT_ROOT
if ($ApiBaseUrl -notmatch '^https://[^/]+/?$' -and $ApiBaseUrl -notmatch '^http://mc\.ainfinitythecoder\.cn(:[0-9]+)?/?$') { throw 'Use HTTPS or the existing Deeraft HTTP origin.' }
& flutter.bat pub get
if ($LASTEXITCODE) { throw 'pub get failed' }
& flutter.bat analyze
if ($LASTEXITCODE) { throw 'analysis failed' }
& flutter.bat test
if ($LASTEXITCODE) { throw 'tests failed' }
& flutter.bat build apk --debug "--dart-define=API_BASE_URL=$ApiBaseUrl" "--dart-define=DEMO_MODE=$($Demo.IsPresent.ToString().ToLower())"
if ($LASTEXITCODE) { throw 'APK build failed' }
New-Item -ItemType Directory -Force dist | Out-Null
Copy-Item build/app/outputs/flutter-apk/app-debug.apk dist/Deeraft-test.apk
Write-Host "APK: $env:DEERAFT_ROOT\dist\Deeraft-test.apk"
