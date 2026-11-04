[CmdletBinding()]
param(
    [string]$ProjectRoot=(Split-Path -Parent $PSScriptRoot),
    [string]$ScreenshotDirectory='C:\Users\Public\Pictures\Screenshots'
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$outputDirectory=Join-Path $ProjectRoot 'docs\media'
[IO.Directory]::CreateDirectory($outputDirectory)|Out-Null
$cards=@(
    @{File='re8_2026_11_04_01_11_20_780.png';Title='Original Cursor Restored'},
    @{File='re8_2026_11_04_01_12_30_173.png';Title='Reduced Patch Overhead'},
    @{File='re8_2026_11_04_01_19_01_856.png';Title='Improved Display Detection'},
    @{File='re8_2026_11_04_01_19_44_562.png';Title='Refined Settings Menu'}
)
foreach($card in $cards){if(-not(Test-Path -LiteralPath (Join-Path $ScreenshotDirectory $card.File) -PathType Leaf)){throw "Missing original screenshot: $($card.File)"}}
$canvas=[Drawing.Bitmap]::new(2400,1800,[Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics=[Drawing.Graphics]::FromImage($canvas)
$graphics.Clear([Drawing.ColorTranslator]::FromHtml('#0D1014'))
$graphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$owned=[Collections.Generic.List[IDisposable]]::new()
function Font([single]$size,[Drawing.FontStyle]$style=[Drawing.FontStyle]::Regular){
    $value=[Drawing.Font]::new('Segoe UI',$size,$style,[Drawing.GraphicsUnit]::Pixel)
    $owned.Add($value);return $value
}
function Brush([string]$hex){$value=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($hex));$owned.Add($value);return $value}
$titleFont=Font 57 ([Drawing.FontStyle]::Bold)
$subtitleFont=Font 26
$versionFont=Font 32 ([Drawing.FontStyle]::Bold)
$captionFont=Font 34 ([Drawing.FontStyle]::Bold)
$numberFont=Font 25
$white=Brush '#F1F1EE';$muted=Brush '#A9ADB2';$gold=Brush '#C5A568';$panel=Brush '#171B21'
$border=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#30353C'),1);$owned.Add($border)
$rule=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#66573A'),2);$owned.Add($rule)
$format=[Drawing.StringFormat]::new();$owned.Add($format)
$format.LineAlignment=[Drawing.StringAlignment]::Center
$format.FormatFlags=[Drawing.StringFormatFlags]::NoWrap
$format.Trimming=[Drawing.StringTrimming]::None
try {
    $graphics.DrawString('RE8DISPLAY',$titleFont,$white,[Drawing.PointF]::new(44,20))
    $graphics.DrawString('Original cursor. Refined presentation.',$subtitleFont,$muted,[Drawing.PointF]::new(48,90))
    $version='VERSION 2.7.0'
    $versionWidth=$graphics.MeasureString($version,$versionFont).Width
    $graphics.DrawString($version,$versionFont,$gold,[Drawing.PointF]::new(2352-$versionWidth,47))
    $graphics.DrawLine($rule,48,135,2352,135)
    for($index=0;$index -lt $cards.Count;$index++){
        [single]$x=48+($index%2)*1164
        [single]$y=156+[math]::Floor($index/2)*809
        [single]$width=1140;[single]$imageHeight=712.5;[single]$cardHeight=785
        $graphics.FillRectangle($panel,$x,$y,$width,$cardHeight)
        $image=[Drawing.Image]::FromFile((Join-Path $ScreenshotDirectory $cards[$index].File))
        try {
            # Uniform contain: preserve the entire source screenshot and its
            # aspect ratio. No crop, retouching, AI generation or color grading.
            $scale=[math]::Min($width/$image.Width,$imageHeight/$image.Height)
            [single]$w=$image.Width*$scale;[single]$h=$image.Height*$scale
            $destination=[Drawing.RectangleF]::new($x+($width-$w)/2,$y+($imageHeight-$h)/2,$w,$h)
            $source=[Drawing.RectangleF]::new(0,0,$image.Width,$image.Height)
            $graphics.DrawImage($image,$destination,$source,[Drawing.GraphicsUnit]::Pixel)
        } finally {$image.Dispose()}
        $graphics.DrawRectangle($border,$x,$y,$width,$cardHeight)
        $captionY=$y+$imageHeight
        $graphics.DrawString(('{0:00}' -f ($index+1)),$numberFont,$gold,[Drawing.RectangleF]::new($x+24,$captionY,54,72),$format)
        $captionRect=[Drawing.RectangleF]::new($x+88,$captionY,$width-112,72)
        if($graphics.MeasureString($cards[$index].Title,$captionFont).Width -gt $captionRect.Width){throw 'Caption does not fit.'}
        $graphics.DrawString($cards[$index].Title,$captionFont,$white,$captionRect,$format)
    }
    $png=Join-Path $outputDirectory 'RE8Display-2.7.0-overview.png'
    $jpg=Join-Path $outputDirectory 'RE8Display-2.7.0-overview.jpg'
    $canvas.Save($png,[Drawing.Imaging.ImageFormat]::Png)
    $codec=[Drawing.Imaging.ImageCodecInfo]::GetImageEncoders()|Where-Object MimeType -eq 'image/jpeg'
    $parameters=[Drawing.Imaging.EncoderParameters]::new(1)
    try {
        $parameters.Param[0]=[Drawing.Imaging.EncoderParameter]::new([Drawing.Imaging.Encoder]::Quality,[long]94)
        $canvas.Save($jpg,$codec,$parameters)
    } finally {$parameters.Dispose()}
    if((Get-Item -LiteralPath $jpg).Length -gt 9MB){throw 'JPEG exceeds the delivery size budget.'}
    Get-Item -LiteralPath $jpg,$png|Select-Object FullName,Length
} finally {
    foreach($item in $owned){$item.Dispose()}
    $graphics.Dispose();$canvas.Dispose()
}
