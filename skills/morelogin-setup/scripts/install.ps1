$ErrorActionPreference = "Stop"

$ApiBase = "https://cb-gateway.morelogin.com/app/ver/public/latest"
$ApiHost = "cb-gateway.morelogin.com"
$ReleaseHost = "releases.morelogin.com"
$InstallHost = "get.morelogin.com"
$InstallDir = if ($env:MORELOGIN_CLI_INSTALL_DIR) { $env:MORELOGIN_CLI_INSTALL_DIR } else { Join-Path $env:USERPROFILE ".morelogin\bin" }
$BinPath = Join-Path $InstallDir "ml-cli.exe"
$SkipClient = $env:MORELOGIN_SKIP_CLIENT -in @("1", "true", "TRUE", "True")

function Get-PlatformIdentify {
  if ($PSVersionTable.PSEdition -eq "Core" -and -not $IsWindows) {
    throw "This installer supports Windows only for ml-cli.exe."
  }

  $arch = if ($env:PROCESSOR_ARCHITECTURE) { $env:PROCESSOR_ARCHITECTURE.ToLowerInvariant() } else { [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLowerInvariant() }
  switch ($arch) {
    "x64" { return "MoreLogin_AirDrop_window_x64_cli" }
    "amd64" { return "MoreLogin_AirDrop_window_x64_cli" }
    default { throw "Unsupported CPU architecture: $arch" }
  }
}

function Assert-TrustedApiUrl {
  $Expected = "https://$ApiHost/app/ver/public/latest"
  if ($ApiBase -cne $Expected) {
    throw "Refusing untrusted MoreLogin release API URL: $ApiBase"
  }
}

function Assert-TrustedDownloadUrl {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$ExpectedIdentify
  )

  try {
    $Uri = [Uri]$Url
  } catch {
    throw "Refusing invalid download URL: $Url"
  }

  if (-not $Uri.IsAbsoluteUri -or $Uri.Scheme -cne "https") {
    throw "Refusing non-HTTPS download URL: $Url"
  }
  if (-not $Uri.IsDefaultPort -or -not [string]::IsNullOrEmpty($Uri.UserInfo)) {
    throw "Refusing download URL with a custom port or user information: $Url"
  }

  $FileName = [System.IO.Path]::GetFileName($Uri.AbsolutePath)
  $HostName = $Uri.DnsSafeHost.ToLowerInvariant()
  if ($HostName -ceq $ReleaseHost) {
    $Platform = $ExpectedIdentify.Substring("MoreLogin_AirDrop_".Length)
    $IsCli = $Platform.EndsWith("_cli", [StringComparison]::Ordinal)
    if ($IsCli) {
      $ExpectedPrefix = "/prod/$ExpectedIdentify/"
      if (-not $Uri.AbsolutePath.StartsWith($ExpectedPrefix, [StringComparison]::Ordinal) -or
          -not $FileName.Contains($ExpectedIdentify)) {
        throw "Refusing CLI release URL that does not match $ExpectedIdentify`: $Url"
      }
    } else {
      $PlatformParts = $Platform.Split("_")
      $ExpectedOs = $PlatformParts[0]
      $ExpectedArch = $PlatformParts[$PlatformParts.Length - 1]
      $PlatformPaths = switch ($ExpectedOs) {
        "darwin" { @("/prod/client/mac/$ExpectedArch/", "/prod/client/darwin/$ExpectedArch/") }
        "window" { @("/prod/client/win/$ExpectedArch/", "/prod/client/window/$ExpectedArch/", "/prod/client/windows/$ExpectedArch/") }
        "linux" { @("/prod/client/linux/$ExpectedArch/") }
        default { throw "Refusing Client release URL for unsupported platform '$ExpectedOs': $Url" }
      }
      if (-not ($PlatformPaths | Where-Object { $Uri.AbsolutePath.StartsWith($_, [StringComparison]::Ordinal) })) {
        throw "Refusing Client release URL for the wrong platform: $Url"
      }
      $ExpectedFileMarker = "MoreLogin_{0}_{1}_" -f $ExpectedOs, $ExpectedArch
      if ($FileName.IndexOf($ExpectedFileMarker, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Refusing unexpected MoreLogin Client release filename: $Url"
      }
      $AllowedExtension = switch ($ExpectedOs) {
        "darwin" { $FileName.EndsWith(".dmg", [StringComparison]::OrdinalIgnoreCase) -or $FileName.EndsWith(".pkg", [StringComparison]::OrdinalIgnoreCase) }
        "window" { $FileName.EndsWith(".exe", [StringComparison]::OrdinalIgnoreCase) }
        "linux" { $FileName -match "\.(deb|rpm|AppImage|appimage|tar\.gz|tgz|zip)$" }
      }
      if (-not $AllowedExtension) {
        throw "Refusing unexpected MoreLogin Client release package type: $Url"
      }
    }
  } elseif ($HostName -ceq $InstallHost) {
    if (-not $Uri.AbsolutePath.StartsWith("/client/prod/", [StringComparison]::Ordinal)) {
      throw "Refusing $InstallHost URL outside /client/prod/`: $Url"
    }
    $Platform = $ExpectedIdentify.Substring("MoreLogin_AirDrop_".Length)
    $IsCli = $Platform.EndsWith("_cli", [StringComparison]::Ordinal)
    if ($IsCli) {
      $Platform = $Platform.Substring(0, $Platform.Length - "_cli".Length)
    }
    $PlatformParts = $Platform.Split("_")
    $ExpectedOs = $PlatformParts[0]
    $ExpectedArch = $PlatformParts[$PlatformParts.Length - 1]

    if ($IsCli) {
      $ExpectedFileName = if ($ExpectedOs -ceq "window") { "ml-cli.exe" } else { "ml-cli" }
      if ($FileName -cne $ExpectedFileName -or -not $Uri.AbsolutePath.Contains("/$ExpectedArch/")) {
        throw "Refusing $InstallHost URL that does not match $ExpectedIdentify`: $Url"
      }
    } else {
      $PlatformPaths = switch ($ExpectedOs) {
        "darwin" { @("/mac/$ExpectedArch/", "/darwin/$ExpectedArch/") }
        "window" { @("/win/$ExpectedArch/", "/window/$ExpectedArch/", "/windows/$ExpectedArch/") }
        "linux" { @("/linux/$ExpectedArch/") }
        default { throw "Refusing Client URL for unsupported platform '$ExpectedOs': $Url" }
      }
      if (-not ($PlatformPaths | Where-Object { $Uri.AbsolutePath.Contains($_) })) {
        throw "Refusing Client URL for the wrong platform: $Url"
      }
      if ($FileName.IndexOf("MoreLogin", [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw "Refusing unexpected MoreLogin Client filename: $Url"
      }
      $AllowedExtension = switch ($ExpectedOs) {
        "darwin" { $FileName.EndsWith(".dmg", [StringComparison]::OrdinalIgnoreCase) -or $FileName.EndsWith(".pkg", [StringComparison]::OrdinalIgnoreCase) }
        "window" { $FileName.EndsWith(".exe", [StringComparison]::OrdinalIgnoreCase) }
        "linux" { $FileName -match "\.(deb|rpm|AppImage|appimage|tar\.gz|tgz|zip)$" }
      }
      if (-not $AllowedExtension) {
        throw "Refusing unexpected MoreLogin Client package type: $Url"
      }
    }
  } else {
    throw "Refusing download URL from untrusted host '$($Uri.DnsSafeHost)': $Url"
  }
}

function Get-ReleaseResponse {
  param([Parameter(Mandatory = $true)][string]$Identify)

  $LookupUrl = "{0}?identify={1}" -f $ApiBase, [Uri]::EscapeDataString($Identify)
  Write-Host "MoreLogin release API request:"
  Write-Host "  identify: $Identify"
  Write-Host "  url: $LookupUrl"
  $Response = Invoke-RestMethod -Uri $LookupUrl -Method Get -MaximumRedirection 0
  Write-Host "MoreLogin release API response:"
  Write-Host ("  " + ($Response | ConvertTo-Json -Depth 10 -Compress))
  if ($Response.success -ne $true -or [string]$Response.code -ne "0" -or [string]::IsNullOrWhiteSpace($Response.data)) {
    throw ("Could not resolve trusted download URL. Raw response: " + ($Response | ConvertTo-Json -Depth 10))
  }
  $DownloadUrl = [string]$Response.data
  Assert-TrustedDownloadUrl -Url $DownloadUrl -ExpectedIdentify $Identify
  Write-Host "Resolved latest download URL:"
  Write-Host "  $DownloadUrl"
  return $DownloadUrl
}

function Get-VersionFromDownloadUrl {
  param([Parameter(Mandatory = $true)][string]$Url)

  $Segments = ([Uri]$Url).AbsolutePath.Trim("/").Split("/")
  for ($Index = $Segments.Length - 2; $Index -ge 0; $Index--) {
    $ParsedVersion = $null
    if ([Version]::TryParse($Segments[$Index], [ref]$ParsedVersion)) {
      return $ParsedVersion
    }
  }
  return $null
}

function Get-InstalledCliVersion {
  param([Parameter(Mandatory = $true)][string]$Path)

  try {
    $VersionOutput = (& $Path --version 2>&1 | Out-String).Trim()
    if ($VersionOutput -match "(?<version>\d+\.\d+\.\d+(?:\.\d+)?)") {
      return [Version]$Matches.version
    }
  } catch {
    return $null
  }
  return $null
}

function Test-MoreLoginClientInstalled {
  $paths = @(
    (Join-Path $env:LOCALAPPDATA "Programs\MoreLogin"),
    (Join-Path $env:ProgramFiles "MoreLogin")
  )
  if (${env:ProgramFiles(x86)}) {
    $paths += (Join-Path ${env:ProgramFiles(x86)} "MoreLogin")
  }
  foreach ($path in $paths) {
    if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Container)) {
      continue
    }
    $Executable = Get-ChildItem -LiteralPath $path -Filter "MoreLogin.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Executable) {
      Write-Host "Found MoreLogin Client executable: $($Executable.FullName)"
      return $true
    }
  }
  return $false
}

