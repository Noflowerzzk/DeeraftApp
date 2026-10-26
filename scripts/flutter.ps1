. "$PSScriptRoot\env.ps1"
& "$env:DEERAFT_ROOT\.toolchain\flutter\bin\flutter.bat" @args
exit $LASTEXITCODE
