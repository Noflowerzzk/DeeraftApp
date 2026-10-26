# Dot-source before running Flutter/Gradle. All new tools and caches stay here.
$DeeraftRoot = Split-Path $PSScriptRoot -Parent
$env:DEERAFT_ROOT = $DeeraftRoot
$env:TEMP = Join-Path $DeeraftRoot '.cache\tmp'
$env:TMP = $env:TEMP
$env:PUB_CACHE = Join-Path $DeeraftRoot '.cache\pub'
$env:GRADLE_USER_HOME = Join-Path $DeeraftRoot '.cache\gradle'
$env:ANDROID_USER_HOME = Join-Path $DeeraftRoot '.cache\android'
$env:ANDROID_EMULATOR_HOME = Join-Path $DeeraftRoot '.cache\android'
$env:ANDROID_AVD_HOME = Join-Path $DeeraftRoot '.cache\android\avd'
$env:ANDROID_HOME = Join-Path $DeeraftRoot '.toolchain\android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:XDG_CONFIG_HOME = Join-Path $DeeraftRoot '.cache\config'
$env:XDG_CACHE_HOME = Join-Path $DeeraftRoot '.cache'
$env:APPDATA = Join-Path $DeeraftRoot '.cache\appdata'
$env:LOCALAPPDATA = Join-Path $DeeraftRoot '.cache\localappdata'
$env:NPM_CONFIG_CACHE = Join-Path $DeeraftRoot '.cache\npm'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:CI = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:PYTHONPYCACHEPREFIX = Join-Path $DeeraftRoot '.cache\pycache'
$env:PIP_CACHE_DIR = Join-Path $DeeraftRoot '.cache\pip'
$jdk = Join-Path $DeeraftRoot '.toolchain\jdk-17.0.20.1+1'
if (Test-Path $jdk) { $env:JAVA_HOME = $jdk }
# Java's user.home controls debug.keystore and some third-party build caches.
$env:JAVA_TOOL_OPTIONS = "`"-Duser.home=$($DeeraftRoot.Replace('\','/'))/.cache/java`" `"-Djava.io.tmpdir=$($env:TEMP.Replace('\','/'))`" -Dfile.encoding=UTF-8"
$env:Path = "$DeeraftRoot\.toolchain\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:Path"
@($env:TEMP,$env:PUB_CACHE,$env:GRADLE_USER_HOME,$env:ANDROID_USER_HOME,$env:XDG_CONFIG_HOME,(Join-Path $DeeraftRoot '.cache\java')) | ForEach-Object { New-Item -ItemType Directory -Force $_ | Out-Null }
