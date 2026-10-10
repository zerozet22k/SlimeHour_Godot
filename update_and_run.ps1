# Slime Hour Windows updater. Standard PowerShell 5.1+, no admin rights.
# Downloads signed-by-release SHA256 protected ZIPs into LOCALAPPDATA and keeps
# earlier installs as offline fallback. Only public GitHub releases are supported.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptRoot 'updater_config.json'
if (-not (Test-Path -LiteralPath $configPath)) { throw 'Missing updater_config.json' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$repo = [string]$config.repository
$assetName = [string]$config.release_asset
$exeName = [string]$config.executable
if ($repo -notmatch '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$' -or $repo -match 'YOUR_PUBLIC') {
    throw 'The developer must configure a PUBLIC GitHub Releases repository in updater_config.json before sharing the launcher.'
}
if ($assetName -notmatch '^[a-zA-Z0-9_.-]+\.zip$' -or $exeName -notmatch '^[a-zA-Z0-9_.-]+\.exe$') {
    throw 'Invalid release asset or executable name in updater_config.json.'
}
$installRoot = Join-Path $env:LOCALAPPDATA 'SlimeHour'
$versionsRoot = Join-Path $installRoot 'versions'
New-Item -ItemType Directory -Force -Path $versionsRoot | Out-Null
$lastPath = Join-Path $installRoot 'last_installed.txt'

function Get-InstalledExe {
    if (Test-Path -LiteralPath $lastPath) {
        $tag = (Get-Content -LiteralPath $lastPath -Raw).Trim()
        if ($tag -match '^[0-9A-Za-z._-]+$') {
            $candidate = Join-Path (Join-Path $versionsRoot $tag) $exeName
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }
    # Recovery if interrupted before saving last_installed.txt.
    foreach ($dir in (Get-ChildItem -LiteralPath $versionsRoot -Directory | Sort-Object LastWriteTime -Descending)) {
        $candidate = Join-Path $dir.FullName $exeName
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

function Start-Game([string]$path) {
    Write-Host "Launching Slime Hour: $path"
    Start-Process -FilePath $path -WorkingDirectory (Split-Path -Parent $path)
}

$cachedExe = Get-InstalledExe
try {
    Write-Host "Checking $repo for Slime Hour updates..."
    $headers = @{ 'User-Agent' = 'SlimeHour-Launcher'; 'Accept' = 'application/vnd.github+json' }
    $releaseUrl = "https://api.github.com/repos/$repo/releases/latest"
    $release = Invoke-RestMethod -Uri $releaseUrl -Headers $headers -TimeoutSec 12
    $tag = [string]$release.tag_name
    if ($tag -notmatch '^[a-zA-Z0-9._-]+$') { throw 'Unsafe or missing release version.' }
    $targetDir = Join-Path $versionsRoot $tag
    $exePath = Join-Path $targetDir $exeName
    if (-not (Test-Path -LiteralPath $exePath)) {
        $zipAsset = $release.assets | Where-Object { $_.name -ceq $assetName } | Select-Object -First 1
        $hashAsset = $release.assets | Where-Object { $_.name -ceq "$assetName.sha256" } | Select-Object -First 1
        if ($null -eq $zipAsset -or $null -eq $hashAsset) {
            throw "Latest GitHub release is missing $assetName or its .sha256 file."
        }
        if ([string]$zipAsset.browser_download_url -notlike 'https://github.com/*' -or
            [string]$hashAsset.browser_download_url -notlike 'https://github.com/*') {
            throw 'Unexpected release download host.'
        }
        $tempDir = Join-Path $installRoot ('.update-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $zipPath = Join-Path $tempDir $assetName
            $checksumPath = Join-Path $tempDir "$assetName.sha256"
            Write-Host "Downloading new release $tag..."
            Invoke-WebRequest -Uri $zipAsset.browser_download_url -OutFile $zipPath -TimeoutSec 120 -UseBasicParsing
            Invoke-WebRequest -Uri $hashAsset.browser_download_url -OutFile $checksumPath -TimeoutSec 20 -UseBasicParsing
            $checksumText = (Get-Content -LiteralPath $checksumPath -Raw).Trim()
            $checksumPattern = '^([A-Fa-f0-9]{64})(?:\s+\*?' + [regex]::Escape($assetName) + ')?\s*$'
            if ($checksumText -notmatch $checksumPattern) {
                throw 'Invalid SHA256 checksum file.'
            }
            $expected = $matches[1].ToUpperInvariant()
            $actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToUpperInvariant()
            if ($actual -cne $expected) { throw 'Release checksum failed. Update rejected.' }
            $unpackDir = Join-Path $tempDir 'unpacked'
            New-Item -ItemType Directory -Path $unpackDir -Force | Out-Null
            Expand-Archive -LiteralPath $zipPath -DestinationPath $unpackDir -Force
            if (-not (Test-Path -LiteralPath (Join-Path $unpackDir $exeName))) {
                throw "ZIP must contain $exeName at its root."
            }
            if (Test-Path -LiteralPath $targetDir) {
                Remove-Item -LiteralPath $targetDir -Recurse -Force
            }
            Move-Item -LiteralPath $unpackDir -Destination $targetDir
            Write-Host "Updated Slime Hour to $tag."
        } finally {
            if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
        }
    }
    Set-Content -LiteralPath $lastPath -Value $tag -Encoding ASCII
    Start-Game $exePath
    exit 0
} catch {
    Write-Warning ("Update check failed: " + $_.Exception.Message)
    if ($cachedExe -and (Test-Path -LiteralPath $cachedExe)) {
        Write-Host 'Starting the previously installed version (offline fallback).'
        Start-Game $cachedExe
        exit 0
    }
    $sourceLauncher = Join-Path $scriptRoot 'PLAY_WINDOWS.bat'
    if (Test-Path -LiteralPath $sourceLauncher) {
        Write-Host 'Starting the local Slime Hour project.'
        & $sourceLauncher
        exit $LASTEXITCODE
    }
    Write-Error 'No playable version is installed yet. Connect to the internet and make sure the public release is published.'
    exit 1
}
