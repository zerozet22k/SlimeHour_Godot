# Slime Hour Windows updater (PowerShell 5.1+, no admin privileges).
# Downloads content-addressed partial updates when the local version matches
# the release's base_version; otherwise securely falls back to the full ZIP.
# Each assembled file is SHA256 verified before an atomic version install.
param(
    [string]$ApplyOnly = '',
    [string]$BaseDirectory = '',
    [string]$TargetDirectory = '',
    [switch]$ProbeDownload
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$validNames = @('SlimeHour.exe', 'SlimeHour.pck', 'update_and_run.ps1', 'updater_config.json', 'Start_Slime_Hour.bat')
$manifestName = 'release_manifest.json'
$deltaName = 'SlimeHour-Delta.zip'
$deltaMetaName = 'SlimeHour-Delta.json'

function Read-Manifest([string]$dir) {
    $path = Join-Path $dir $manifestName
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $m = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if ([int]$m.format -ne 1 -or [string]$m.version -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') {
        throw 'Invalid installed release manifest.'
    }
    return $m
}

function Verify-File([string]$path, [object]$spec) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing release file: $path" }
    if ([long](Get-Item -LiteralPath $path).Length -ne [long]$spec.size) {
        throw "Release file length mismatch: $path"
    }
    $real = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($real -cne [string]$spec.sha256) { throw "SHA256 verification failed: $path" }
}

function Copy-Segment([IO.Stream]$output, [string]$path, [long]$offset, [long]$length) {
    $inputStream = [IO.File]::OpenRead($path)
    try {
        if ($offset -lt 0 -or $length -lt 0 -or ($offset + $length) -gt $inputStream.Length) {
            throw "Invalid chunk offset in $path"
        }
        [void]$inputStream.Seek($offset, [IO.SeekOrigin]::Begin)
        $buffer = New-Object byte[] (1024 * 1024)
        $remaining = $length
        while ($remaining -gt 0) {
            $want = [int][Math]::Min([long]$buffer.Length, $remaining)
            $read = $inputStream.Read($buffer, 0, $want)
            if ($read -le 0) { throw "Incomplete chunk in $path" }
            $output.Write($buffer, 0, $read)
            $remaining -= $read
        }
    }
    finally { $inputStream.Dispose() }
}

