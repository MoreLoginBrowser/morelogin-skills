$ErrorActionPreference = "Stop"

$ApiBase = "https://cb-gateway.morelogin.com/app/ver/public/latest"
$ApiHost = "cb-gateway.morelogin.com"
$ReleaseHost = "releases.morelogin.com"
$InstallHost = "get.morelogin.com"
$OfficialPublisher = "EASYANT PTE. LTD."
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

function Test-OfficialMoreLoginPublisher {
  param([Parameter(Mandatory = $true)]$Signature)

  if ($Signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or
      -not $Signature.SignerCertificate) {
    return $false
  }

  $ExpectedOrganization = "O=$OfficialPublisher"
  $ExpectedCommonName = "CN=$OfficialPublisher"
  $MatchedComponent = $Signature.SignerCertificate.Subject.Split(",") |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -ieq $ExpectedCommonName -or $_ -ieq $ExpectedOrganization } |
    Select-Object -First 1
  return [bool]$MatchedComponent
}

function Test-VersionMatchesExpected {
  param(
    [AllowNull()][string]$ActualVersion,
    [Parameter(Mandatory = $true)][Version]$ExpectedVersion
  )

  if (-not $ActualVersion -or $ActualVersion -notmatch "(?<version>\d+\.\d+\.\d+(?:\.\d+)?)") {
    return $false
  }
  try {
    $Actual = [Version]$Matches.version
  } catch {
    return $false
  }

  $ActualRevision = if ($Actual.Revision -lt 0) { 0 } else { $Actual.Revision }
  $ExpectedRevision = if ($ExpectedVersion.Revision -lt 0) { 0 } else { $ExpectedVersion.Revision }
  return $Actual.Major -eq $ExpectedVersion.Major -and
    $Actual.Minor -eq $ExpectedVersion.Minor -and
    $Actual.Build -eq $ExpectedVersion.Build -and
    $ActualRevision -eq $ExpectedRevision
}

function Test-TrustedInstalledMoreLoginExecutable {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $false
  }

  $Executable = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
  if (-not $Executable -or $Executable.Name -ine "MoreLogin.exe") {
    return $false
  }
  if (-not $Executable.VersionInfo.ProductName -or
      $Executable.VersionInfo.ProductName.IndexOf("MoreLogin", [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    return $false
  }

  try {
    $Signature = Get-AuthenticodeSignature -LiteralPath $Executable.FullName -ErrorAction Stop
  } catch {
    return $false
  }
  return Test-OfficialMoreLoginPublisher -Signature $Signature
}

function Get-MoreLoginClientRegistryCandidates {
  $Candidates = New-Object System.Collections.Generic.List[string]
  $UninstallPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )

  Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue |
    Where-Object {
      $_.DisplayName -like "*MoreLogin*" -or
      $_.InstallLocation -like "*MoreLogin*" -or
      $_.DisplayIcon -like "*MoreLogin*"
    } |
    ForEach-Object {
      if ($_.InstallLocation) {
        $Candidates.Add((Join-Path ([string]$_.InstallLocation) "MoreLogin.exe"))
      }
      if ($_.DisplayIcon) {
        $DisplayIconPath = ([string]$_.DisplayIcon).Split(",")[0].Trim().Trim('"')
        if ($DisplayIconPath) {
          $Candidates.Add($DisplayIconPath)
        }
      }
    }

  $AppPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\MoreLogin.exe",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\MoreLogin.exe"
  )
  foreach ($AppPath in $AppPaths) {
    try {
      $ExecutablePath = (Get-Item -LiteralPath $AppPath -ErrorAction Stop).GetValue("")
      if ($ExecutablePath) {
        $Candidates.Add([string]$ExecutablePath)
      }
    } catch {
      continue
    }
  }

  return @($Candidates | Select-Object -Unique)
}

function Get-MoreLoginClientFileSystemCandidates {
  $InstallRoots = @()
  if ($env:LOCALAPPDATA) {
    $InstallRoots += (Join-Path $env:LOCALAPPDATA "Programs\MoreLogin")
  }
  if ($env:ProgramFiles) {
    $InstallRoots += (Join-Path $env:ProgramFiles "MoreLogin")
  }
  if (${env:ProgramFiles(x86)}) {
    $InstallRoots += (Join-Path ${env:ProgramFiles(x86)} "MoreLogin")
  }

  foreach ($InstallRoot in $InstallRoots) {
    if (Test-Path -LiteralPath $InstallRoot -PathType Container) {
      Get-ChildItem -LiteralPath $InstallRoot -Filter "MoreLogin.exe" -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object { $_.FullName }
    }
  }
}