function Save-MoreLoginClientInstaller {
  if (Test-MoreLoginClientInstalled) {
    Write-Host "MoreLogin Client appears to be installed. Skipping Client installer download."
    return
  }

  $ClientIdentify = "MoreLogin_AirDrop_window_x64"
  $DownloadUrl = Get-ReleaseResponse -Identify $ClientIdentify
  $DownloadDir = if ($env:MORELOGIN_DOWNLOAD_DIR) { $env:MORELOGIN_DOWNLOAD_DIR } else { Join-Path $env:USERPROFILE "Downloads" }
  New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
  $FileName = Split-Path -Leaf ([Uri]$DownloadUrl).AbsolutePath
  $ClientPath = Join-Path $DownloadDir $FileName
  if (Test-Path $ClientPath) {
    $Base = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $Ext = [System.IO.Path]::GetExtension($FileName)
    $ClientPath = Join-Path $DownloadDir "$Base-$(Get-Date -Format yyyyMMddHHmmss)$Ext"
  }

  Write-Host "Downloading MoreLogin Client installer from:"
  Write-Host $DownloadUrl
  Invoke-WebRequest -Uri $DownloadUrl -OutFile $ClientPath -MaximumRedirection 0
  Write-Host "Downloaded MoreLogin Client installer to $ClientPath"
  Start-Process "explorer.exe" -ArgumentList "/select,`"$ClientPath`""
  Start-Process $ClientPath
  Write-Host "If UAC, EULA, firewall, privacy, or installer prompts appear, confirm them manually."
}

Assert-TrustedApiUrl
$Identify = Get-PlatformIdentify
$LatestCliDownloadUrl = Get-ReleaseResponse -Identify $Identify
$LatestCliVersion = Get-VersionFromDownloadUrl -Url $LatestCliDownloadUrl

$ExistingCliPath = if (Test-Path -LiteralPath $BinPath -PathType Leaf) {
  $BinPath
} else {
  $ExistingCommand = Get-Command "ml-cli" -ErrorAction SilentlyContinue
  if ($ExistingCommand) { $ExistingCommand.Source } else { $null }
}
$CliReady = $false
if ($ExistingCliPath) {
  $InstalledCliVersion = Get-InstalledCliVersion -Path $ExistingCliPath
  Write-Host "Installed ml-cli: $ExistingCliPath"
  Write-Host "Installed version: $(if ($InstalledCliVersion) { $InstalledCliVersion } else { 'unknown' })"
  Write-Host "Latest API version: $(if ($LatestCliVersion) { $LatestCliVersion } else { 'unknown' })"
  try {
    if ($InstalledCliVersion -and $LatestCliVersion -and $InstalledCliVersion -ge $LatestCliVersion) {
      Write-Host "ml-cli is already at the latest or a newer version. Skipping download."
    } else {
      & $ExistingCliPath self-update
    }
    & $ExistingCliPath --version
    $CliReady = $true
  } catch {
    Write-Warning "ml-cli self-update failed; falling back to user-local install. $($_.Exception.Message)"
  }
}

if (-not $CliReady) {
  $DownloadUrl = $LatestCliDownloadUrl

  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  $TmpPath = "$BinPath.tmp"

  Write-Host "Downloading ml-cli from:"
  Write-Host $DownloadUrl
  Invoke-WebRequest -Uri $DownloadUrl -OutFile $TmpPath -MaximumRedirection 0
  Move-Item -Force $TmpPath $BinPath

  $UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if (($UserPath -split ";") -notcontains $InstallDir) {
    $NewPath = if ([string]::IsNullOrWhiteSpace($UserPath)) { $InstallDir } else { "$UserPath;$InstallDir" }
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    Write-Host "Added $InstallDir to the user PATH. Restart the terminal if ml-cli is not found."
  }

  Write-Host "Installed ml-cli to $BinPath"
  & $BinPath --version
}

if ($SkipClient) {
  Write-Host ""
  Write-Host "MoreLogin Client check was skipped because MORELOGIN_SKIP_CLIENT is enabled."
} else {
  Save-MoreLoginClientInstaller
}
