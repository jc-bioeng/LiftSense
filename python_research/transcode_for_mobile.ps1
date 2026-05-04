$ffmpeg = "C:\Users\jjcor\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg.Essentials_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1-essentials_build\bin\ffmpeg.exe"
$outDir = "$PSScriptRoot\mobile_videos"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$videos = @("frontal", "lateral", "posterior", "carac")

foreach ($v in $videos) {
    $input = "$PSScriptRoot\$v.mp4"
    $output = "$outDir\$v.mp4"
    Write-Host "Transcoding $v.mp4 ..."
    & $ffmpeg -y -i $input `
      -vcodec libx264 -profile:v baseline -level 3.1 `
      -b:v 2000k -maxrate 2500k -bufsize 5000k `
      -vf "scale=720:-2" `
      -r 30 `
      -acodec aac -b:a 128k `
      -movflags +faststart `
      $output
    Write-Host "Done: $output"
}

Write-Host "All videos transcoded to $outDir"
