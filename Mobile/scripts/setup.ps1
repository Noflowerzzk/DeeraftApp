param([switch]$WithEmulator)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/env.ps1"
Set-Location $env:DEERAFT_ROOT
$lock=Get-Content "$PSScriptRoot/toolchain.json" -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force .toolchain,work | Out-Null
function Get-VerifiedArchive($Package,[string]$Name) {
    $target=Join-Path $env:DEERAFT_ROOT ".toolchain/$Name.zip"
    if(!(Test-Path $target) -or (Get-FileHash $target).Hash.ToLower() -ne $Package.sha256) {
        & curl.exe -sSL --fail --retry 2 --output "$target.partial" $Package.url
        if($LASTEXITCODE){throw "Download failed: $Name"}
        if((Get-FileHash "$target.partial").Hash.ToLower() -ne $Package.sha256){throw "Checksum mismatch: $Name"}
        Move-Item -LiteralPath "$target.partial" -Destination $target -Force
    }
    return $target
}
if(!(Test-Path '.toolchain/flutter/bin/flutter.bat')) {
    Expand-Archive (Get-VerifiedArchive $lock.flutter 'flutter') .toolchain -Force
}
if(!(Test-Path ".toolchain/$($lock.jdk.directory)/bin/java.exe")) {
    Expand-Archive (Get-VerifiedArchive $lock.jdk 'jdk') .toolchain -Force
}
if(!(Test-Path '.toolchain/android-sdk/cmdline-tools/latest/bin/sdkmanager.bat')) {
    Expand-Archive (Get-VerifiedArchive $lock.android 'android-cli') .toolchain/android-cli -Force
    New-Item -ItemType Directory -Force .toolchain/android-sdk/cmdline-tools/latest | Out-Null
    Copy-Item .toolchain/android-cli/cmdline-tools/* .toolchain/android-sdk/cmdline-tools/latest -Recurse -Force
}
. "$PSScriptRoot/env.ps1"
& flutter.bat config --jdk-dir "$env:JAVA_HOME" --android-sdk "$env:ANDROID_HOME"
if($LASTEXITCODE){throw 'Flutter configuration failed'}
# The requested Android build uses the SDK license. Print the license text in
# the setup log; the developer can also run sdkmanager --licenses interactively.
1..20 | ForEach-Object {'y'} | & sdkmanager.bat --sdk_root=$env:ANDROID_HOME --licenses
if($LASTEXITCODE){throw 'SDK license setup failed'}
& sdkmanager.bat --sdk_root=$env:ANDROID_HOME @($lock.android.packages)
if($LASTEXITCODE){throw 'SDK installation failed'}
if($WithEmulator) {
    & sdkmanager.bat --sdk_root=$env:ANDROID_HOME 'emulator' 'system-images;android-36;google_apis;x86_64'
    if($LASTEXITCODE){throw 'Emulator installation failed'}
}
& flutter.bat pub get
if($LASTEXITCODE){throw 'pub get failed'}
& flutter.bat doctor -v
