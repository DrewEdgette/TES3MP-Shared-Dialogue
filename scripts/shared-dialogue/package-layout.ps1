# Complete runtime in the standard TES3MP layout. No custom launcher or installer.
function Add-PackageTree([hashtable]$Files, [string]$Directory, [string]$Prefix) {
    if (!(Test-Path -LiteralPath $Directory -PathType Container)) { throw "Missing package directory: $Directory" }
    $directoryPath = (Get-Item -LiteralPath $Directory).FullName
    foreach ($file in Get-ChildItem -LiteralPath $directoryPath -File -Recurse -Force) {
        $relative = $file.FullName.Substring($directoryPath.Length + 1).Replace('\','/')
        $Files[$Prefix + $relative] = $file.FullName
    }
}

function Get-CompletePackageMap {
    $files = Get-RuntimeLibraryMap
    foreach ($entry in (Get-QtRuntimeLibraryMap).GetEnumerator()) { $files[$entry.Key] = $entry.Value }
    foreach ($name in @('tes3mp.exe','tes3mp-server.exe','openmw-iniimporter.exe','openmw-launcher.exe','openmw-wizard.exe','tes3mp-browser.exe','defaults.bin','gamecontrollerdb.txt')) {
        $files[$name] = Join-Path $script:Build "Release/$name"
    }
    Add-PackageTree $files "$script:Build/Release/resources" 'resources/'
    foreach ($name in @('openmw.cfg','tes3mp-client-default.cfg','tes3mp-server-default.cfg')) {
        $files[$name] = Join-Path $script:Build "Release/$name"
    }
    # Only pinned, unmodified server sources can enter a public package.
    $dependencies = Get-Content -LiteralPath "$PSScriptRoot/dependencies.json" -Raw | ConvertFrom-Json
    foreach ($name in @('CoreScripts','Lua-io2')) {
        $source = $dependencies.sources | Where-Object directory -eq $name
        $directory = Join-Path $script:Dependencies $name
        $revision = & git -C $directory rev-parse HEAD
        if ($LASTEXITCODE -or $revision -ne $source.commit) { throw "Wrong $name revision" }
        $changes = & git -C $directory status --porcelain --untracked-files=no
        if ($LASTEXITCODE -or $changes) { throw "Modified $name sources" }
    }
    $core = Join-Path $script:Dependencies 'CoreScripts'
    $paths = @(& git -C $core ls-files)
    if ($LASTEXITCODE) { throw 'Cannot enumerate CoreScripts' }
    foreach ($path in $paths) {
        if ($path -match '^(scripts|lib|data)/') { $files['server/' + $path] = Join-Path $core $path }
    }
    $files['server/lib/io2.dll'] = Join-Path $script:Dependencies 'Lua-io2/build/Release/io2.dll'
    $files['docs/shared-dialogue/licenses/CoreScripts.txt'] = Join-Path $core 'LICENSE'
    $files['docs/shared-dialogue/licenses/Lua-io2.txt'] = Join-Path $script:Dependencies 'Lua-io2/LICENSE'
    $files['docs/shared-dialogue/licenses/sol2.txt'] = Join-Path $script:Dependencies 'Lua-io2/sol2/LICENSE.txt'
    $files['resources/mygui/DejaVuFontLicense.txt'] = Join-Path $script:RepositoryRoot 'files/mygui/DejaVuFontLicense.txt'
    $files['resources/mygui/RussoOne-OFL.txt'] = Join-Path $PSScriptRoot '../../docs/shared-dialogue/licenses/RussoOne-OFL.txt'
    return $files
}
