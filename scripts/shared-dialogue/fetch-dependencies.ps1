param([string]$DependenciesPath, [string]$BuildPath)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
$sevenZip = Find-SevenZip
$manifest = Get-Content -LiteralPath "$PSScriptRoot/dependencies.json" -Raw | ConvertFrom-Json
$downloads = Join-Path $script:Dependencies 'downloads'
New-Item -ItemType Directory -Force -Path $downloads | Out-Null
foreach ($archive in $manifest.archives) {
    $destination = Join-Path $downloads $archive.file
    if (!(Test-Path -LiteralPath $destination)) {
        Write-Output "Downloading $($archive.file)"
        Invoke-Checked curl.exe @('--fail','--location','--retry','3','--silent','--show-error',$archive.url,'--output',($destination + '.part'))
        if ((Get-FileHash -LiteralPath ($destination + '.part') -Algorithm SHA256).Hash -ne $archive.sha256) {
            throw "Checksum mismatch: $($archive.file). The partial file was left for inspection."
        }
        Move-Item -LiteralPath ($destination + '.part') -Destination $destination
    }
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $archive.sha256) {
        throw "Checksum mismatch in cached archive: $destination"
    }
    # A completion marker avoids unpacking Boost on every incremental build.
    $marker = Join-Path $downloads ($archive.file + '.extracted')
    $expected = Join-Path $script:Dependencies $archive.probe
    if (!(Test-Path -LiteralPath $marker) -or !(Test-Path -LiteralPath $expected)) {
        if ($archive.kind -eq 'inno') {
            $extractor = Join-Path $script:Dependencies 'innoextract/innoextract.exe'
            # Only headers, libraries and license are needed. The unused bundled
            # HTML manual contains paths longer than Win32 tools can extract.
            Invoke-Checked $extractor @('--extract','--quiet','--include','app/boost',
                '--include','app/lib64-msvc-14.2','--include','app/LICENSE_1_0.txt',
                '--output-dir',(Join-Path $script:Dependencies $archive.destination),$destination)
        } else {
            Invoke-Checked $sevenZip @('x','-y',('-o' + (Join-Path $script:Dependencies $archive.destination)),$destination)
        }
        if (!(Test-Path -LiteralPath $expected)) { throw "Archive did not produce expected file: $expected" }
        Set-Content -LiteralPath $marker -Value $archive.sha256
    }
}
foreach ($source in $manifest.sources) {
    $destination = Join-Path $script:Dependencies $source.directory
    if (!(Test-Path -LiteralPath $destination)) {
        Invoke-Checked git @('clone',$source.url,$destination)
        Invoke-Checked git @('-C',$destination,'checkout','--detach',$source.commit)
    }
    $actual = & git -C $destination rev-parse HEAD
    if ($LASTEXITCODE -ne 0 -or $actual -ne $source.commit) { throw "Unexpected source revision: $destination" }
    $changes = & git -C $destination status --porcelain --untracked-files=no
    if ($LASTEXITCODE -ne 0 -or $changes) { throw "Tracked dependency source changes must be reviewed: $destination" }
    if ($source.submodules) { Invoke-Checked git @('-C',$destination,'submodule','update','--init','--recursive') }
}
Write-Output "Verified dependencies: $script:Dependencies"
& "$PSScriptRoot/fetch-source-archives.ps1" -DependenciesPath $script:Dependencies -BuildPath $script:Build
