$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\")).Path
$Skill = Get-Content -Raw (Join-Path $Root "skills\morelogin-setup\SKILL.md")
$Install = Get-Content -Raw (Join-Path $Root "skills\morelogin-setup\install.md")
$Windows = Get-Content -Raw (Join-Path $Root "skills\morelogin-setup\references\windows-installation.md")
$Script = Get-Content -Raw (Join-Path $Root "skills\morelogin-setup\scripts\install.ps1")

function Assert-Contains {
  param([string]$Text, [string]$Expected, [string]$Message)
  if ($Text.IndexOf($Expected, [StringComparison]::Ordinal) -lt 0) {
    throw $Message
  }
}

function Assert-NotContains {
  param([string]$Text, [string]$Unexpected, [string]$Message)
  if ($Text.IndexOf($Unexpected, [StringComparison]::Ordinal) -ge 0) {
    throw $Message
  }
}

Assert-Contains $Skill 'client status --output-json' 'SKILL.md must document the status check.'
Assert-Contains $Skill 'status: "not_installed"' 'SKILL.md must gate installation on not_installed.'
Assert-Contains $Skill 'invalid JSON' 'SKILL.md must fail closed on invalid status output.'
Assert-Contains $Install 'MORELOGIN_SKIP_CLIENT="1"' 'install.md must provide a CLI-only bootstrap.'
Assert-Contains $Install 'Never treat a failed check as `not_installed`.' 'install.md must document fail-closed behavior.'
Assert-Contains $Install 'git ls-remote origin refs/heads/main' 'install.md must document guide freshness checks.'
Assert-NotContains $Install 'install_1.1.ps1' 'install.md must not reference the superseded Windows bootstrap.'
Assert-Contains $Windows 'Run the read-only status check first' 'Windows reference must separate status from install.'
Assert-Contains $Script 'function Get-ClientStatusFromCli' 'Installer must use the CLI status command.'
Assert-Contains $Script 'function Request-ClientInstallFromCli' 'Installer must use the CLI install command.'
Assert-Contains $Script 'MoreLogin Client status is not safe to continue' 'Installer must reject unknown states.'
Assert-NotContains ($Script | Select-String -Pattern '(?m)^\s*Save-MoreLoginClientInstaller\s*$' -AllMatches | Out-String) 'Save-MoreLoginClientInstaller' 'Installer must not invoke the legacy detector in the main flow.'

Write-Output 'MoreLogin install contract checks passed.'
