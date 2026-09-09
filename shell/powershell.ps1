# Load this file from the PowerShell profile.
Import-Module PSReadLine -ErrorAction Stop

function Invoke-FtkFilePicker {
    param([string]$Path = '.', [switch]$Hidden, [switch]$Directory)
    foreach ($tool in @('fd', 'fzf', 'bat')) {
        if (-not (Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue)) {
            throw "Missing executable: $tool"
        }
    }
    $base = Get-Item -LiteralPath $Path -ErrorAction Stop
    if (-not $base.PSIsContainer -or $base.PSProvider.Name -ne 'FileSystem') {
        throw 'Choose a filesystem directory.'
    }
    $fdArgs = @('--type', 'f', '--color', 'never', '--absolute-path',
        '--exclude', '.git', '--exclude', 'node_modules', '--exclude', '.venv',
        '--exclude', '__pycache__', '--exclude', 'dist', '--exclude', 'build')
    if ($Directory) { $fdArgs[1] = 'd' }
    if ($Hidden) { $fdArgs += @('--hidden', '--exclude', 'AppData', '--exclude', '.cache') }
    $fzfArgs = @('--height', '80%', '--layout=reverse', '--border', '--no-multi',
        '--bind', 'alt-j:preview-down,alt-k:preview-up')
    if (-not $Directory) {
        $fzfArgs += @('--with-shell', 'cmd.exe /d /s /c',
            '--preview', 'bat --style=numbers --color=always --paging=never --line-range=:300 -- {}',
            '--preview-window', 'right:60%')
    }
    $oldOutput = $global:OutputEncoding
    $oldConsole = [Console]::OutputEncoding
    $oldInput = [Console]::InputEncoding
    try {
        $global:OutputEncoding = New-Object System.Text.UTF8Encoding($false)
        [Console]::OutputEncoding = $global:OutputEncoding
        [Console]::InputEncoding = $global:OutputEncoding
        Push-Location -LiteralPath $base.FullName
        try {
            fd @fdArgs | fzf @fzfArgs
        } finally { Pop-Location }
    } finally {
        $global:OutputEncoding = $oldOutput
        [Console]::OutputEncoding = $oldConsole
        [Console]::InputEncoding = $oldInput
    }
}
function ff { param([string]$Path = '.') Invoke-FtkFilePicker -Path $Path }
function ffh { param([string]$Path = '.') Invoke-FtkFilePicker -Path $Path -Hidden }
Set-Alias fpreview ff

# Return the selected history text. Never execute it.
function fh {
    param([string]$Query = '')
    $historyPath = (Get-PSReadLineOption).HistorySavePath
    if (-not (Test-Path -LiteralPath $historyPath)) { return }
    $oldOutput = $global:OutputEncoding
    $oldConsole = [Console]::OutputEncoding
    $oldInput = [Console]::InputEncoding
    try {
        $global:OutputEncoding = New-Object System.Text.UTF8Encoding($false)
        [Console]::OutputEncoding = $global:OutputEncoding
        [Console]::InputEncoding = $global:OutputEncoding
        Get-Content -LiteralPath $historyPath -Encoding UTF8 |
            Select-Object -Unique |
            fzf --height 40% --layout=reverse --border --tac --no-sort --no-multi --query="$Query"
    } finally {
        $global:OutputEncoding = $oldOutput
        [Console]::OutputEncoding = $oldConsole
        [Console]::InputEncoding = $oldInput
    }
}
Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ScriptBlock {
    $line = $null; $cursor = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
    $selected = fh -Query $line
    if ($selected) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace(0, $line.Length, [string]$selected)
    }
}
Set-PSReadLineKeyHandler -Chord 'Ctrl+t' -ScriptBlock {
    $selected = ff
    if ($selected) {
        $quoted = "'" + ([string]$selected).Replace("'", "''") + "'"
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quoted)
    }
}
Set-PSReadLineKeyHandler -Chord 'Alt+c' -ScriptBlock {
    $selected = Invoke-FtkFilePicker -Directory
    if ($selected) {
        Set-Location -LiteralPath $selected
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
}
