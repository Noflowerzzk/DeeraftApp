param([switch]$RefreshPackages)
$ErrorActionPreference = 'Stop'
$desktop = Split-Path $PSScriptRoot
$toolchain = Join-Path $desktop '.toolchain'
$cache = Join-Path $desktop '.cache'
New-Item -ItemType Directory -Force $toolchain,$cache | Out-Null
New-Item -ItemType Directory -Force "$cache/tmp" | Out-Null
$env:TEMP="$cache/tmp"
$env:TMP=$env:TEMP
$archive = Join-Path $cache 'msys2-base.tar.xz'
$hash = 'f94db7cc4e7eaaf7a4251ac9f84de4fb22fbafc5147e7a2a292f00809015047f'
if (!(Test-Path (Join-Path $toolchain 'msys64/usr/bin/bash.exe'))) {
    if (!(Test-Path $archive)) {
        Invoke-WebRequest 'https://github.com/msys2/msys2-installer/releases/download/nightly-x86_64/msys2-base-x86_64-latest.tar.xz' -OutFile $archive
    }
    if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) { throw 'MSYS2 archive checksum mismatch. Update the pinned source deliberately.' }
    tar -xf $archive -C $toolchain
    if ($LASTEXITCODE) { throw 'MSYS2 extraction failed' }
}
$env:MSYSTEM = 'UCRT64'
$env:CHERE_INVOKING = '1'
$bash = Join-Path $toolchain 'msys64/usr/bin/bash.exe'
$packages = @('toolchain','cmake','ninja','qt6-base','qt6-declarative','qt6-svg','qt6-imageformats','qt6-5compat','qt6-networkauth','qt6-websockets','extra-cmake-modules','cmark','libarchive','tomlplusplus','zlib','quazip-qt6','qrencode','openssl') | ForEach-Object { 'mingw-w64-ucrt-x86_64-' + $_ }
if ($RefreshPackages -or !(Test-Path (Join-Path $toolchain 'msys64/ucrt64/bin/qmake6.exe'))) {
    & $bash -lc 'pacman -Sy --noconfirm'
    if ($LASTEXITCODE) { throw 'Package index update failed' }
    & $bash -lc ('pacman -S --needed --noconfirm ' + ($packages -join ' '))
    if ($LASTEXITCODE) { throw 'Toolchain dependency installation failed' }
    & $bash -lc 'pacman -Q' | Set-Content (Join-Path $desktop 'scripts/packages.lock.txt') -Encoding utf8
}
Write-Host "Toolchain ready: $toolchain"
