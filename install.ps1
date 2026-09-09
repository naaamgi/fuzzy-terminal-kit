[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$RestoreBackup,
    [switch]$SkipDependencies,
    [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA "fuzzy-terminal-kit\powershell-$($PSVersionTable.PSVersion.Major)")
)
$ErrorActionPreference = 'Stop'
$startMarker = '# >>> fuzzy-terminal-kit >>>'
$endMarker = '# <<< fuzzy-terminal-kit <<<'
$ProfilePath = [IO.Path]::GetFullPath($ProfilePath)
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
$statePath = Join-Path $InstallRoot 'state.json'
$utf8Bom = New-Object Text.UTF8Encoding($true)
$text = if (Test-Path -LiteralPath $ProfilePath) { [IO.File]::ReadAllText($ProfilePath) } else { '' }
$startCount = [regex]::Matches($text, '(?m)^' + [regex]::Escape($startMarker) + '\r?$').Count
$endCount = [regex]::Matches($text, '(?m)^' + [regex]::Escape($endMarker) + '\r?$').Count
if ($startCount -ne $endCount -or $startCount -gt 1) { throw 'Broken managed block. Restore or repair the profile first.' }
$pattern = '(?ms)^' + [regex]::Escape($startMarker) + '\r?\n.*?^' + [regex]::Escape($endMarker) + '(?:\r?\n|$)'
if ($startCount -eq 1 -and -not [regex]::IsMatch($text, $pattern)) { throw 'Managed block markers are out of order.' }
$cleanText = [regex]::Replace($text, $pattern, '')
$state = if (Test-Path -LiteralPath $statePath) { Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json } else { $null }
if ($state -and $state.profile -ne $ProfilePath) { throw 'This install root belongs to another profile. Choose a different -InstallRoot.' }
if (-not $state -and (Test-Path -LiteralPath $InstallRoot) -and @(Get-ChildItem -LiteralPath $InstallRoot -Force).Count) {
    throw 'Install root is not empty and has no installation state. Choose a different -InstallRoot.'
}

if ($RestoreBackup -and -not $state) { throw 'No baseline backup exists for this profile.' }
if (($Uninstall -or $RestoreBackup) -and -not $state) { Write-Host 'Nothing installed for this profile.'; return }

if (-not $Uninstall -and -not $RestoreBackup) {
    $source = Join-Path $PSScriptRoot 'shell\powershell.ps1'
    if (-not (Test-Path -LiteralPath $source)) { throw 'Extract the entire project ZIP before running the installer.' }
    $parseErrors = $null; $tokens = $null
    [void][Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw 'Invalid PowerShell payload.' }
    $packages = [ordered]@{fzf='junegunn.fzf'; fd='sharkdp.fd'; bat='sharkdp.bat'}
    foreach ($tool in $packages.Keys) {
        if (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue) { continue }
        if ($SkipDependencies) { throw "Missing executable: $tool" }
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Install Microsoft App Installer (WinGet), then retry.' }
        & winget install --id $packages[$tool] -e --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw "WinGet installation failed for $tool (exit $LASTEXITCODE)." }
    }
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') + ';' + $env:Path
    foreach ($tool in $packages.Keys) {
        if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) { throw "Open a new terminal and retry; $tool is not on PATH yet." }
    }
    & fzf --with-shell 'cmd.exe /d /s /c' --version | Out-Null
    if ($LASTEXITCODE) { throw 'Update fzf; this version does not support --with-shell.' }
    Import-Module PSReadLine -ErrorAction Stop
}

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
$snapshot = Join-Path $InstallRoot ('backups\' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss-fffffff'))
New-Item -ItemType Directory -Force -Path $snapshot | Out-Null
if (Test-Path -LiteralPath $ProfilePath) { Copy-Item -LiteralPath $ProfilePath -Destination (Join-Path $snapshot 'profile.ps1') }
if (-not $state) {
    $state = [pscustomobject]@{ profile=$ProfilePath; existed=(Test-Path -LiteralPath $ProfilePath); baseline=(Join-Path $InstallRoot 'profile-before-install.ps1') }
    if ($state.existed) { Copy-Item -LiteralPath $ProfilePath -Destination $state.baseline }
    [IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json), $utf8Bom)
}

if ($RestoreBackup) {
    if ($state.existed) {
        Copy-Item -LiteralPath $state.baseline -Destination $ProfilePath -Force
    } elseif (Test-Path -LiteralPath $ProfilePath) {
        Remove-Item -LiteralPath $ProfilePath
    }
    Write-Host "Baseline restored. Previous current profile is backed up in: $snapshot"
} elseif ($Uninstall) {
    if ($startCount) { [IO.File]::WriteAllText($ProfilePath, $cleanText, $utf8Bom) }
    Write-Host 'Managed profile block removed. Other profile content, tools and backups were kept.'
} else {
    $target = Join-Path $InstallRoot 'powershell.ps1'
    if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination (Join-Path $snapshot 'powershell.ps1') }
    Copy-Item -LiteralPath $source -Destination $target -Force
    $quotedTarget = $target.Replace("'", "''")
    $block = "$startMarker`r`nif (Test-Path -LiteralPath '$quotedTarget') { . '$quotedTarget' }`r`n$endMarker`r`n"
    if ($cleanText.Length -and -not $cleanText.EndsWith("`n")) { $cleanText += "`r`n" }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ProfilePath) | Out-Null
    [IO.File]::WriteAllText($ProfilePath, $cleanText + $block, $utf8Bom)
    Write-Host "Installed for PowerShell $($PSVersionTable.PSVersion.Major): $ProfilePath"
    Write-Host "Backup: $snapshot"
    Write-Host 'Open a new terminal. Commands: ff, ffh, fh. Keys: Ctrl+R, Ctrl+T, Alt+C.'
}
