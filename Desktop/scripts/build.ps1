param([ValidateSet('Debug','Release','RelWithDebInfo')][string]$Configuration='Release',[int]$Jobs=6,[switch]$ConfigureOnly)
$ErrorActionPreference='Stop'
$desktop=Split-Path $PSScriptRoot
New-Item -ItemType Directory -Force "$desktop/.cache/tmp" | Out-Null
$env:TEMP="$desktop/.cache/tmp"
$env:TMP=$env:TEMP
$prefix=Join-Path $desktop '.toolchain/msys64/ucrt64'
if (!(Test-Path "$prefix/bin/cmake.exe")) { & "$PSScriptRoot/bootstrap.ps1" }
$env:PATH="$prefix/bin;"+$env:PATH
$env:JAVA_HOME=(Resolve-Path "$desktop/../Mobile/.toolchain/jdk-17.0.20.1+1").Path
$env:PATH="$env:JAVA_HOME/bin;"+$env:PATH
$build=Join-Path $desktop "build/$Configuration"
& "$prefix/bin/cmake.exe" -S "$desktop/launcher" -B $build -G Ninja "-DCMAKE_BUILD_TYPE=$Configuration" "-DCMAKE_PREFIX_PATH=$prefix" "-DCMAKE_MAKE_PROGRAM=$prefix/bin/ninja.exe" "-DCMAKE_C_COMPILER=$prefix/bin/gcc.exe" "-DCMAKE_CXX_COMPILER=$prefix/bin/g++.exe" '-DBUILD_TESTING=ON' '-DLauncher_BUILD_PLATFORM=DeeraftApp-internal-win64' '-DLauncher_USE_PCH=OFF' '-DLauncher_ENABLE_UPDATER=OFF'
if ($LASTEXITCODE) { throw 'CMake configuration failed' }
if (!$ConfigureOnly) {
    & "$prefix/bin/cmake.exe" --build $build --parallel $Jobs
    if ($LASTEXITCODE) { throw 'Desktop build failed' }
    # UAC helpers do not inherit our process PATH. Their DLLs must be adjacent.
    & "$prefix/bin/windeployqt6.exe" --release --no-translations "$build/prismlauncher_filelink.exe"
    if ($LASTEXITCODE) { throw 'File-link helper deployment failed' }
    & "$prefix/bin/python.exe" "$PSScriptRoot/collect-dlls.py" $prefix $build
    if ($LASTEXITCODE) { throw 'Runtime DLL collection failed' }
}
