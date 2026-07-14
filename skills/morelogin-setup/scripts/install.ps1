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

function Test-ReusableMoreLoginClientInstaller {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $false
  }

  $Installer = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
  if (-not $Installer -or $Installer.Length -le 0) {
    return $false
  }

  try {
    $Signature = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
  } catch {
    return $false
  }
  if ($Signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid) {
    return $false
  }

  $VersionInfo = $Installer.VersionInfo
  $ProductMetadata = @(
    $VersionInfo.CompanyName,
    $VersionInfo.ProductName,
    $VersionInfo.FileDescription
  ) -join " "
  return $ProductMetadata.IndexOf("MoreLogin", [StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Move-AsideInvalidFile {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  $PreservedPath = "$Path.invalid-$(Get-Date -Format yyyyMMddHHmmssfff)"
  Move-Item -LiteralPath $Path -Destination $PreservedPath
  Write-Warning "Preserved an incomplete or invalid file at $PreservedPath"
}

function Save-WebFileWithResume {
  param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Path
  )

  for ($Attempt = 0; $Attempt -lt 2; $Attempt++) {
    $ExistingLength = if (Test-Path -LiteralPath $Path -PathType Leaf) {
      (Get-Item -LiteralPath $Path).Length
    } else {
      0
    }

    $Request = [System.Net.HttpWebRequest]::Create($Url)
    $Request.Method = "GET"
    $Request.AllowAutoRedirect = $false
    if ($ExistingLength -gt 0) {
      $Request.AddRange($ExistingLength)
      Write-Host "Resuming Client download at byte $ExistingLength."
    }

    $Response = $null
    try {
      $Response = [System.Net.HttpWebResponse]$Request.GetResponse()
    } catch [System.Net.WebException] {
      $ErrorResponse = $_.Exception.Response
      $StatusCode = if ($ErrorResponse) { [int]$ErrorResponse.StatusCode } else { 0 }
      if ($ErrorResponse) {
        $ErrorResponse.Close()
      }
      if ($ExistingLength -gt 0 -and $StatusCode -eq 416 -and $Attempt -eq 0) {
        Move-AsideInvalidFile -Path $Path
        Write-Warning "The server rejected the saved partial range. Restarting the download."
        continue
      }
      throw
    }

    try {
      $StatusCode = [int]$Response.StatusCode
      if ($StatusCode -notin @(200, 206)) {
        throw "Unexpected HTTP status $StatusCode while downloading $Url"
      }

      $Append = $ExistingLength -gt 0 -and $StatusCode -eq 206
      if ($Append) {
        $ContentRange = [string]$Response.Headers["Content-Range"]
        if (-not $ContentRange.StartsWith("bytes $ExistingLength-", [StringComparison]::OrdinalIgnoreCase)) {
          throw "The server returned an unexpected Content-Range while resuming: $ContentRange"
        }
      }

      $FileMode = if ($Append) { [System.IO.FileMode]::Append } else { [System.IO.FileMode]::Create }
      $InputStream = $Response.GetResponseStream()
      $OutputStream = New-Object System.IO.FileStream($Path, $FileMode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
      try {
        $Buffer = New-Object byte[] (1024 * 1024)
        while (($BytesRead = $InputStream.Read($Buffer, 0, $Buffer.Length)) -gt 0) {
          $OutputStream.Write($Buffer, 0, $BytesRead)
        }
      } finally {
        $OutputStream.Dispose()
        $InputStream.Dispose()
      }
      return
    } finally {
      $Response.Close()
    }
  }

  throw "Could not download $Url"
}

function Show-MoreLoginInstallerInExplorer {
  param([Parameter(Mandatory = $true)][string]$Path)

  try {
    Start-Process "explorer.exe" -ArgumentList "/select,`"$Path`"" -ErrorAction Stop
    Write-Host "Selected the MoreLogin Client installer in Explorer:"
    Write-Host $Path
  } catch {
    Write-Warning "Could not reveal the installer in Explorer. Open it manually: $Path. $($_.Exception.Message)"
  }
}

function Start-MoreLoginClientInstaller {
  param([Parameter(Mandatory = $true)][string]$Path)

  $InstallerProcess = $null
  $LaunchRequested = $false
  $VisibleWindowConfirmed = $false

  Write-Host "Requesting Windows to launch the MoreLogin Client installer with elevation:"
  Write-Host $Path
  try {
    $InstallerProcess = Start-Process -FilePath $Path -Verb RunAs -PassThru -ErrorAction Stop
    $LaunchRequested = $true
  } catch {
    Write-Warning "Windows did not start the installer. UAC may have been cancelled or the agent may not have access to the interactive desktop. $($_.Exception.Message)"
  }

  if ($LaunchRequested -and $InstallerProcess) {
    Start-Sleep -Seconds 5
    try {
      if (-not $InstallerProcess.HasExited) {
        $InstallerProcess.Refresh()
        $VisibleWindowConfirmed = $InstallerProcess.MainWindowHandle -ne [IntPtr]::Zero
      }
    } catch {
      Write-Warning "Could not confirm whether the installer window is visible. $($_.Exception.Message)"
    }
  }

  if ($VisibleWindowConfirmed) {
    Write-Host "The MoreLogin Client installer process is running with a visible window."
    Write-Host "Confirm UAC, EULA, firewall, privacy, and installer prompts manually."
    return
  }

  if ($LaunchRequested) {
    Write-Warning "Windows accepted the installer launch request, but a visible installer window could not be confirmed."
  }
  Show-MoreLoginInstallerInExplorer -Path $Path
  Write-Host "If the installer or UAC window is already visible, do not start it again."
  Write-Host "If no installer window appears, double-click the selected file manually:"
  Write-Host $Path
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

  $ReuseInstaller = Test-ReusableMoreLoginClientInstaller -Path $ClientPath
  if ($ReuseInstaller) {
    Write-Host "Found the latest MoreLogin Client installer in the download directory:"
    Write-Host $ClientPath
    Write-Host "The existing installer is valid. Skipping download."
  } else {
    Move-AsideInvalidFile -Path $ClientPath
    $PartialPath = "$ClientPath.part"

    if (Test-ReusableMoreLoginClientInstaller -Path $PartialPath) {
      Write-Host "Found a complete validated partial download. Finishing it without downloading again:"
      Write-Host $PartialPath
    } else {
      Write-Host "Downloading MoreLogin Client installer from:"
      Write-Host $DownloadUrl
      Save-WebFileWithResume -Url $DownloadUrl -Path $PartialPath
    }
    if (-not (Test-ReusableMoreLoginClientInstaller -Path $PartialPath)) {
      throw "Downloaded MoreLogin Client installer failed Authenticode or product validation: $PartialPath"
    }
    Move-Item -LiteralPath $PartialPath -Destination $ClientPath
    Write-Host "Downloaded MoreLogin Client installer to $ClientPath"
  }

  Start-MoreLoginClientInstaller -Path $ClientPath
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
  $TmpPath = Join-Path $InstallDir "ml-cli.download.exe"

  Write-Host "Downloading ml-cli from:"
  Write-Host $DownloadUrl
  Invoke-WebRequest -Uri $DownloadUrl -OutFile $TmpPath -MaximumRedirection 0
  $DownloadedCliVersion = Get-InstalledCliVersion -Path $TmpPath
  if (-not $DownloadedCliVersion) {
    throw "Downloaded ml-cli could not be executed or did not report a valid version: $TmpPath"
  }
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
