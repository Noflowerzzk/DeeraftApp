param([string]$Configuration='Release',[Parameter(ValueFromRemainingArguments=$true)][string[]]$AppArguments)
$ErrorActionPreference='Stop'
$desktop=Split-Path $PSScriptRoot
$prefix=Join-Path $desktop '.toolchain/msys64/ucrt64'
$env:PATH="$prefix/bin;"+$env:PATH
$env:QML_IMPORT_PATH="$prefix/share/qt6/qml"
$env:QT_PLUGIN_PATH="$prefix/share/qt6/plugins"
$env:TEMP="$desktop/.cache/tmp"
$env:TMP=$env:TEMP
$binary=Join-Path $desktop "build/$Configuration/DeeraftApp.exe"
if(!(Test-Path $binary)){throw 'Build first: ./Desktop/scripts/build.ps1'}
& $binary @AppArguments
if($LASTEXITCODE){throw "DeeraftApp exited with code $LASTEXITCODE"}
