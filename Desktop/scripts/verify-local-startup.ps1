param(
    [string]$InstanceDirectory='F:\Users\张桢锴\Documents\软件\MultiMC\instances',
    [string]$Version='26.2_bac',
    [string]$Executable='',
    [switch]$Packaged
)
$ErrorActionPreference='Stop'
$desktop=Split-Path $PSScriptRoot
$names=@('PATH','QT_PLUGIN_PATH','QML_IMPORT_PATH','TEMP','TMP','DEERAFT_SMOKE_DIR','DEERAFT_AUDIT_ROOT','DEERAFT_AUDIT_VERSION','DEERAFT_DESIGN_FIXTURE','DEERAFT_QML_DIR','DEERAFT_SMOKE_ACCOUNT','DEERAFT_POLISH_PROBE','DEERAFT_REPAIR_PROBE','DEERAFT_IMPORT_DIRECTORY')
$saved=@{};foreach($name in $names){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
    $prefix="$desktop/.toolchain/msys64/ucrt64"
    $env:PATH="$prefix/bin;"+$env:PATH
    $env:QT_PLUGIN_PATH="$prefix/share/qt6/plugins";$env:QML_IMPORT_PATH="$prefix/share/qt6/qml"
    if(!$Executable){$Executable="$desktop/build/Release/DeeraftApp.exe"}
    if($Packaged){$package=Split-Path (Resolve-Path -LiteralPath $Executable);$env:PATH="$env:SystemRoot/System32;$env:SystemRoot";$env:QT_PLUGIN_PATH=$package;$env:QML_IMPORT_PATH="$package/qml"}
    $env:TEMP="$desktop/.cache/tmp";$env:TMP=$env:TEMP
    $fixture="$desktop/.cache/startup-audit-fixture";New-Item -ItemType Directory -Force $fixture | Out-Null
    Copy-Item "$PSScriptRoot/fixtures/repairs.json" "$fixture/fixture.json";Copy-Item "$PSScriptRoot/fixtures/FixtureClient.qml" $fixture
    $env:DEERAFT_DESIGN_FIXTURE=$fixture;$env:DEERAFT_QML_DIR=$null;$env:DEERAFT_SMOKE_ACCOUNT=$null;$env:DEERAFT_POLISH_PROBE=$null;$env:DEERAFT_REPAIR_PROBE=$null;$env:DEERAFT_IMPORT_DIRECTORY=$null
    $env:DEERAFT_AUDIT_ROOT=$InstanceDirectory;$env:DEERAFT_AUDIT_VERSION=$Version
    $output="$desktop/.cache/startup-audit/$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')";$env:DEERAFT_SMOKE_DIR=$output
    $homeDirectory=Split-Path $InstanceDirectory
    $files=@("$InstanceDirectory/$Version/instance.cfg","$InstanceDirectory/$Version/mmc-pack.json")
    $components=(Get-Content -LiteralPath $files[1] -Raw | ConvertFrom-Json).components
    foreach($component in $components){$files+="$homeDirectory/meta/$($component.uid)/$($component.version).json"}
    $files+=@(Get-ChildItem -LiteralPath "$homeDirectory/assets/indexes" -File | Select-Object -ExpandProperty FullName)
    $before=@{};foreach($file in $files){if(Test-Path -LiteralPath $file){$before[$file]=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}}
    $process=Start-Process $Executable -ArgumentList @('--dir',('"'+$output+'/data"')) -WindowStyle Hidden -PassThru
    if(!$process.WaitForExit(60000)){Stop-Process -Id $process.Id;throw "Local preparation audit timed out: $output"}
    $report=Get-Content "$output/launch-audit.json" -Raw | ConvertFrom-Json
    $report | ConvertTo-Json -Depth 8
    if($process.ExitCode -or !$report.success -or $report.networkAttempts -ne 0 -or !$report.localMetadataReady -or $report.automaticJavaDownload -or !$report.ignoreJavaCompatibility -or !$report.readOnlyAssets -or $report.localJavas.Count -lt 1){throw "Local preparation audit failed: $output"}
    if(Test-Path -LiteralPath "$output/data/assets/objects"){if(Get-ChildItem -LiteralPath "$output/data/assets/objects" -Recurse -File){throw 'Complete original assets were unnecessarily copied'}}
    foreach($tree in @('libraries','meta')){if(Test-Path -LiteralPath "$output/data/$tree"){if(Get-ChildItem -LiteralPath "$output/data/$tree" -Recurse -File | Where-Object {$_.Extension -in '.jar','.json'}){throw "Original $tree was unnecessarily copied"}}}
    if($report.instanceRoot.Replace('\','/').TrimEnd('/') -ne "$InstanceDirectory/$Version".Replace('\','/').TrimEnd('/')){throw 'Instance is not running in its original directory'}
    foreach($file in $report.classPath){if(!(Test-Path -LiteralPath $file -PathType Leaf) -or !$file.Replace('\','/').StartsWith($homeDirectory.Replace('\','/')+'/',[StringComparison]::OrdinalIgnoreCase)){throw "Classpath did not reuse the original directory: $file"}}
    foreach($file in $before.Keys){if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $before[$file]){throw "Original metadata changed: $file"}}
    Write-Output "Original metadata unchanged: $($before.Count) files. Evidence: $output"
} finally {foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}}
