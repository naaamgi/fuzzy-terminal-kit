$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$caseDir = Join-Path $root ('test-results\windows-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $caseDir | Out-Null
$profileFile = Join-Path $caseDir 'profile.ps1'
$installRoot = Join-Path $caseDir "space and 'quote\install"
$baseline = "# existing profile`r`n`$env:FTK_EXISTING = 'kept'`r`n"
[IO.File]::WriteAllText($profileFile, $baseline, [Text.UTF8Encoding]::new($true))
$initialBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($profileFile))
$installer = Join-Path $root 'install.ps1'
$params = @{ProfilePath=$profileFile; InstallRoot=$installRoot; SkipDependencies=$true}
& $installer @params
& $installer @params
$text = [IO.File]::ReadAllText($profileFile)
if ([regex]::Matches($text,'# >>> fuzzy-terminal-kit >>>').Count -ne 1) { throw 'Duplicate block' }
. $profileFile
if ($env:FTK_EXISTING -ne 'kept') { throw 'Existing content damaged' }
$fixture = Join-Path $caseDir 'files'
New-Item -ItemType Directory -Force -Path $fixture,(Join-Path $fixture '.hidden'),(Join-Path $fixture 'node_modules') | Out-Null
$unicodeName = ([string][char]0xD55C) + ([string][char]0xAE00) + ' space.txt'
[IO.File]::WriteAllText((Join-Path $fixture $unicodeName), 'preview')
[IO.File]::WriteAllText((Join-Path $fixture '.hidden\secret.txt'), 'hidden')
[IO.File]::WriteAllText((Join-Path $fixture 'node_modules\excluded.txt'), 'excluded')
$oldOptions = $env:FZF_DEFAULT_OPTS
$oldLocation = (Get-Location).Path
try {
    $env:FZF_DEFAULT_OPTS = '--filter=space.txt$'
    if ((ff $fixture) -ne (Join-Path $fixture $unicodeName)) { throw 'Unicode/space path failed' }
    $env:FZF_DEFAULT_OPTS = '--filter=secret.txt$'
    if (ff $fixture) { throw 'Hidden file leaked' }
    if (-not (ffh $fixture)) { throw 'Hidden file missing' }
    $env:FZF_DEFAULT_OPTS = '--filter=excluded.txt$'
    if (ffh $fixture) { throw 'Excluded file leaked' }
    if ((Get-Location).Path -ne $oldLocation) { throw 'Working directory changed' }
} finally { $env:FZF_DEFAULT_OPTS = $oldOptions }
Add-Content -LiteralPath $profileFile -Value '# user edit after install'
& $installer @params -Uninstall
$after = [IO.File]::ReadAllText($profileFile)
if ($after.Contains('# >>> fuzzy-terminal-kit >>>') -or -not $after.Contains('# user edit after install')) { throw 'Uninstall damaged later edit' }
& $installer @params -RestoreBackup
if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($profileFile)) -ne $initialBytes) { throw 'Baseline restore failed' }
'PASS: install, repeat, quoted path, existing profile, file selection, hidden/excluded files, uninstall, exact baseline restore'
"Test artifacts: $caseDir"
