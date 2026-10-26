. "$PSScriptRoot/common.ps1"
Assert-ReleaseVersion
foreach ($script in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
    $tokens = $null
    $parseErrors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw "$($script.Name): $($parseErrors -join '; ')" }
}
$manifest = Get-Content -LiteralPath "$PSScriptRoot/dependencies.json" -Raw | ConvertFrom-Json
foreach ($archive in $manifest.archives) {
    if ($archive.sha256 -notmatch '^[0-9a-f]{64}$' -or $archive.url -notmatch '^https://') { throw "Invalid archive manifest entry: $($archive.file)" }
}
foreach ($source in $manifest.sources) {
    if ($source.commit -notmatch '^[0-9a-f]{40}$') { throw "Unpinned source: $($source.directory)" }
}
$sourceManifest = Get-Content -LiteralPath "$PSScriptRoot/source-archives.json" -Raw | ConvertFrom-Json
$supplements = Get-Content -LiteralPath "$PSScriptRoot/source-supplements.json" -Raw | ConvertFrom-Json
foreach ($archive in (@($sourceManifest.archives) + @($sourceManifest.tools) + @($supplements.archives))) {
    if ($archive.sha256 -notmatch '^[0-9a-f]{64}$' -or $archive.url -notmatch '^https://') {
        throw "Invalid source archive manifest entry: $($archive.file)"
    }
}
$tracked = & git -C $script:RepositoryRoot ls-files
if ($LASTEXITCODE) { throw 'Could not inspect tracked files' }
foreach ($path in $tracked) {
    if ($path -match '^(deps|dist|portable|build[^/]*|network-test|ui-test)/' -or
        $path -match '(?i)(^|/)Data Files/|\.(esm|esp|bsa|ess|omwsave|pid|log)$') {
        throw "Private/generated artifact is tracked: $path"
    }
}
Write-Output 'PowerShell syntax, release metadata, pinned dependencies and tracked-file exclusions passed.'
