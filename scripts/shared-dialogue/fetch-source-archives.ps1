param([string]$DependenciesPath, [string]$BuildPath)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
$manifest = Get-Content -LiteralPath "$PSScriptRoot/source-archives.json" -Raw | ConvertFrom-Json
$downloads = Join-Path $script:Dependencies 'downloads'
$sources = Join-Path $script:Dependencies 'source'
New-Item -ItemType Directory -Force -Path $downloads,$sources | Out-Null
foreach ($archive in (@($manifest.archives) + @($manifest.tools))) {
    $extractRoot = if ($archive.buildToolOnly) { Join-Path $script:Dependencies 'tools/msys-make' } else { $sources }
    New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
    $file = Join-Path $downloads $archive.file
    if (!(Test-Path -LiteralPath $file)) {
        Invoke-Checked curl.exe @('--fail','--location','--retry','3','--silent','--show-error',
            $archive.url,'--output',($file + '.part'))
        if ((Get-FileHash -LiteralPath ($file + '.part') -Algorithm SHA256).Hash -ne $archive.sha256) {
            throw "Source download hash mismatch: $($archive.file)"
        }
        Move-Item -LiteralPath ($file + '.part') -Destination $file
    }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $archive.sha256) {
        throw "Source archive hash mismatch: $($archive.file)"
    }
    $probe = if ($archive.buildToolOnly) { Join-Path $extractRoot 'usr/bin/make.exe' } else { Join-Path $sources $archive.directory }
    if (!(Test-Path -LiteralPath $probe)) {
        Invoke-Checked tar.exe @('-xf',$file,'-C',$extractRoot)
    }
    Write-Output "Verified source: $($archive.name) $($archive.version)"
}
