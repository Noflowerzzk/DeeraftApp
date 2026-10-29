param([Parameter(Mandatory=$true)][string]$Installer,[Parameter(Mandatory=$true)][string]$PackageDirectory)
$ErrorActionPreference='Stop'
$desktop=Split-Path $PSScriptRoot
$target=[IO.Path]::GetFullPath("$desktop/.cache/installer-checks/$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')/应用安装测试")
$scope=[IO.Path]::GetFullPath("$desktop/.cache/installer-checks/")
if(!$target.StartsWith($scope,[StringComparison]::OrdinalIgnoreCase)){throw 'Installer test escaped its workspace'}
$env:TEMP="$desktop/.cache/tmp";$env:TMP=$env:TEMP
New-Item -ItemType Directory -Force "$target/data" | Out-Null
[IO.File]::WriteAllText("$target/data/preserve.txt",'existing application data')
[IO.File]::WriteAllText("$target/user-note.txt",'user-owned file')
$expected=(Get-FileHash -LiteralPath "$PackageDirectory/DeeraftApp.exe" -Algorithm SHA256).Hash
foreach($pass in 1,2){
 $process=Start-Process -FilePath (Resolve-Path -LiteralPath $Installer) -ArgumentList "/S /NOINTEGRATION /D=$target" -WindowStyle Hidden -PassThru
 if(!$process.WaitForExit(60000)){throw 'Installer exceeded 60 seconds; inspect the isolated process before retrying'}
 if($process.ExitCode -ne 0){throw "Installer exited $($process.ExitCode)"}
 if((Get-FileHash -LiteralPath "$target/DeeraftApp.exe" -Algorithm SHA256).Hash -ne $expected){throw 'Installed binary differs from packaged binary'}
 if([IO.File]::ReadAllText("$target/data/preserve.txt") -ne 'existing application data'){throw 'Installation changed existing application data'}
}
& "$PSScriptRoot/verify-feedback.ps1" -Executable "$target/DeeraftApp.exe" -Packaged
$process=Start-Process -FilePath "$target/Uninstall.exe" -ArgumentList "/S _?=$target" -WindowStyle Hidden -PassThru
if(!$process.WaitForExit(30000)){throw 'Uninstaller exceeded 30 seconds'}
if($process.ExitCode -ne 0 -or (Test-Path -LiteralPath "$target/DeeraftApp.exe")){throw 'Uninstall did not remove the application binary'}
if([IO.File]::ReadAllText("$target/data/preserve.txt") -ne 'existing application data' -or [IO.File]::ReadAllText("$target/user-note.txt") -ne 'user-owned file'){throw 'Uninstall removed user-owned content'}
Write-Output "Install, overwrite update, packaged UI and uninstall passed; user data preserved: $target"
