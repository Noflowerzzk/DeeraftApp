. "$PSScriptRoot\env.ps1"
Push-Location $env:DEERAFT_ROOT
try {
    & "$env:DEERAFT_ROOT\.toolchain\flutter\bin\flutter.bat" @args
    $DeeraftFlutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $DeeraftFlutterExitCode
