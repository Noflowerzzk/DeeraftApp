param([string]$InstanceDirectory='F:\Users\张桢锴\Documents\软件\MultiMC\instances')
$ErrorActionPreference='Stop'
$desktop=Split-Path $PSScriptRoot
$environmentNames=@('PATH','QT_PLUGIN_PATH','QML_IMPORT_PATH','TEMP','TMP','DEERAFT_DESIGN_FIXTURE','DEERAFT_REPAIR_PROBE','DEERAFT_SMOKE_DIR','DEERAFT_QML_DIR','DEERAFT_IMPORT_DIRECTORY')
$previous=@{}
foreach($name in $environmentNames){$previous[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
try {
    $env:PATH="$desktop/.toolchain/msys64/ucrt64/bin;"+$env:PATH
    $env:QT_PLUGIN_PATH="$desktop/.toolchain/msys64/ucrt64/share/qt6/plugins"
    $env:QML_IMPORT_PATH="$desktop/.toolchain/msys64/ucrt64/share/qt6/qml"
    $env:TEMP="$desktop/.cache/tmp";$env:TMP=$env:TEMP
    $env:DEERAFT_DESIGN_FIXTURE=$null;$env:DEERAFT_REPAIR_PROBE=$null;$env:DEERAFT_QML_DIR=$null
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
    $output="$desktop/.cache/import-checks/$stamp"
    $env:DEERAFT_SMOKE_DIR=$output
    $env:DEERAFT_IMPORT_DIRECTORY=$InstanceDirectory
    $data="$output/data"
    # Only hash configuration files; never open another launcher's account database.
    $files=@(Get-ChildItem -LiteralPath $InstanceDirectory -Directory | ForEach-Object {
        foreach($name in @('instance.cfg','mmc-pack.json')){$file=Join-Path $_.FullName $name;if(Test-Path -LiteralPath $file){$file}}
    })
    $before=@{};foreach($file in $files){$before[$file]=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}
    for($pass=1;$pass -le 2;$pass++){
        $process=Start-Process "$desktop/build/Release/DeeraftApp.exe" -ArgumentList @('--dir',('"'+$data+'"')) -WindowStyle Hidden -PassThru
        if(!$process.WaitForExit(25000)){Stop-Process -Id $process.Id;throw 'Directory import probe timed out'}
        if($process.ExitCode){throw "Directory import probe exited $($process.ExitCode)"}
        $report=Get-Content "$output/native-checks.json" -Raw | ConvertFrom-Json
        if($report.timedOut -or $report.importedCount -lt 1 -or $report.rowsAfterInvalidSelections -ne $report.importedCount -or !$report.invalidSelectionPreservedRows -or !$report.scanningFinished){throw ($report | ConvertTo-Json -Depth 10)}
        if($report.requestReturnedMs -gt 1000 -or $report.maximumUiGapMs -gt 1000 -or $report.heartbeatCount -lt 3){throw 'Import blocked the UI event loop'}
        if($report.nativeDirectoryObjects -gt 2){throw 'Import eagerly initialized unselected instances'}
        if($report.worldModelCount -ne $report.worldDataCount -or $report.realizedWorldRows -gt 40 -or ($report.worldDataCount -gt 0 -and $report.realizedWorldRows -lt 1)){throw 'World list failed to virtualize correctly'}
        if($report.worldDataCount -gt 100 -and $report.worldContentHeight -le $report.worldViewportHeight){throw 'Large world list is not scrollable'}
        if($report.invalidSelections.Count -lt 5){throw 'Wrong-directory cases were not all exercised'}
        if($pass -eq 2 -and $report.startupRowsBeforeImport -ne $report.importedCount){throw 'Saved instance directories did not load on restart'}
        $errors=Select-String "$data/logs/DeeraftApp-0.log" -Pattern 'Binding loop|ReferenceError|TypeError|recursive rearrange|polish loop'
        if($errors){throw ($errors | Out-String)}
        Copy-Item "$output/native-checks.json" "$output/pass-$pass.json"
        $report | Select-Object importedCount,importElapsedMs,requestReturnedMs,maximumUiGapMs,nativeDirectoryObjects,startupRowsBeforeImport,worldModelCount,realizedWorldRows | ConvertTo-Json
    }
    foreach($file in $files){if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $before[$file]){throw "Original configuration changed: $file"}}
    Write-Output "Original metadata unchanged: $($files.Count) files. Reports: $output"
} finally {
    foreach($name in $environmentNames){[Environment]::SetEnvironmentVariable($name,$previous[$name],'Process')}
}
