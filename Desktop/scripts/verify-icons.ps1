param([Parameter(Mandatory=$true)][string[]]$Executables)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$desktop=Split-Path $PSScriptRoot
$expectedIcon=[Drawing.Icon]::new("$desktop/app/assets/deeraft.ico",32,32)
$expected=$expectedIcon.ToBitmap()
try {
 foreach($file in $Executables){
  $path=(Resolve-Path -LiteralPath $file).Path
  $icon=[Drawing.Icon]::ExtractAssociatedIcon($path);$actual=$icon.ToBitmap()
  try {
   if($actual.Size -ne $expected.Size){throw "Unexpected embedded icon dimensions: $file"}
   for($y=0;$y -lt 32;$y++){for($x=0;$x -lt 32;$x++){if($actual.GetPixel($x,$y).ToArgb() -ne $expected.GetPixel($x,$y).ToArgb()){throw "Embedded icon does not match DeeraftApp branding: $file"}}}
   Write-Output "Verified embedded D icon: $file"
  } finally {$actual.Dispose();$icon.Dispose()}
 }
} finally {$expected.Dispose();$expectedIcon.Dispose()}
