param([string]$DependenciesPath, [string]$BuildPath, [switch]$Candidate)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
Assert-ReleaseVersion
Add-Type -AssemblyName System.IO.Compression.FileSystem
$release = Read-ReleaseInfo
$output = Join-Path $script:RepositoryRoot $(if ($Candidate) { 'dist/candidates' } else { 'dist/release' })
New-Item -ItemType Directory -Force -Path $output | Out-Null
& "$PSScriptRoot/audit-runtime.ps1" -DependenciesPath $script:Dependencies -BuildPath $script:Build
& "$PSScriptRoot/package-sources.ps1" -DependenciesPath $script:Dependencies -BuildPath $script:Build -OutputDirectory $output
$sourceName = "tes3mp-shared-dialogue-$($release.version)-sources.zip"
$sourceHash = (Get-FileHash -LiteralPath (Join-Path $output $sourceName) -Algorithm SHA256).Hash.ToLower()
$commit = & git -C $script:RepositoryRoot rev-parse HEAD
if ($LASTEXITCODE) { throw 'Cannot determine the source commit' }
$versionFile = Join-Path $script:Build 'Release/resources/version'
$versionLines = @(Get-Content -LiteralPath $versionFile)
if ($versionLines.Count -lt 2 -or $versionLines[1].Trim() -ne $commit) {
    throw 'The build revision does not match HEAD. Run build.ps1 before packaging this commit.'
}
$dirty = [bool](& git -C $script:RepositoryRoot status --porcelain --untracked-files=normal)
$buildInfo = [ordered]@{
    project = $release.name; version = $release.version; engineVersion = $release.engineVersion
    protocol = $release.protocol; upstreamCommit = $release.upstreamCommit; sourceCommit = $commit
    sourceWorkingTreeDirty = $dirty; builtAtUtc = [DateTime]::UtcNow.ToString('o')
    distributionStatus = $(if ($Candidate) { 'Local review candidate' } else { 'Prepared locally; not published' })
    requiredSourceArchive = $sourceName; sourceArchiveSha256 = $sourceHash
    dependencyManifestSha256 = (Get-FileHash -LiteralPath "$PSScriptRoot/dependencies.json" -Algorithm SHA256).Hash.ToLower()
    sourceManifestSha256 = (Get-FileHash -LiteralPath "$PSScriptRoot/source-archives.json" -Algorithm SHA256).Hash.ToLower()
}
$infoPath = Join-Path $output 'BUILD-INFO.json'
$utf8 = New-Object Text.UTF8Encoding $false
[IO.File]::WriteAllText($infoPath, ($buildInfo | ConvertTo-Json) + "`n", $utf8)
$notice = Join-Path $output 'SOURCE-AND-INSTALLATION.txt'
[IO.File]::WriteAllText($notice, "TES3MP Shared Dialogue $($release.version)`nInstallation instructions: docs/shared-dialogue/installation.md`nPublish with the matching source archive: $sourceName`nSource archive SHA256: $sourceHash`nLicense and attribution: THIRD-PARTY-NOTICES.md`n", $utf8)
$baseFiles = Get-RuntimeLibraryMap
$baseFiles['LICENSE'] = Join-Path $script:RepositoryRoot 'LICENSE'
$baseFiles['THIRD-PARTY-NOTICES.md'] = Join-Path $script:RepositoryRoot 'THIRD-PARTY-NOTICES.md'
foreach ($name in @('AUTHORS.md','tes3mp-credits.md','tes3mp-changelog.md','CHANGELOG.md')) {
    $baseFiles[$name] = Join-Path $script:RepositoryRoot $name
}
$baseFiles['resources/version'] = $versionFile
$baseFiles['scripts/shared-dialogue/dependencies.json'] = Join-Path $PSScriptRoot 'dependencies.json'
$baseFiles['scripts/shared-dialogue/source-archives.json'] = Join-Path $PSScriptRoot 'source-archives.json'
$baseFiles['scripts/shared-dialogue/source-supplements.json'] = Join-Path $PSScriptRoot 'source-supplements.json'
$baseFiles['BUILD-INFO.json'] = $infoPath
$baseFiles['SOURCE-AND-INSTALLATION.txt'] = $notice
$baseFiles['RUNTIME-DEPENDENCIES.json'] = Join-Path $script:Build 'runtime-dependencies.json'
foreach ($document in Get-ChildItem -LiteralPath "$script:RepositoryRoot/docs/shared-dialogue" -Recurse -File) {
    $relative = $document.FullName.Substring($script:RepositoryRoot.Length + 1).Replace('\','/')
    $baseFiles[$relative] = $document.FullName
}
$checksums = @($sourceHash + '  ' + $sourceName)
foreach ($variant in @('client','client-server')) {
    $files = $baseFiles.Clone()
    $files['tes3mp.exe'] = Join-Path $script:Build 'Release/tes3mp.exe'
    if ($variant -eq 'client-server') { $files['tes3mp-server.exe'] = Join-Path $script:Build 'Release/tes3mp-server.exe' }
    $suffix = if ($Candidate) { '-candidate' } else { '' }
    $name = "tes3mp-shared-dialogue-$($release.version)-windows-x64-$variant$suffix.zip"
    $destination = Join-Path $output $name
    $temporaryZip = Join-Path $output ([Guid]::NewGuid().ToString() + '.zip')
    $manifest = @($files.Keys | Sort-Object | ForEach-Object {
        [ordered]@{path=$_;sha256=(Get-FileHash -LiteralPath $files[$_] -Algorithm SHA256).Hash.ToLower()}
    })
    $fileList = Join-Path $output "$variant-files.json"
    [IO.File]::WriteAllText($fileList, ($manifest | ConvertTo-Json -Depth 4) + "`n", $utf8)
    $files['FILE-MANIFEST.json'] = $fileList
    $zip = [IO.Compression.ZipFile]::Open($temporaryZip, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($entryName in ($files.Keys | Sort-Object)) {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $files[$entryName], $entryName)
        }
    } finally { $zip.Dispose() }
    $zip = [IO.Compression.ZipFile]::OpenRead($temporaryZip)
    try {
        if ($zip.Entries.Count -ne $files.Count) { throw 'Archive entry count mismatch' }
        foreach ($entry in $zip.Entries) {
            if (!$files.ContainsKey($entry.FullName)) { throw "Unexpected archive entry: $($entry.FullName)" }
            $sha = [Security.Cryptography.SHA256]::Create()
            $stream = $entry.Open()
            try { $actual = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') }
            finally { $stream.Dispose(); $sha.Dispose() }
            if ($actual -ne (Get-FileHash -LiteralPath $files[$entry.FullName] -Algorithm SHA256).Hash) {
                throw "Archive content mismatch: $($entry.FullName)"
            }
        }
    } finally { $zip.Dispose() }
    Move-Item -LiteralPath $temporaryZip -Destination $destination -Force
    $checksums += (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLower() + '  ' + $name
    Write-Output "Verified $name ($($files.Count) files)"
}
[IO.File]::WriteAllText((Join-Path $output 'SHA256SUMS.txt'), ($checksums -join "`n") + "`n", $utf8)
Write-Output "Local release artifacts: $output"