function Apply-Delta([string]$oldDir, [string]$zipPath, [string]$destination, [string]$expectedVersion = '') {
    $old = Read-Manifest $oldDir
    if ($null -eq $old) { throw 'Old installation has no chunk manifest.' }
    $unpacked = Join-Path (Split-Path -Parent $destination) ('patch-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $unpacked -Force | Out-Null
    try {
        Expand-Archive -LiteralPath $zipPath -DestinationPath $unpacked -Force
        $patchFile = Join-Path $unpacked 'patch.json'
        if (-not (Test-Path -LiteralPath $patchFile)) { throw 'Delta archive has no patch.json.' }
        $patch = Get-Content -LiteralPath $patchFile -Raw | ConvertFrom-Json
        if ([int]$patch.format -ne 1 -or $patch.base_version -cne $old.version -or
            [int]$patch.manifest.format -ne 1 -or
            $patch.target_version -cne $patch.manifest.version) {
            throw 'Patch base or format mismatch.'
        }
        if ($expectedVersion -ne '' -and $patch.target_version -cne $expectedVersion) {
            throw 'Delta archive version differs from latest GitHub release.'
        }
        $oldChunks = @{}
        foreach ($file in $old.files) {
            if ($validNames -cnotcontains [string]$file.name) { throw 'Unexpected old manifest filename.' }
            $path = Join-Path $oldDir ([string]$file.name)
            Verify-File $path $file
            foreach ($chunk in $file.chunks) {
                $hash = [string]$chunk.sha256
                if ($hash -cnotmatch '^[a-f0-9]{64}$') { throw 'Bad old chunk hash.' }
                $oldChunks[$hash] = @{ Path = $path; Offset = [long]$chunk.offset; Size = [long]$chunk.size }
            }
        }
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        foreach ($file in $patch.manifest.files) {
            $name = [string]$file.name
            if ($validNames -cnotcontains $name) { throw "Unexpected patch target: $name" }
            $outputPath = Join-Path $destination $name
            $out = [IO.File]::Create($outputPath)
            try {
                foreach ($chunk in $file.chunks) {
                    $hash = [string]$chunk.sha256
                    if ($hash -cnotmatch '^[a-f0-9]{64}$' -or [long]$chunk.size -lt 0) {
                        throw 'Invalid patch chunk description.'
                    }
                    if ($oldChunks.ContainsKey($hash)) {
                        $source = $oldChunks[$hash]
                        if ([long]$source.Size -ne [long]$chunk.size) { throw 'Chunk collision or bad patch.' }
                        Copy-Segment $out $source.Path $source.Offset $source.Size
                    }
                    else {
                        $chunkPath = Join-Path (Join-Path $unpacked 'chunks') $hash
                        if (-not (Test-Path -LiteralPath $chunkPath)) {
                            throw "Missing changed chunk: $hash"
                        }
                        if ([long](Get-Item -LiteralPath $chunkPath).Length -ne [long]$chunk.size) {
                            throw 'Changed chunk size mismatch.'
                        }
                        $actual = (Get-FileHash -LiteralPath $chunkPath -Algorithm SHA256).Hash.ToLowerInvariant()
                        if ($actual -cne $hash) { throw 'Changed chunk hash mismatch.' }
                        Copy-Segment $out $chunkPath 0 ([long]$chunk.size)
                    }
                }
            }
            finally { $out.Dispose() }
            Verify-File $outputPath $file
            Write-Host ("Verified " + $name + " (" + [Math]::Round([double]$file.size / 1MB, 1) + " MB)")
        }
        Copy-Item -LiteralPath $patchFile -Destination (Join-Path $destination '_patch.audit.json') -Force
        # The manifest must describe the exact output, including all chunk offsets.
        $patch.manifest | ConvertTo-Json -Depth 15 -Compress |
            Set-Content -LiteralPath (Join-Path $destination $manifestName) -Encoding UTF8
        Write-Host "Partial update verified: $($patch.base_version) -> $($patch.target_version)"
    }
    finally {
        if (Test-Path -LiteralPath $unpacked) { Remove-Item -LiteralPath $unpacked -Recurse -Force }
    }
}

function Find-Asset([object]$release, [string]$name) {
    return $release.assets | Where-Object { $_.name -ceq $name } | Select-Object -First 1
}

function Download-Asset([object]$asset, [string]$destination, [int]$timeout = 180) {
    if ($null -eq $asset -or
        [string]$asset.browser_download_url -notmatch '^https://github\.com/') {
        throw 'Required GitHub release asset is missing or unsafe.'
    }
    $name = [string]$asset.name
    $expected = [long]$asset.size
    if ($expected -le 0) { throw "Release asset $name has an invalid size." }
    # Metadata must NEVER be allowed to download hundreds of megabytes.
    if ($name -eq $deltaMetaName -and $expected -gt 4096) {
        throw "Patch metadata is unexpectedly large ($expected bytes)."
    }
    if ($expected -lt 1MB) {
        Write-Host ("Fetching {0} ({1} bytes)..." -f $name, $expected)
    }
    else {
        Write-Host ("Downloading {0} ({1:N1} MiB)..." -f $name, ($expected / 1MB))
    }

    # Stream a GET instead of Invoke-WebRequest's misleading 'Writing web
    # request stream' progress. No complete ZIP is stored in memory.
    $partial = $destination + '.part'
    $response = $null
    $inputStream = $null
    $outputStream = $null
    $received = [long]0
    $finished = $false
    try {
        if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
        $request = [System.Net.WebRequest]::Create([Uri][string]$asset.browser_download_url)
        $request.Method = 'GET'
        $request.AllowAutoRedirect = $true
        $request.MaximumAutomaticRedirections = 5
        $request.UserAgent = 'SlimeHour-Updater/1.1'
        $request.Timeout = [int][Math]::Min([Math]::Max($timeout * 1000.0, 15000), 90000)
        $request.ReadWriteTimeout = 60000
        $response = $request.GetResponse()
        if ([int]$response.StatusCode -ne 200) {
            throw "Unexpected HTTP status while downloading: $($response.StatusCode)"
        }
        if ([long]$response.ContentLength -gt 0 -and
            [long]$response.ContentLength -ne $expected) {
            throw "Server returned an unexpected download size for $name."
        }
        $inputStream = $response.GetResponseStream()
        $outputStream = [IO.File]::Open($partial, [IO.FileMode]::CreateNew,
                                        [IO.FileAccess]::Write, [IO.FileShare]::None)
        $buffer = New-Object byte[] 65536
        $lastUpdate = [DateTime]::UtcNow.AddSeconds(-1)
        while (($count = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $received += [long]$count
            if ($received -gt $expected) {
                throw "Received more bytes than GitHub advertised for $name."
            }
            if ($name -eq $deltaMetaName -and $received -gt 4096) {
                throw 'Patch metadata exceeded 4 KiB. Aborting.'
            }
            $outputStream.Write($buffer, 0, $count)
            if ($expected -ge 1MB -and
                ([DateTime]::UtcNow - $lastUpdate).TotalMilliseconds -ge 250) {
                $percent = [int][Math]::Floor(100.0 * $received / $expected)
                $status = ("{0}: {1:N1} / {2:N1} MiB ({3}%)" -f
                    $name, ($received / 1MB), ($expected / 1MB), $percent)
                Write-Progress -Id 1 -Activity 'Slime Hour download' -Status $status -PercentComplete $percent
                $lastUpdate = [DateTime]::UtcNow
            }
        }
        if ($received -ne $expected) {
            throw ("Download incomplete for {0}: got {1} of {2} bytes." -f $name, $received, $expected)
        }
        $finished = $true
    }
    finally {
        if ($null -ne $outputStream) { $outputStream.Dispose() }
        if ($null -ne $inputStream) { $inputStream.Dispose() }
        if ($null -ne $response) { $response.Close() }
        if ($expected -ge 1MB) {
            Write-Progress -Id 1 -Activity 'Slime Hour download' -Completed
        }
        if (-not $finished -and (Test-Path -LiteralPath $partial)) {
            Remove-Item -LiteralPath $partial -Force
        }
    }
    if (Test-Path -LiteralPath $destination) {
        Remove-Item -LiteralPath $destination -Force
    }
    Move-Item -LiteralPath $partial -Destination $destination
    Write-Host ("Downloaded {0} ({1:N1} MiB; size verified)." -f $name, ($received / 1MB))
}

function Download-Verified([object]$release, [string]$name, [string]$dir) {
    $dataAsset = Find-Asset $release $name
    $hashAsset = Find-Asset $release ($name + '.sha256')
    $file = Join-Path $dir $name
    $hashFile = $file + '.sha256'
    Download-Asset $dataAsset $file 900
    Download-Asset $hashAsset $hashFile 60
    $line = (Get-Content -LiteralPath $hashFile -Raw).Trim()
    $pattern = '^([a-fA-F0-9]{64})\s+\*?' + [regex]::Escape($name) + '\s*$'
    if ($line -notmatch $pattern) { throw "Invalid checksum for $name." }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $matches[1].ToLowerInvariant()) { throw "Download hash mismatch for $name." }
    Write-Host "SHA256 verified: $name"
    return $file
}

function Start-Game([string]$path) {
    Write-Host "Launching Slime Hour: $path"
    Start-Process -FilePath $path -WorkingDirectory (Split-Path -Parent $path)
}

# CI can invoke the exact production reconstruction code with local test files.
if ($ApplyOnly -ne '') {
    if (-not $BaseDirectory -or -not $TargetDirectory) {
        throw '-ApplyOnly requires -BaseDirectory and -TargetDirectory.'
    }
    Apply-Delta $BaseDirectory $ApplyOnly $TargetDirectory
    exit 0
}

$configPath = Join-Path $scriptRoot 'updater_config.json'
if (-not (Test-Path -LiteralPath $configPath)) { throw 'Missing updater_config.json.' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$repo = [string]$config.repository
$assetName = [string]$config.release_asset
$exeName = [string]$config.executable
if ($repo -notmatch '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$' -or
    $assetName -notmatch '^[a-zA-Z0-9_.-]+\.zip$' -or $exeName -cne 'SlimeHour.exe') {
    throw 'Invalid public GitHub release updater configuration.'
}
# CI tests the production downloader against the actual tiny GitHub JSON.
# This never installs or changes a game executable.
if ($ProbeDownload) {
    $probeTemp = Join-Path ([IO.Path]::GetTempPath()) ("slime-hour-probe-" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $headers = @{ 'User-Agent' = 'SlimeHour-Launcher'; 'Accept' = 'application/vnd.github+json' }
        $probeRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 25
        $probeAsset = Find-Asset $probeRelease $deltaMetaName
        if ($null -eq $probeAsset) { throw 'Latest release has no delta metadata asset.' }
        Download-Asset $probeAsset $probeTemp 40
        if ([long](Get-Item -LiteralPath $probeTemp).Length -ne [long]$probeAsset.size) {
            throw 'Metadata probe downloaded the wrong number of bytes.'
        }
        $metadata = Get-Content -LiteralPath $probeTemp -Raw | ConvertFrom-Json
        if (-not $metadata.base_version -or -not $metadata.target_version) {
            throw 'Metadata probe did not return a valid patch description.'
        }
        Write-Host 'PASS: GitHub delta metadata downloaded with exact advertised size.'
    }
    finally {
        if (Test-Path -LiteralPath $probeTemp) { Remove-Item -LiteralPath $probeTemp -Force }
    }
    exit 0
}
if (-not $env:LOCALAPPDATA) { $env:LOCALAPPDATA = [IO.Path]::GetTempPath() }
$installRoot = Join-Path $env:LOCALAPPDATA 'SlimeHour'
$versionsRoot = Join-Path $installRoot 'versions'
$lastPath = Join-Path $installRoot 'last_installed.txt'
New-Item -ItemType Directory -Path $versionsRoot -Force | Out-Null
$baseDir = $scriptRoot
$cachedExe = Join-Path $scriptRoot $exeName
if (Test-Path -LiteralPath $lastPath) {
    $prior = (Get-Content -LiteralPath $lastPath -Raw).Trim()
    if ($prior -match '^v[0-9]+\.[0-9]+\.[0-9]+$') {
        $installed = Join-Path $versionsRoot $prior
        if (Test-Path -LiteralPath (Join-Path $installed $exeName)) {
            $baseDir = $installed
            $cachedExe = Join-Path $installed $exeName
        }
    }
}
# A downloaded ZIP can be launched directly without a prior installed cache.
$sourceManifest = Read-Manifest $scriptRoot
if ($null -ne $sourceManifest) {
    $cachedManifest = Read-Manifest $baseDir
    if ($null -eq $cachedManifest -or
        [version]($sourceManifest.version.TrimStart('v')) -gt
        [version]($cachedManifest.version.TrimStart('v'))) {
        $baseDir = $scriptRoot
        $cachedExe = Join-Path $scriptRoot $exeName
    }
}
try {
    Write-Host "Checking $repo for Slime Hour updates..."
    $headers = @{ 'User-Agent' = 'SlimeHour-Launcher'; 'Accept' = 'application/vnd.github+json' }
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 20
    $tag = [string]$release.tag_name
    if ($tag -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Unsafe or missing release tag.' }
    $targetDir = Join-Path $versionsRoot $tag
    $exePath = Join-Path $targetDir $exeName
    $baseManifest = Read-Manifest $baseDir
    $baseVersion = if ($null -eq $baseManifest) { '' } else { [string]$baseManifest.version }

    if (-not (Test-Path -LiteralPath $exePath)) {
        if ($baseVersion -eq $tag -and (Test-Path -LiteralPath $cachedExe)) {
            Start-Game $cachedExe
            exit 0
        }
        if ($baseVersion -ne '' -and
            [version]($baseVersion.TrimStart('v')) -gt [version]($tag.TrimStart('v'))) {
            Write-Host 'Local version is newer than the published release.'
            Start-Game $cachedExe
            exit 0
        }
        $tmp = Join-Path $installRoot ('.update-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        try {
            $built = Join-Path $tmp 'assembled'
            $patched = $false
            $metaAsset = Find-Asset $release $deltaMetaName
            if ($null -ne $baseManifest -and $null -ne $metaAsset) {
                try {
                    $metaFile = Join-Path $tmp $deltaMetaName
                    Download-Asset $metaAsset $metaFile 45
                    $meta = Get-Content -LiteralPath $metaFile -Raw | ConvertFrom-Json
                    if ($meta.base_version -ceq $baseVersion -and $meta.target_version -ceq $tag) {
                        $deltaAsset = Find-Asset $release $deltaName
                        if ($null -ne $deltaAsset) {
                            Write-Host "Small update available: $baseVersion -> $tag"
                            $deltaPath = Download-Verified $release $deltaName $tmp
                            Apply-Delta $baseDir $deltaPath $built $tag
                            $patched = $true
                        }
                    } else {
                        Write-Host 'This version needs a full update (no matching patch).'
                    }
                }
                catch {
                    Write-Warning ("Partial update failed; using the verified full download: " + $_.Exception.Message)
                    if (Test-Path -LiteralPath $built) {
                        Remove-Item -LiteralPath $built -Recurse -Force
                    }
                }
            }
            if (-not $patched) {
                $zipPath = Download-Verified $release $assetName $tmp
                Expand-Archive -LiteralPath $zipPath -DestinationPath $built -Force
                if (-not (Test-Path -LiteralPath (Join-Path $built $exeName))) {
                    throw 'Full release ZIP is missing the game executable.'
                }
                $newManifest = Read-Manifest $built
                if ($null -ne $newManifest) {
                    if ($newManifest.version -cne $tag) { throw 'Full ZIP version does not match release tag.' }
                    foreach ($entry in $newManifest.files) {
                        if ($validNames -cnotcontains [string]$entry.name) { throw 'Unexpected full-release file name.' }
                        Verify-File (Join-Path $built ([string]$entry.name)) $entry
                    }
                }
            }
            if (Test-Path -LiteralPath $targetDir) { Remove-Item -LiteralPath $targetDir -Recurse -Force }
            Move-Item -LiteralPath $built -Destination $targetDir
            Write-Host "Slime Hour updated to $tag."
        }
        finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        }
    }
    Set-Content -LiteralPath $lastPath -Value $tag -Encoding ASCII
    Start-Game $exePath
    exit 0
}
catch {
    Write-Warning ("Update failed or offline: " + $_.Exception.Message)
    if (Test-Path -LiteralPath $cachedExe) {
        Write-Host 'Playing the previously installed version.'
        Start-Game $cachedExe
        exit 0
    }
    throw 'No playable Slime Hour installation was found. Install the full ZIP from GitHub Releases.'
}
