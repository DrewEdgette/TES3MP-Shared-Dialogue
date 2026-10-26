Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))

function Invoke-Checked {
    param([string]$Program, [string[]]$Arguments)
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}

function Initialize-BuildPaths {
    param([string]$DependenciesPath, [string]$BuildPath)
    if (!$DependenciesPath) { $DependenciesPath = Join-Path $script:RepositoryRoot 'deps' }
    if (!$BuildPath) { $BuildPath = Join-Path $script:RepositoryRoot 'build-shared-dialogue' }
    $script:Dependencies = [IO.Path]::GetFullPath($DependenciesPath)
    $script:Build = [IO.Path]::GetFullPath($BuildPath)
    $temporary = Join-Path $script:Build 'temp'
    New-Item -ItemType Directory -Force -Path $temporary | Out-Null
    $env:TEMP = $temporary
    $env:TMP = $temporary
}

function Find-SevenZip {
    $command = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $standard = Join-Path $env:ProgramFiles '7-Zip/7z.exe'
    if (Test-Path -LiteralPath $standard) { return $standard }
    throw '7-Zip is required. Install it yourself or add 7z.exe to PATH.'
}

function Initialize-VisualStudio {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (!(Test-Path -LiteralPath $vswhere)) { throw 'Visual Studio 2022 C++ tools and vswhere are required.' }
    $install = & $vswhere -latest -products '*' -version '[17.0,18.0)' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($LASTEXITCODE -ne 0 -or !$install) { throw 'Visual Studio 2022 with the Desktop development with C++ workload was not found.' }
    $script:VisualStudio = [string]($install | Select-Object -First 1)
    $compiler = Get-Command cl.exe -ErrorAction SilentlyContinue
    if ($compiler -and $env:VSCMD_ARG_TGT_ARCH -eq 'x64' -and
        $compiler.Source.StartsWith(($script:VisualStudio.TrimEnd('\') + '\VC\'), [StringComparison]::OrdinalIgnoreCase)) {
        return
    }
    $devCmd = Join-Path $script:VisualStudio 'Common7/Tools/VsDevCmd.bat'
    # Import the toolchain environment without changing persistent system settings.
    $environmentLines = & cmd.exe /d /s /c "`"$devCmd`" -no_logo -arch=x64 -host_arch=x64 >nul && set"
    if ($LASTEXITCODE -ne 0) { throw 'Could not initialize the Visual Studio environment.' }
    foreach ($line in $environmentLines) {
        if ($line -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process') }
    }
}

function Read-ReleaseInfo {
    Get-Content -LiteralPath (Join-Path $PSScriptRoot 'release.json') -Raw | ConvertFrom-Json
}

function Assert-ReleaseVersion {
    $release = Read-ReleaseInfo
    $header = Get-Content -LiteralPath (Join-Path $script:RepositoryRoot 'components/openmw-mp/Version.hpp') -Raw
    if (!$header.Contains(('"{0}"' -f $release.engineVersion)) -or
        $header -notmatch ('(?m)^#define TES3MP_PROTO_VERSION ' + $release.protocol + '\s*$')) {
        throw 'release.json and components/openmw-mp/Version.hpp disagree.'
    }
}

function Get-RuntimeLibraryMap {
    $files = @{
        'MyGUIEngine.dll' = Join-Path $script:Dependencies 'MyGUI-3.4.0-msvc2019-win64/bin/RelWithDebInfo/MyGUIEngine.dll'
        'SDL2.dll' = Join-Path $script:Dependencies 'SDL2-2.0.12/lib/x64/SDL2.dll'
        'liblz4.dll' = Join-Path $script:Dependencies 'bin/Release/liblz4.dll'
    }
    foreach ($name in @('OpenThreads','osg','osgDB','osgViewer','osgText','osgGA',
        'osgParticle','osgUtil','osgFX','osgShadow','osgAnimation','freetype','jpeg62',
        'libpng16','z','OpenAL32','avcodec-58','avformat-58','avutil-56','swresample-3','swscale-5')) {
        $files[$name + '.dll'] = Join-Path $script:Dependencies "built/bin/$name.dll"
    }
    $plugins = Join-Path $script:Dependencies 'built/bin/osgPlugins-3.6.5'
    foreach ($name in @('bmp','dds','freetype','jpeg','osg','png','serializers_osg','tga')) {
        $files["osgPlugins-3.6.5/osgdb_$name.dll"] = Join-Path $plugins "osgdb_$name.dll"
    }
    $files['lua51.dll'] = Join-Path $script:Dependencies 'LuaJIT/src/lua51.dll'
    return $files
}

function Copy-FileMap {
    param([hashtable]$Files, [string]$Destination)
    foreach ($name in $Files.Keys) {
        $target = Join-Path $Destination $name
        New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
        Copy-Item -LiteralPath $Files[$name] -Destination $target -Force
    }
}
