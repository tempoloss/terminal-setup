$ErrorActionPreference = 'Stop'

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $installed = winget list --id $Id --exact --accept-source-agreements
    if (($installed -join "`n") -match [regex]::Escape($Id)) {
        Write-Host "$Name is already installed."
        return
    }

    Write-Host "Installing $Name..."
    winget install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install $Name with winget."
    }
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

function Get-FileSha256Prefix {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead((Resolve-Path -LiteralPath $Path))
        try {
            $hash = -join ($sha.ComputeHash($stream) | ForEach-Object { $_.ToString('x2') })
            return $hash.Substring(0, 12)
        }
        finally {
            $stream.Dispose()
        }
    }
    finally {
        $sha.Dispose()
    }
}

function Set-ObjectProperty {
    param(
        [Parameter(Mandatory = $true)]
        [psobject]$Object,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        $Value
    )

    $Object | Add-Member -MemberType NoteProperty -Name $Name -Value $Value -Force
}
function Remove-JsonLineComments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Json
    )

    $result = New-Object System.Text.StringBuilder
    $inString = $false
    $escaped = $false
    $i = 0

    while ($i -lt $Json.Length) {
        $char = $Json[$i]
        $next = if ($i + 1 -lt $Json.Length) { $Json[$i + 1] } else { [char]0 }

        if (-not $inString -and $char -eq '/' -and $next -eq '/') {
            while ($i -lt $Json.Length -and $Json[$i] -ne "`r" -and $Json[$i] -ne "`n") {
                $i++
            }
            continue
        }

        [void]$result.Append($char)

        if ($inString) {
            if ($escaped) {
                $escaped = $false
            } elseif ($char -eq '\') {
                $escaped = $true
            } elseif ($char -eq '"') {
                $inString = $false
            }
        } elseif ($char -eq '"') {
            $inString = $true
        }

        $i++
    }

    $result.ToString()
}


function Update-WindowsTerminalSettings {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackgroundPath
    )

    $settingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        Write-Host 'Windows Terminal settings.json was not found. Open Windows Terminal once, then rerun setup.ps1 to apply appearance settings.'
        return
    }

    $settingsContent = Get-Content -Raw -LiteralPath $settingsPath
    $settings = Remove-JsonLineComments -Json $settingsContent | ConvertFrom-Json
    if (-not $settings.profiles) {
        Set-ObjectProperty -Object $settings -Name 'profiles' -Value ([pscustomobject]@{})
    }

    if (-not $settings.profiles.defaults) {
        Set-ObjectProperty -Object $settings.profiles -Name 'defaults' -Value ([pscustomobject]@{})
    }


    $anekScheme = [pscustomobject]@{
        background = '#0B0B0B'
        black = '#1C1C1C'
        blue = '#7AA2F7'
        brightBlack = '#666666'
        brightBlue = '#7AA2F7'
        brightCyan = '#7DCFFF'
        brightGreen = '#95D475'
        brightPurple = '#BB9AF7'
        brightRed = '#FF6B6B'
        brightWhite = '#FFFFFF'
        brightYellow = '#D7BA7D'
        cursorColor = '#FFFFFF'
        cyan = '#7DCFFF'
        foreground = '#D0D0D0'
        green = '#95D475'
        name = 'Anek'
        purple = '#BB9AF7'
        red = '#FF6B6B'
        selectionBackground = '#FFFFFF'
        white = '#D0D0D0'
        yellow = '#D7BA7D'
    }
    $otherSchemes = @($settings.schemes | Where-Object { $_.name -ne 'Anek' })
    Set-ObjectProperty -Object $settings -Name 'schemes' -Value @($otherSchemes + $anekScheme)

    $defaults = $settings.profiles.defaults
    Set-ObjectProperty -Object $defaults -Name 'colorScheme' -Value 'Anek'
    Set-ObjectProperty -Object $defaults -Name 'backgroundImage' -Value $BackgroundPath
    Set-ObjectProperty -Object $defaults -Name 'backgroundImageAlignment' -Value 'center'
    Set-ObjectProperty -Object $defaults -Name 'backgroundImageOpacity' -Value 0.22
    Set-ObjectProperty -Object $defaults -Name 'backgroundImageStretchMode' -Value 'uniformToFill'
    Set-ObjectProperty -Object $defaults -Name 'cursorShape' -Value 'bar'
    Set-ObjectProperty -Object $defaults -Name 'opacity' -Value 100
    Set-ObjectProperty -Object $defaults -Name 'useAcrylic' -Value $false

    if (-not $defaults.font) {
        Set-ObjectProperty -Object $defaults -Name 'font' -Value ([pscustomobject]@{})
    }
    Set-ObjectProperty -Object $defaults.font -Name 'face' -Value 'MesloLGS Nerd Font'

    $backupPath = "$settingsPath.bak"
    Copy-Item -LiteralPath $settingsPath -Destination $backupPath -Force
    Write-Host "Backed up Windows Terminal settings to $backupPath"

    $settings | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    Write-Host 'Windows Terminal defaults updated.'
}

Install-WingetPackage -Id 'Microsoft.PowerShell' -Name 'PowerShell'
Install-WingetPackage -Id 'Microsoft.WindowsTerminal' -Name 'Windows Terminal'
Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Name 'Oh My Posh'

Refresh-Path

$ohMyPosh = Get-Command oh-my-posh -ErrorAction SilentlyContinue
if (-not $ohMyPosh) {
    throw 'oh-my-posh was installed, but is not available on PATH yet. Restart this shell and run setup.ps1 again.'
}

Write-Host 'Installing MesloLGS Nerd Font via Oh My Posh...'
& $ohMyPosh.Source font install meslo
if ($LASTEXITCODE -ne 0) {
    throw 'Failed to install MesloLGS Nerd Font.'
}

$themeSource = Join-Path $PSScriptRoot 'minimal.omp.json'
$profileSource = Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1'
$backgroundSource = Join-Path $PSScriptRoot 'terminalbg.png'
$backgroundHash = Get-FileSha256Prefix -Path $backgroundSource
$backgroundTarget = Join-Path $HOME "terminalbg-$backgroundHash.png"

Copy-Item -LiteralPath $themeSource -Destination (Join-Path $HOME 'minimal.omp.json') -Force
Copy-Item -LiteralPath $backgroundSource -Destination $backgroundTarget -Force

$documents = [Environment]::GetFolderPath('MyDocuments')
$profileTargets = @(
    (Join-Path $documents 'PowerShell\profile.ps1'),
    (Join-Path $documents 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $documents 'WindowsPowerShell\profile.ps1'),
    (Join-Path $documents 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)

foreach ($profilePath in $profileTargets) {
    $profileDir = Split-Path -Parent $profilePath
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Copy-Item -LiteralPath $profileSource -Destination $profilePath -Force
}

Update-WindowsTerminalSettings -BackgroundPath $backgroundTarget

Write-Host ''
Write-Host 'Setup complete.'
Write-Host ''
Write-Host 'Next steps:'
Write-Host '1. Restart Windows Terminal.'
Write-Host '2. The prompt, MesloLGS Nerd Font, acrylic, opacity, and terminal background are applied.'
Write-Host '3. Adjust Windows Terminal appearance manually only if you want a different opacity.'
