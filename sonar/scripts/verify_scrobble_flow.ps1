param(
  [Parameter(Mandatory = $true)]
  [string]$LogPath
)

if (-not (Test-Path -Path $LogPath)) {
  Write-Error "Log file not found: $LogPath"
  exit 1
}

$lines = Get-Content -Path $LogPath

$submissionLines = $lines | Where-Object { $_ -match "scrobble submission id=" }
$nowPlayingLines = $lines | Where-Object { $_ -match "scrobble nowPlaying id=" }
$skipLines = $lines | Where-Object { $_ -match "skip submission reason=" }
$errorLines = $lines | Where-Object {
  $_ -match "submission failed \[" -or
  $_ -match "nowPlaying failed \[" -or
  $_ -match "fallback standard call"
}

Write-Host "==== SonicAPI Scrobble Verification ===="
Write-Host "Log file:" $LogPath
Write-Host "Now Playing count:" $nowPlayingLines.Count
Write-Host "Submission count:" $submissionLines.Count
Write-Host "Threshold skip count:" $skipLines.Count
Write-Host "Error count:" $errorLines.Count
Write-Host ""

Write-Host "---- Last 10 Now Playing ----"
$nowPlayingLines | Select-Object -Last 10 | ForEach-Object { Write-Host $_ }
Write-Host ""

Write-Host "---- Last 10 Submission ----"
$submissionLines | Select-Object -Last 10 | ForEach-Object { Write-Host $_ }
Write-Host ""

Write-Host "---- Last 10 Skipped (Threshold) ----"
$skipLines | Select-Object -Last 10 | ForEach-Object { Write-Host $_ }
Write-Host ""

if ($errorLines.Count -gt 0) {
  Write-Host "---- Last 20 Errors ----"
  $errorLines | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
  Write-Host ""
}

Write-Host "==== Expected checks ===="
Write-Host "1) submission log time should look like current epoch ms"
Write-Host "2) nowPlaying should include positionSec when progress > 0"
Write-Host "3) short/low-progress tracks should appear in skip submission logs"
Write-Host "4) no repeated auth/network/server errors in normal playback"
