$ErrorActionPreference = "Stop"

# Standalone Windows CLI-only bootstrap. This file intentionally does not load
# or invoke the legacy install.ps1, which may download or launch MoreLogin Client.
$ApiBase = "https://cb-gateway.morelogin.com/app/ver/public/latest"
$InstallDir = if ($env:MORELOGIN_CLI_INSTALL_DIR) { $env:MORELOGIN_CLI_INSTALL_DIR } else { Join-Path $env:USERPROFILE ".morelogin\bin" }
$BinPath = Join-Path $InstallDir "ml-cli.exe"
$Identify = "MoreLogin_AirDrop_window_x64_cli"

if (-not $IsWindows -and $PSVersionTable.PSEdition -eq "Core") {
  throw "This bootstrap supports Windows x64 only. Use install-cli.sh on macOS/Linux."
}

function Get-ReleaseUrl {
  $LookupUrl = "{0}?identify={1}" -f $ApiBase, [Uri]::EscapeDataString($Identify)
  $Response = Invoke-RestMethod -Uri $LookupUrl -Method Get -MaximumRedirection 0
  if ($Response.success -ne $true -or [string]$Response.code -ne "0" -or [string]::IsNullOrWhiteSpace([string]$Response.data)) {
    throw "MoreLogin release API returned an invalid response."
  }
  $Url = [Uri][string]$Response.data
  if ($Url.Scheme -cne "https" -or $Url.IsDefaultPort -eq $false -or $Url.DnsSafeHost -notin @("releases.morelogin.com", "get.morelogin.com")) {
    throw "Refusing untrusted CLI download URL: $Url"
  }
  $FileName = [System.IO.Path]::GetFileName($Url.AbsolutePath)
  $IsExpectedPath = ($Url.DnsSafeHost -eq "releases.morelogin.com" -and $Url.AbsolutePath.StartsWith("/prod/$Identify/", [StringComparison]::Ordinal)) -or
    ($Url.DnsSafeHost -eq "get.morelogin.com" -and $Url.AbsolutePath.StartsWith("/client/prod/", [StringComparison]::Ordinal) -and $Url.AbsolutePath -match "/x64/")
  if (-not $IsExpectedPath -or $FileName -notmatch "(?i)ml-cli(\.exe)?$") {
    throw "Refusing CLI download URL that does not match $Identify`: $Url"
  }
  return $Url.AbsoluteUri
}

function Get-CliVersion([string]$Path) {
  try {
    $Output = (& $Path --version 2>&1 | Out-String).Trim()
    if ($Output -match "(?<version>\d+\.\d+\.\d+(?:\.\d+)?)") { return [Version]$Matches.version }
  } catch { }
  return $null
}

function Get-ReleaseVersion([string]$Url) {
  $Segments = ([Uri]$Url).AbsolutePath.Trim("/").Split("/")
  for ($Index = $Segments.Length - 2; $Index -ge 0; $Index--) {
    $Parsed = $null
    if ([Version]::TryParse($Segments[$Index], [ref]$Parsed)) { return $Parsed }
  }
  return $null
}

function Test-DownloadedCli([string]$Path) {
  $Version = Get-CliVersion $Path
  if (-not $Version) { throw "Downloaded ml-cli could not report a valid version: $Path" }
  try {
    $Signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
    if ($Signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
      throw "Downloaded ml-cli has an invalid Authenticode signature: $Path"
    }
  } catch {
    throw "Downloaded ml-cli signature validation failed: $($_.Exception.Message)"
  }
  return $Version
}

$DownloadUrl = Get-ReleaseUrl
$LatestVersion = Get-ReleaseVersion $DownloadUrl
$Command = Get-Command ml-cli -ErrorAction SilentlyContinue
$Existing = if (Test-Path -LiteralPath $BinPath -PathType Leaf) { $BinPath } elseif ($Command) { $Command.Source } else { $null }
$Latest = $null
if ($Existing) { $Latest = Get-CliVersion $Existing }
if ($Existing -and $Latest) {
  if (-not $LatestVersion -or $Latest -ge $LatestVersion) {
    Write-Host "ml-cli is already installed at $Existing ($Latest); latest is $LatestVersion."
    exit 0
  }
  Write-Host "Installed ml-cli $Latest is older than latest $LatestVersion; updating."
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$Temp = Join-Path $InstallDir "ml-cli.download.exe"
try {
  Invoke-WebRequest -Uri $DownloadUrl -OutFile $Temp -MaximumRedirection 0
  $DownloadedVersion = Test-DownloadedCli $Temp
  if ($LatestVersion -and $DownloadedVersion -ne $LatestVersion) {
    throw "Downloaded ml-cli version $DownloadedVersion does not match release version $LatestVersion."
  }
  Move-Item -Force $Temp $BinPath
} finally {
  Remove-Item -LiteralPath $Temp -Force -ErrorAction SilentlyContinue
}

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (($UserPath -split ";") -notcontains $InstallDir) {
  [Environment]::SetEnvironmentVariable("Path", ($(if ([string]::IsNullOrWhiteSpace($UserPath)) { $InstallDir } else { "$UserPath;$InstallDir" })), "User")
}
Write-Host "Installed ml-cli $DownloadedVersion to $BinPath"
& $BinPath --version
