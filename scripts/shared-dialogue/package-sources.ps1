param([string]$DependenciesPath, [string]$BuildPath, [string]$OutputDirectory)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
Add-Type -AssemblyName System.IO.Compression.FileSystem
$release = Read-ReleaseInfo
if (!$OutputDirectory) { $OutputDirectory = Join-Path $script:RepositoryRoot 'dist/release' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$temporary = Join-Path $script:Build 'source-packaging'
New-Item -ItemType Directory -Force -Path $temporary | Out-Null
$files = @{}
# Include the complete current source snapshot, including unpublished edits.
# Generated/private paths are excluded by Git and checked again here.
$paths = @(& git -C $script:RepositoryRoot ls-files --cached --others --exclude-standard) | Sort-Object -Unique
if ($LASTEXITCODE) { throw 'Cannot enumerate source snapshot' }
foreach ($path in $paths) {
    if ($path -match '^(deps|dist|portable|build[^/]*|network-test|ui-test)/' -or
        $path -match '(?i)(^|/)Data Files/|\.(esm|esp|bsa|ess|omwsave|pid|log|exe|dll|pdb)$') {
        throw "Private/generated artifact in source snapshot: $path"
    }
    $absolute = Join-Path $script:RepositoryRoot $path
    if (Test-Path -LiteralPath $absolute -PathType Leaf) { $files['engine/' + $path] = $absolute }
}
foreach ($manifestName in @('source-archives.json','source-supplements.json')) {
    $manifest = Get-Content -LiteralPath "$PSScriptRoot/$manifestName" -Raw | ConvertFrom-Json
    foreach ($archive in $manifest.archives) {
        $path = Join-Path $script:Dependencies "downloads/$($archive.file)"
        if (!(Test-Path -LiteralPath $path)) {
            Invoke-Checked curl.exe @('--fail','--location','--retry','3','--silent','--show-error',$archive.url,'--output',($path + '.part'))
            if ((Get-FileHash -LiteralPath ($path + '.part') -Algorithm SHA256).Hash -ne $archive.sha256) { throw "Source hash mismatch: $($archive.file)" }
            Move-Item -LiteralPath ($path + '.part') -Destination $path
        }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $archive.sha256) { throw "Source hash mismatch: $($archive.file)" }
        $files['dependency-archives/' + $archive.file] = $path
    }
}
$dependencyManifest = Get-Content -LiteralPath "$PSScriptRoot/dependencies.json" -Raw | ConvertFrom-Json
foreach ($name in @('CrabNet','LuaJIT')) {
    $source = $dependencyManifest.sources | Where-Object directory -eq $name
    $directory = Join-Path $script:Dependencies $name
    $revision = & git -C $directory rev-parse HEAD
    if ($LASTEXITCODE) { throw "Cannot inspect dependency revision: $name" }
    $changes = & git -C $directory status --porcelain --untracked-files=no
    if ($LASTEXITCODE) { throw "Cannot inspect dependency source changes: $name" }
    if ($revision -ne $source.commit -or $changes) { throw "Dependency source differs from the pinned revision: $name" }
    $archive = Join-Path $temporary "$name-$($source.commit).tar"
    Invoke-Checked git @('-C',$directory,'archive','--format=tar',"--prefix=$name/","--output=$archive",$source.commit)
    $files['dependency-archives/' + [IO.Path]::GetFileName($archive)] = $archive
}
foreach ($name in @('config.h','ffbuild/config.mak')) {
    $files['build-records/ffmpeg/' + $name] = Join-Path $script:Dependencies "source-build/ffmpeg/$name"
}
$files['build-records/runtime-dependencies.json'] = Join-Path $script:Build 'runtime-dependencies.json'
$files['README.txt'] = Join-Path $PSScriptRoot 'source-bundle-readme.txt'
$manifestPath = Join-Path $temporary 'SOURCE-MANIFEST.json'
$manifest = @($files.Keys | Sort-Object | ForEach-Object {
    [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath $files[$_] -Algorithm SHA256).Hash.ToLower()}
})
[IO.File]::WriteAllText($manifestPath,($manifest | ConvertTo-Json -Depth 4) + "`n",(New-Object Text.UTF8Encoding $false))
$files['SOURCE-MANIFEST.json'] = $manifestPath
$zipPath = Join-Path $OutputDirectory "tes3mp-shared-dialogue-$($release.version)-sources.zip"
$tempZip = Join-Path $OutputDirectory ([Guid]::NewGuid().ToString() + '.zip')
$zip = [IO.Compression.ZipFile]::Open($tempZip,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($name in ($files.Keys | Sort-Object)) {
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$files[$name],$name)
    }
} finally { $zip.Dispose() }
$zip = [IO.Compression.ZipFile]::OpenRead($tempZip)
try {
    if ($zip.Entries.Count -ne $files.Count) { throw 'Source archive entry count mismatch' }
    foreach ($entry in $zip.Entries) {
        $hash = [Security.Cryptography.SHA256]::Create()
        $stream = $entry.Open()
        try { $actual = [BitConverter]::ToString($hash.ComputeHash($stream)).Replace('-','') }
        finally { $stream.Dispose(); $hash.Dispose() }
        if ($actual -ne (Get-FileHash -LiteralPath $files[$entry.FullName] -Algorithm SHA256).Hash) { throw "Source archive content mismatch: $($entry.FullName)" }
    }
} finally { $zip.Dispose() }
Move-Item -LiteralPath $tempZip -Destination $zipPath -Force
Write-Output "Verified source archive ($($files.Count) entries): $zipPath"
