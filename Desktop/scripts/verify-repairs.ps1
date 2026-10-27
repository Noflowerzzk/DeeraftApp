$ErrorActionPreference='Stop'
$environmentNames=@('PATH','QT_PLUGIN_PATH','QML_IMPORT_PATH','TEMP','TMP','DEERAFT_DESIGN_FIXTURE','DEERAFT_REPAIR_PROBE','DEERAFT_SMOKE_DIR','DEERAFT_QML_DIR','DEERAFT_SMOKE_ACCOUNT')
$previousEnvironment=@{}
foreach($name in $environmentNames){$previousEnvironment[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
$desktop=Split-Path $PSScriptRoot
$prefix=Join-Path $desktop '.toolchain/msys64/ucrt64'
$env:PATH="$prefix/bin;"+$env:PATH
$env:QT_PLUGIN_PATH="$prefix/share/qt6/plugins"
$env:QML_IMPORT_PATH="$prefix/share/qt6/qml"
$env:TEMP="$desktop/.cache/tmp"
$env:TMP=$env:TEMP
$fixture="$desktop/.cache/repair-fixture"
New-Item -ItemType Directory -Force $fixture | Out-Null
$data=Get-Content "$PSScriptRoot/fixtures/repairs.json" -Raw | ConvertFrom-Json
$data.community.mc.motd="§aSSCG Arcade | 26.3`n这是一个很长的服务器说明，用于检查标题换行、版本信息和启动按钮布局是否完整"
foreach($server in $data.servers){$server.PSObject.Properties.Remove('is_running')}
$data | Add-Member hostedStatus @{server_name=$data.servers[0].name;is_running=$true} -Force
$data.liveRooms=@(@{id='fixture';roomId='123';name='测试玩家';checked=$true;live=$true})
$data.instances[0].running=$true
$data | ConvertTo-Json -Depth 30 | Set-Content "$fixture/fixture.json" -Encoding utf8
Copy-Item "$PSScriptRoot/fixtures/FixtureClient.qml" $fixture
$env:DEERAFT_DESIGN_FIXTURE=$fixture
$env:DEERAFT_REPAIR_PROBE='1'
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$env:DEERAFT_SMOKE_DIR="$desktop/.cache/repair-shots/$stamp"
$env:DEERAFT_QML_DIR="$desktop/app/qml"
$testData="$env:DEERAFT_SMOKE_DIR/app-data"
$env:DEERAFT_SMOKE_ACCOUNT='DeeraftTest'
$process=Start-Process "$desktop/build/Release/DeeraftApp.exe" -ArgumentList @('--dir',('"'+$testData+'"')) -WindowStyle Hidden -PassThru
if(!$process.WaitForExit(20000)){Stop-Process -Id $process.Id;throw 'Repair probe timed out'}
if($process.ExitCode){throw "Repair probe exited $($process.ExitCode)"}
$report=Get-Content "$env:DEERAFT_SMOKE_DIR/native-checks.json" -Raw | ConvertFrom-Json
if(!$report.motdLaunchInsideHero -or $report.runningServerCards -ne 1 -or !$report.viewport.ownerless -or !$report.viewport.hasIcon -or $report.viewport.rootWidth -ne $report.viewport.hostWidth){throw ($report | ConvertTo-Json -Depth 8)}
if($report.calendarVisibleLabels -notcontains '选择日期' -or $report.calendarVisibleLabels -notcontains '取消' -or $report.calendarVisibleLabels -notcontains '确定'){throw 'Calendar translations missing'}
foreach($check in @('directoryCoreRegistered','modToggleRoundTrip','copyWorldPreserved','copyModFilterRespected','copyIndependentDirectory','copyOriginalIntact','exportPortablePaths','nativeInstanceSettingsOpened','selectorFillSurvivesPageTransitions')){if(!$report.$check){throw "Failed repair check: $check"}}
if($report.directoryVersion -ne '1.17.1' -or $report.directoryLoader -ne 'Fabric 0.17.3' -or $report.directoryMods -ne 1 -or $report.directoryWorlds -ne 1){throw 'Directory adapter metadata or resource mismatch'}
if($report.runningButtonText -ne '结束游戏' -or $report.visibleWavyIndicators -lt 1 -or $report.appToolbarCount -ne 0){throw 'Running button, progress or desktop shell regression'}
if(!($report.progressIndicators | Where-Object { [Math]::Abs($_.value-.37) -lt .001 -and [Math]::Abs($_.displayed-.37) -lt .02 -and $_.amplitude -gt .9 })){throw 'Progress value or wave animation did not settle'}
$report | ConvertTo-Json -Depth 8
} finally {
    foreach($name in $environmentNames){[Environment]::SetEnvironmentVariable($name,$previousEnvironment[$name],'Process')}
}