function Get-MoreLoginClientShortcutCandidates {
  $ShortcutRoots = @()
  if ($env:APPDATA) {
    $ShortcutRoots += (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs")
  }
  if ($env:ProgramData) {
    $ShortcutRoots += (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs")
  }
  if ($env:USERPROFILE) {
    $ShortcutRoots += (Join-Path $env:USERPROFILE "Desktop")
  }
  if ($env:PUBLIC) {
    $ShortcutRoots += (Join-Path $env:PUBLIC "Desktop")
  }

  try {
    $Shell = New-Object -ComObject WScript.Shell
  } catch {
    return
  }
  foreach ($ShortcutRoot in $ShortcutRoots) {
    if (-not (Test-Path -LiteralPath $ShortcutRoot -PathType Container)) {
      continue
    }
    Get-ChildItem -LiteralPath $ShortcutRoot -Filter "MoreLogin.lnk" -File -Recurse -ErrorAction SilentlyContinue |
      ForEach-Object {
        try {
          $TargetPath = $Shell.CreateShortcut($_.FullName).TargetPath
          if ($TargetPath) {
            $TargetPath
          }
        } catch {
          continue
        }
      }
  }
}

function Test-MoreLoginClientInstalled {
  $Candidates = @(
    @(Get-MoreLoginClientRegistryCandidates)
    @(Get-MoreLoginClientFileSystemCandidates)
    @(Get-MoreLoginClientShortcutCandidates)
  ) | Select-Object -Unique

  foreach ($Candidate in $Candidates) {
    if ($Candidate -and (Test-TrustedInstalledMoreLoginExecutable -Path $Candidate)) {
      Write-Host "Found trusted MoreLogin Client executable: $Candidate"
      return $true
    }
  }
  return $false
}

function Test-ReusableMoreLoginClientInstaller {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][Version]$ExpectedVersion
  )

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
  if (-not (Test-OfficialMoreLoginPublisher -Signature $Signature)) {
    return $false
  }

  $VersionInfo = $Installer.VersionInfo
  $ProductMetadata = @(
    $VersionInfo.CompanyName,
    $VersionInfo.ProductName,
    $VersionInfo.FileDescription
  ) -join " "
  if ($ProductMetadata.IndexOf("MoreLogin", [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    return $false
  }

  return (Test-VersionMatchesExpected -ActualVersion $VersionInfo.ProductVersion -ExpectedVersion $ExpectedVersion) -or
    (Test-VersionMatchesExpected -ActualVersion $VersionInfo.FileVersion -ExpectedVersion $ExpectedVersion)
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

function Test-ElevationCancelledByUser {
  param([Parameter(Mandatory = $true)][System.Exception]$Exception)

  return (($Exception.HResult -band 0xFFFF) -eq 1223) -or
    ($Exception.PSObject.Properties.Name -contains "NativeErrorCode" -and $Exception.NativeErrorCode -eq 1223)
}

function Start-MoreLoginClientInstaller {
  param([Parameter(Mandatory = $true)][string]$Path)

  $ResolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path

  Write-Host "Requesting Windows to launch the MoreLogin Client installer with elevation:"
  Write-Host $ResolvedPath
  try {
    Start-Process -FilePath $ResolvedPath -Verb RunAs -ErrorAction Stop
    # Do not use MainWindowHandle as the success condition. UAC can appear on the
    # secure desktop, and bootstrap installers commonly create another process.
    Write-Host "Windows accepted the installer launch request."
    Write-Host "Check the taskbar and secure desktop for a UAC prompt or MoreLogin installer window."
    Write-Host "Approve UAC, EULA, firewall, privacy, and installer prompts manually."
    return
  } catch {
    if (Test-ElevationCancelledByUser -Exception $_.Exception) {
      Write-Warning "The UAC prompt was cancelled. The installer was not started."
      return
    }
    Write-Warning "Windows could not launch the installer automatically. This process may not have access to the interactive desktop. $($_.Exception.Message)"
  }

  Show-MoreLoginInstallerInExplorer -Path $ResolvedPath
  Write-Host "Double-click the selected file manually:"
  Write-Host $ResolvedPath
}

function Save-MoreLoginClientInstaller {
  if (Test-MoreLoginClientInstalled) {
    Write-Host "MoreLogin Client appears to be installed. Skipping Client installer download."
    return
  }

  $ClientIdentify = "MoreLogin_AirDrop_window_x64"
  $DownloadUrl = Get-ReleaseResponse -Identify $ClientIdentify
  $ExpectedClientVersion = Get-VersionFromDownloadUrl -Url $DownloadUrl
  if (-not $ExpectedClientVersion) {
    throw "Could not determine the latest MoreLogin Client version from: $DownloadUrl"
  }
  $DownloadDir = if ($env:MORELOGIN_DOWNLOAD_DIR) { $env:MORELOGIN_DOWNLOAD_DIR } else { Join-Path $env:USERPROFILE "Downloads" }
  New-Item -ItemType Directory -Force -Path $DownloadDir | Out-Null
  $FileName = Split-Path -Leaf ([Uri]$DownloadUrl).AbsolutePath
  $ClientPath = Join-Path $DownloadDir $FileName

  $ReuseInstaller = Test-ReusableMoreLoginClientInstaller -Path $ClientPath -ExpectedVersion $ExpectedClientVersion
  if ($ReuseInstaller) {
    Write-Host "Found the latest MoreLogin Client installer in the download directory:"
    Write-Host $ClientPath
    Write-Host "The existing installer is valid. Skipping download."
  } else {
    Move-AsideInvalidFile -Path $ClientPath
    $PartialPath = "$ClientPath.part"

    if (Test-ReusableMoreLoginClientInstaller -Path $PartialPath -ExpectedVersion $ExpectedClientVersion) {
      Write-Host "Found a complete validated partial download. Finishing it without downloading again:"
      Write-Host $PartialPath
    } else {
      Write-Host "Downloading MoreLogin Client installer from:"
      Write-Host $DownloadUrl
      Save-WebFileWithResume -Url $DownloadUrl -Path $PartialPath
    }
    if (-not (Test-ReusableMoreLoginClientInstaller -Path $PartialPath -ExpectedVersion $ExpectedClientVersion)) {
      throw "Downloaded MoreLogin Client installer failed version, product, Authenticode, or publisher validation: $PartialPath"
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
  if ($LatestCliVersion -and $DownloadedCliVersion -ne $LatestCliVersion) {
    throw "Downloaded ml-cli version $DownloadedCliVersion does not match latest API version $LatestCliVersion`: $TmpPath"
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
