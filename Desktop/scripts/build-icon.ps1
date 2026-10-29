# Reproduce the approved design demo's D mark, without generated illustrations.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$assetRoot=Join-Path (Split-Path $PSScriptRoot) 'app/assets'
$images=@()
foreach($edge in @(16,20,24,32,48,64,128,256)) {
 $bitmap=[Drawing.Bitmap]::new($edge,$edge)
 $g=[Drawing.Graphics]::FromImage($bitmap);$g.SmoothingMode='AntiAlias'
 $g.ScaleTransform($edge/24.0,$edge/24.0)
 $background=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#056b5b'))
 $foreground=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#cef4e8'))
 $shape=[Drawing.Drawing2D.GraphicsPath]::new()
 $shape.AddArc(1,1,8,8,180,90);$shape.AddArc(15,1,8,8,270,90);$shape.AddArc(15,15,8,8,0,90);$shape.AddArc(1,15,8,8,90,90);$shape.CloseFigure();$g.FillPath($background,$shape)
 $letter=[Drawing.Drawing2D.GraphicsPath]::new([Drawing.Drawing2D.FillMode]::Alternate)
 $letter.StartFigure();$letter.AddLine(7,5,12,5);$letter.AddBezier(12,5,22,5,22,19,12,19);$letter.AddLine(12,19,7,19);$letter.CloseFigure()
 $letter.StartFigure();$letter.AddLine(11,9,12,9);$letter.AddBezier(12,9,16,9,16,15,12,15);$letter.AddLine(12,15,11,15);$letter.CloseFigure();$g.FillPath($foreground,$letter)
 if($edge -eq 256){$bitmap.Save((Join-Path $assetRoot 'deeraft.png'),[Drawing.Imaging.ImageFormat]::Png)}
 $stream=[IO.MemoryStream]::new();$bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png);$images+=,@{Edge=$edge;Bytes=$stream.ToArray()}
 $g.Dispose();$bitmap.Dispose();$stream.Dispose();$shape.Dispose();$letter.Dispose();$background.Dispose();$foreground.Dispose()
}
$ico=[IO.File]::Create((Join-Path $assetRoot 'deeraft.ico'));$writer=[IO.BinaryWriter]::new($ico)
$writer.Write([uint16]0);$writer.Write([uint16]1);$writer.Write([uint16]$images.Count)
$offset=6+16*$images.Count
foreach($image in $images){$size=if($image.Edge -eq 256){0}else{$image.Edge};$writer.Write([byte]$size);$writer.Write([byte]$size);$writer.Write([byte]0);$writer.Write([byte]0);$writer.Write([uint16]1);$writer.Write([uint16]32);$writer.Write([uint32]$image.Bytes.Length);$writer.Write([uint32]$offset);$offset+=$image.Bytes.Length}
foreach($image in $images){$writer.Write([byte[]]$image.Bytes)}
$writer.Dispose();$ico.Dispose()
