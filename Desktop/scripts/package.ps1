param([string]$Configuration='Release')
$ErrorActionPreference='Stop'
$desktop=Split-Path $PSScriptRoot
$prefix=Join-Path $desktop '.toolchain/msys64/ucrt64'
$env:PATH="$prefix/bin;"+$env:PATH
$env:TEMP="$desktop/.cache/tmp"
$env:TMP=$env:TEMP
$build=Join-Path $desktop "build/$Configuration"
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$output=Join-Path $desktop "dist/DeeraftApp-win64-$stamp"
New-Item -ItemType Directory -Force $output,"$output/jars","$output/licenses" | Out-Null
Copy-Item "$build/DeeraftApp.exe" $output
Copy-Item "$build/jars/*.jar" "$output/jars"
if(Test-Path "$build/prismlauncher_filelink.exe"){Copy-Item "$build/prismlauncher_filelink.exe" $output}
& "$prefix/bin/windeployqt6.exe" --release --no-translations --compiler-runtime --qmldir "$desktop/app/qml" "$output/DeeraftApp.exe"
if($LASTEXITCODE){throw 'Qt deployment failed'}
& "$prefix/bin/python.exe" "$PSScriptRoot/collect-dlls.py" $prefix $output
if($LASTEXITCODE){throw 'DLL dependency collection failed'}
Copy-Item "$desktop/launcher/LICENSE" "$output/licenses/Prism-GPL-3.0.txt"
Copy-Item "$desktop/launcher/COPYING.md" "$output/licenses/" -ErrorAction SilentlyContinue
Copy-Item "$desktop/app/webview/vendor/LICENSE" "$output/licenses/webview-MIT.txt"
Copy-Item "$desktop/app/webview/vendor/WebView2-LICENSE.txt" "$output/licenses/"
Copy-Item "$desktop/../Mobile/assets/fonts/OFL.txt" "$output/licenses/NotoSansSC-OFL.txt"
Copy-Item "$desktop/launcher/UPSTREAM.md","$desktop/README.md" $output
Copy-Item "$desktop/scripts/packages.lock.txt" "$output/licenses/toolchain-packages.txt"
if(Test-Path "$prefix/share/licenses"){Copy-Item "$prefix/share/licenses" "$output/licenses/dependencies" -Recurse}
$qtConf="[Paths]`nPrefix=.`nPlugins=.`nQmlImports=qml`n"
Set-Content "$output/qt.conf" $qtConf -Encoding utf8
$zip="$output.zip"
Compress-Archive -Path "$output/*" -DestinationPath $zip -CompressionLevel Optimal
Get-FileHash $zip -Algorithm SHA256 | Format-List
Write-Host "Portable package: $zip"
