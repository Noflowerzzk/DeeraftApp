param([string]$Executable='', [switch]$Packaged)
$ErrorActionPreference='Stop'
$names=@('PATH','QT_PLUGIN_PATH','QML_IMPORT_PATH','TEMP','TMP','DEERAFT_DESIGN_FIXTURE','DEERAFT_POLISH_PROBE','DEERAFT_SMOKE_DIR','DEERAFT_QML_DIR','DEERAFT_SMOKE_ACCOUNT')
$saved=@{};foreach($name in $names){$saved[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
    $desktop=Split-Path $PSScriptRoot
    $prefix=Join-Path $desktop '.toolchain/msys64/ucrt64'
    $env:PATH="$prefix/bin;"+$env:PATH
    $env:QT_PLUGIN_PATH="$prefix/share/qt6/plugins";$env:QML_IMPORT_PATH="$prefix/share/qt6/qml"
    if(!$Executable){$Executable="$desktop/build/Release/DeeraftApp.exe"}
    if($Packaged){$package=Split-Path (Resolve-Path -LiteralPath $Executable);$env:PATH="$env:SystemRoot/System32;$env:SystemRoot";$env:QT_PLUGIN_PATH=$package;$env:QML_IMPORT_PATH="$package/qml"}
    $env:TEMP="$desktop/.cache/tmp";$env:TMP=$env:TEMP
    $fixture="$desktop/.cache/polish-fixture";New-Item -ItemType Directory -Force $fixture | Out-Null
    Copy-Item "$PSScriptRoot/fixtures/repairs.json" "$fixture/fixture.json"
    Copy-Item "$PSScriptRoot/fixtures/FixtureClient.qml" $fixture
    $env:DEERAFT_DESIGN_FIXTURE=$fixture;$env:DEERAFT_POLISH_PROBE='1'
    $env:DEERAFT_SMOKE_DIR="$desktop/.cache/polish-shots/$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
    $env:DEERAFT_QML_DIR="$desktop/app/qml";$env:DEERAFT_SMOKE_ACCOUNT='DeeraftTest'
    if($Packaged){$env:DEERAFT_QML_DIR=$null}
    $testData="$env:DEERAFT_SMOKE_DIR/app-data"
    $process=Start-Process $Executable -ArgumentList @('--dir',('"'+$testData+'"')) -WindowStyle Hidden -PassThru
    if(!$process.WaitForExit(22000)){Stop-Process -Id $process.Id;throw 'Polish probe timed out'}
    if($process.ExitCode){throw "Probe exited $($process.ExitCode)"}
    $report=Get-Content "$env:DEERAFT_SMOKE_DIR/polish-checks.json" -Raw | ConvertFrom-Json
    $report | ConvertTo-Json -Depth 8
    foreach($check in @('modDelegatePreserved','modSwitchChanged','modScrollPreserved','modDidNotReload','modSearchFilters','tabDidNotReload','coverPreserved','externalInventoryRefresh','headerScrollsAway','carouselVisible','carouselNavigates','communityScrollable','communityWheelMoved','communityNoOverscroll','downloadCancelled','cancelButtonFound','cancelButtonPreserved')){
        if(!$report.$check){throw "Failed polish check: $check ($env:DEERAFT_SMOKE_DIR)"}
    }
    if($report.drawerIntermediatePosition -le 0 -or $report.drawerIntermediatePosition -ge 1){throw 'Side sheet did not move through an intermediate position'}
    $errors=Select-String -Path "$testData/logs/DeeraftApp-0.log" -Pattern 'ReferenceError|TypeError|Binding loop|Cannot assign|Unable to assign|is not a type'
    if($errors){throw ($errors | Out-String)}
    Write-Output "Evidence: $env:DEERAFT_SMOKE_DIR"
} finally {foreach($name in $names){if($null -eq $saved[$name]){Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue}else{[Environment]::SetEnvironmentVariable($name,$saved[$name],'Process')}}}
