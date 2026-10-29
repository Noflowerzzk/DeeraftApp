param([string]$Executable='', [switch]$Packaged)
$ErrorActionPreference='Stop'
$desktop=Split-Path $PSScriptRoot
$names=@('PATH','QT_PLUGIN_PATH','QML_IMPORT_PATH','TEMP','TMP','DEERAFT_SMOKE_DIR','DEERAFT_UPDATE_PROBE','DEERAFT_DESIGN_FIXTURE','DEERAFT_QML_DIR','DEERAFT_POLISH_PROBE','DEERAFT_AUDIT_ROOT','DEERAFT_IMPORT_DIRECTORY','DEERAFT_SOURCE_PROBE','DEERAFT_REPAIR_PROBE','DEERAFT_SMOKE_ACCOUNT')
$saved=@{};foreach($name in $names){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
 $prefix="$desktop/.toolchain/msys64/ucrt64"
 $env:PATH="$prefix/bin;"+$env:PATH;$env:QT_PLUGIN_PATH="$prefix/share/qt6/plugins";$env:QML_IMPORT_PATH="$prefix/share/qt6/qml"
 if(!$Executable){$Executable="$desktop/build/Release/DeeraftApp.exe"}
 if($Packaged){$package=Split-Path (Resolve-Path -LiteralPath $Executable);$env:PATH="$env:SystemRoot/System32;$env:SystemRoot";$env:QT_PLUGIN_PATH=$package;$env:QML_IMPORT_PATH="$package/qml"}
 $env:TEMP="$desktop/.cache/tmp";$env:TMP=$env:TEMP
 foreach($name in @('DEERAFT_QML_DIR','DEERAFT_POLISH_PROBE','DEERAFT_AUDIT_ROOT','DEERAFT_IMPORT_DIRECTORY','DEERAFT_SOURCE_PROBE','DEERAFT_REPAIR_PROBE','DEERAFT_SMOKE_ACCOUNT')){[Environment]::SetEnvironmentVariable($name,$null,'Process')}
 $fixture="$desktop/.cache/updates-fixture";New-Item -ItemType Directory -Force $fixture | Out-Null
 Copy-Item "$PSScriptRoot/fixtures/repairs.json" "$fixture/fixture.json";Copy-Item "$PSScriptRoot/fixtures/FixtureClient.qml" $fixture
 $env:DEERAFT_DESIGN_FIXTURE=$fixture;$env:DEERAFT_UPDATE_PROBE='1';$env:DEERAFT_SMOKE_DIR="$desktop/.cache/update-checks/$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
 $process=Start-Process $Executable -ArgumentList @('--dir',('"'+$env:DEERAFT_SMOKE_DIR+'/data"')) -WindowStyle Hidden -PassThru
 if(!$process.WaitForExit(25000)){Stop-Process -Id $process.Id;throw 'Update check probe timed out'}
 $report=Get-Content "$env:DEERAFT_SMOKE_DIR/update-check.json" -Raw | ConvertFrom-Json
 if($process.ExitCode -ne 0 -or !$report.success){throw ($report | ConvertTo-Json)}
 $report | ConvertTo-Json
 Write-Output "Signed live update channel verified: $env:DEERAFT_SMOKE_DIR"
} finally {foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}}
