param([Parameter(Mandatory=$true)][string]$PackageDirectory,[string]$Version='0.6.1')
$ErrorActionPreference='Stop'
$desktop=Split-Path $PSScriptRoot
$payload=(Resolve-Path -LiteralPath $PackageDirectory).Path
if(!(Test-Path -LiteralPath "$payload/DeeraftApp.exe")){throw 'Select a complete packaged application directory'}
$installer="$desktop/dist/DeeraftApp-$Version-windows-x64-setup.exe"
$script="$desktop/.cache/installer-$Version.nsi"
$template=@'
Unicode true
!define MUI_ICON "@ICON@"
!define MUI_UNICON "@ICON@"
!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
Name "DeeraftApp"
Icon "@ICON@"
UninstallIcon "@ICON@"
VIProductVersion "@VERSION@.0"
VIAddVersionKey "ProductName" "DeeraftApp"
VIAddVersionKey "FileDescription" "DeeraftApp Installer"
VIAddVersionKey "FileVersion" "@VERSION@"
VIAddVersionKey "LegalCopyright" "DeeraftApp contributors"
OutFile "@OUTPUT@"
InstallDir "$LOCALAPPDATA\Programs\DeeraftApp"
InstallDirRegKey HKCU "Software\DeeraftApp" "InstallDirectory"
RequestExecutionLevel user
SetCompressor /SOLID lzma
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!define MUI_DIRECTORYPAGE_TEXT_TOP "选择安装位置。已有便携版请选择原文件夹，data 中的数据会保留。"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\DeeraftApp.exe"
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
Var NoIntegration
Var UpdateRequested
Var UpdateDataDirectory
Function .onInit
 ${GetParameters} $0
 ${GetOptions} $0 "/NOINTEGRATION" $NoIntegration
 IfErrors 0 +2
 StrCpy $NoIntegration "false"
 StrCpy $UpdateRequested "false"
 StrCpy $1 ""
 ${GetOptions} $0 "/WAITPID=" $1
 ${If} $1 != ""
  StrCpy $UpdateRequested "true"
  System::Call 'kernel32::OpenProcess(i 0x100000, i 0, i r1) p.r2'
  ${If} $2 != 0
   System::Call 'kernel32::WaitForSingleObject(p r2, i 60000) i.r3'
   System::Call 'kernel32::CloseHandle(p r2)'
   ${If} $3 != 0
    SetErrorLevel 2
    Abort
   ${EndIf}
  ${EndIf}
 ${EndIf}
 StrCpy $UpdateDataDirectory ""
 ${GetOptions} $0 "/DATADIR=" $UpdateDataDirectory
FunctionEnd
Function .onInstSuccess
 ${If} $UpdateRequested == "true"
 ${AndIf} $NoIntegration == "false"
  ${If} $UpdateDataDirectory != ""
   Exec '"$INSTDIR\DeeraftApp.exe" --dir "$UpdateDataDirectory"'
  ${Else}
   Exec '"$INSTDIR\DeeraftApp.exe"'
  ${EndIf}
 ${EndIf}
FunctionEnd
Section "DeeraftApp"
 SetOutPath "$INSTDIR"
 SetOverwrite on
 ClearErrors
 File /r "@PAYLOAD@\*"
 ${If} ${Errors}
  SetErrorLevel 3
  Abort
 ${EndIf}
 WriteUninstaller "$INSTDIR\Uninstall.exe"
 ${If} $NoIntegration == "false"
  CreateDirectory "$SMPROGRAMS\DeeraftApp"
  CreateShortcut "$SMPROGRAMS\DeeraftApp\DeeraftApp.lnk" "$INSTDIR\DeeraftApp.exe"
  CreateShortcut "$DESKTOP\DeeraftApp.lnk" "$INSTDIR\DeeraftApp.exe"
  WriteRegStr HKCU "Software\DeeraftApp" "InstallDirectory" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeeraftApp" "DisplayName" "DeeraftApp"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeeraftApp" "DisplayVersion" "@VERSION@"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeeraftApp" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeeraftApp" "DisplayIcon" "$INSTDIR\DeeraftApp.exe"
 ${EndIf}
SectionEnd
Section "Uninstall"
@REMOVE@
 Delete "$INSTDIR\Uninstall.exe"
 RMDir "$INSTDIR"
 ReadRegStr $0 HKCU "Software\DeeraftApp" "InstallDirectory"
 ${If} $0 == $INSTDIR
  Delete "$DESKTOP\DeeraftApp.lnk"
  Delete "$SMPROGRAMS\DeeraftApp\DeeraftApp.lnk"
  RMDir "$SMPROGRAMS\DeeraftApp"
  DeleteRegKey HKCU "Software\DeeraftApp"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\DeeraftApp"
 ${EndIf}
SectionEnd
'@
$remove=@(Get-ChildItem -LiteralPath $payload -Recurse -File | ForEach-Object {
 $relative=$_.FullName.Substring($payload.Length+1)
 if($relative.StartsWith('data\',[StringComparison]::OrdinalIgnoreCase)){throw 'The installer payload must not include user data'}
 ' Delete "$INSTDIR\'+$relative+'"'
})
$remove+=@(Get-ChildItem -LiteralPath $payload -Recurse -Directory | Sort-Object {$_.FullName.Length} -Descending | ForEach-Object {' RMDir "$INSTDIR\'+$_.FullName.Substring($payload.Length+1)+'"'})
$template=$template.Replace('@ICON@',"$desktop/app/assets/deeraft.ico").Replace('@OUTPUT@',$installer).Replace('@PAYLOAD@',$payload).Replace('@VERSION@',$Version).Replace('@REMOVE@',($remove -join "`n"))
[IO.File]::WriteAllText($script,$template,[Text.UTF8Encoding]::new($true))
$env:NSISDIR="$desktop/.toolchain/msys64/ucrt64/share/nsis"
& "$desktop/.toolchain/msys64/ucrt64/bin/makensis.exe" /V2 $script
if($LASTEXITCODE){throw 'Installer compilation failed'}
Get-FileHash -LiteralPath $installer -Algorithm SHA256
Write-Output "Installer: $installer"
