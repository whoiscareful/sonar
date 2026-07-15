[CmdletBinding()]
param(
  [ValidateSet('Installer', 'Hdc')]
  [string]$InstallMode = 'Installer',

  [switch]$SkipBuild,

  [string]$InstallerPath = $env:HEARTTONE_HAP_INSTALLER,

  [string]$HdcPath = $env:HDC_PATH,

  [string]$DevEcoRoot = (Join-Path $env:ProgramFiles 'Huawei\DevEco Studio')
)

$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$hapPath = Join-Path $repoRoot 'hearttone\build\default\outputs\default\hearttone-default-signed.hap'
$hvigor = Join-Path $DevEcoRoot 'tools\hvigor\bin\hvigorw.bat'
$javaHome = Join-Path $DevEcoRoot 'jbr'
$sdkHome = Join-Path $DevEcoRoot 'sdk'

if (-not $SkipBuild) {
  if (-not (Test-Path -LiteralPath $hvigor -PathType Leaf)) {
    throw "Hvigor was not found: $hvigor"
  }

  $env:JAVA_HOME = $javaHome
  $env:DEVECO_SDK_HOME = $sdkHome
  $env:PATH = "$javaHome\bin;$env:PATH"

  Write-Host 'Building the signed HeartTone HAP...'
  Push-Location $repoRoot
  try {
    & $hvigor --mode module `
      -p product=default `
      -p module=hearttone@default `
      -p buildMode=debug `
      assembleHap `
      --no-daemon

    if ($LASTEXITCODE -ne 0) {
      throw "HAP build failed. Hvigor exit code: $LASTEXITCODE"
    }
  }
  finally {
    Pop-Location
  }
}

if (-not (Test-Path -LiteralPath $hapPath -PathType Leaf)) {
  throw "Signed HAP was not found: $hapPath"
}

Write-Host "HAP: $hapPath"

if ($InstallMode -eq 'Installer') {
  if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
    throw 'Set -InstallerPath or HEARTTONE_HAP_INSTALLER to a trusted HAP installer executable.'
  }

  # The installer accepts a .hap through its Windows openFiles/openFile path.
  $quotedHapPath = '"' + $hapPath + '"'
  Start-Process -FilePath $InstallerPath -ArgumentList $quotedHapPath
  Write-Host 'The HAP installer was opened with the signed package.'
  exit 0
}

if ([string]::IsNullOrWhiteSpace($HdcPath) -and
    -not [string]::IsNullOrWhiteSpace($InstallerPath)) {
  $installerRoot = Split-Path -Parent $InstallerPath
  $HdcPath = Join-Path $installerRoot 'data\flutter_assets\assets\windows\hdc.exe'
}
if ([string]::IsNullOrWhiteSpace($HdcPath)) {
  $hdcCommand = Get-Command 'hdc.exe' -ErrorAction SilentlyContinue
  if ($hdcCommand) {
    $HdcPath = $hdcCommand.Source
  }
}
if (-not (Test-Path -LiteralPath $HdcPath -PathType Leaf)) {
  throw 'Set -HdcPath or HDC_PATH to a trusted hdc.exe, or add hdc.exe to PATH.'
}

$targets = @(& $HdcPath list targets 2>&1)
$targetLines = @($targets | ForEach-Object { $_.ToString().Trim() } | Where-Object {
  $_ -and $_ -notmatch '^\[(Empty|Fail)\]'
})
if ($LASTEXITCODE -ne 0 -or $targetLines.Count -eq 0) {
  throw 'No HarmonyOS device was detected. Connect the phone and allow debugging first.'
}

Write-Host "Device: $($targetLines -join ', ')"
Write-Host 'Installing the HAP directly...'
$installOutput = @(& $HdcPath install -r $hapPath 2>&1)
$installOutput | ForEach-Object { Write-Host $_ }
$installText = $installOutput -join "`n"
if ($LASTEXITCODE -ne 0 -or $installText -match '(?im)^\[Fail\]' -or
  $installText -notmatch 'install bundle successfully') {
  throw "HAP install failed. HDC exit code: $LASTEXITCODE"
}

Write-Host 'HeartTone was installed successfully.'
