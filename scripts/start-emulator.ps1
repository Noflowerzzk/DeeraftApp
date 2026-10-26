$ErrorActionPreference='Stop'
. "$PSScriptRoot/env.ps1"
$avdPath=Join-Path $env:ANDROID_AVD_HOME 'deeraft-api36'
New-Item -ItemType Directory -Force $avdPath | Out-Null
if(-not (Test-Path "$env:ANDROID_HOME/system-images/android-36/google_apis/x86_64/system.img")) {
    throw 'Install emulator and system-images;android-36;google_apis;x86_64 with sdkmanager first.'
}
@"
avd.ini.encoding=UTF-8
path=$avdPath
target=android-36
"@ | Set-Content "$env:ANDROID_AVD_HOME/deeraft-api36.ini" -Encoding utf8
@"
AvdId=deeraft-api36
avd.ini.displayname=Deeraft API 36
avd.ini.encoding=UTF-8
abi.type=x86_64
hw.cpu.arch=x86_64
hw.cpu.ncore=4
hw.ramSize=2048
hw.gpu.enabled=yes
hw.gpu.mode=swiftshader_indirect
hw.lcd.width=1080
hw.lcd.height=2340
hw.lcd.density=440
hw.keyboard=yes
hw.mainKeys=no
hw.sensors.orientation=yes
disk.dataPartition.size=4G
image.sysdir.1=system-images/android-36/google_apis/x86_64/
tag.id=google_apis
tag.display=Google APIs
PlayStore.enabled=false
showDeviceFrame=no
fastboot.forceColdBoot=yes
"@ | Set-Content "$avdPath/config.ini" -Encoding utf8
$emulatorProcess=Start-Process -FilePath "$env:ANDROID_HOME/emulator/emulator.exe" -ArgumentList @('-avd','deeraft-api36','-no-window','-no-audio','-no-boot-anim','-no-snapshot','-gpu','swiftshader_indirect','-camera-back','none','-camera-front','none') -WindowStyle Hidden -RedirectStandardOutput "$env:DEERAFT_ROOT/work/emulator.log" -RedirectStandardError "$env:DEERAFT_ROOT/work/emulator-error.log" -PassThru
Write-Host "Deeraft emulator PID: $($emulatorProcess.Id)"
