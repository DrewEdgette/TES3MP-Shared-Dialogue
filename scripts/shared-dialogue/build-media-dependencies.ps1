param([string]$DependenciesPath, [string]$BuildPath, [int]$Jobs = 4,
    [ValidateSet('All','Graphics','FFmpeg')][string]$Component = 'All')
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
Initialize-VisualStudio
$manifest = Get-Content -LiteralPath "$PSScriptRoot/source-archives.json" -Raw | ConvertFrom-Json
$prefix = Join-Path $script:Dependencies 'built'
$buildRoot = Join-Path $script:Dependencies 'source-build'
New-Item -ItemType Directory -Force -Path $prefix,$buildRoot | Out-Null
function Get-Source([string]$Name) {
    $entry = $manifest.archives | Where-Object name -eq $Name
    if (!$entry) { throw "Missing source manifest entry: $Name" }
    Join-Path $script:Dependencies "source/$($entry.directory)"
}
function Build-CMakeDependency([string]$Name, [string[]]$Options) {
    $directory = Join-Path $buildRoot $Name
    Write-Output "Building $Name from pinned source"
    Invoke-Checked cmake (@('-S',(Get-Source $Name),'-B',$directory,'-G','Visual Studio 17 2022','-A','x64',
        "-DCMAKE_GENERATOR_INSTANCE=$script:VisualStudio","-DCMAKE_INSTALL_PREFIX=$prefix",
        "-DCMAKE_PREFIX_PATH=$prefix",'-DCMAKE_FIND_USE_PACKAGE_REGISTRY=OFF',
        '-DCMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY=OFF','-DBUILD_SHARED_LIBS=ON','-DBUILD_TESTING=OFF') + $Options)
    Invoke-Checked cmake @('--build',$directory,'--config','Release','--parallel',"$Jobs")
    Invoke-Checked cmake @('--install',$directory,'--config','Release')
}
if ($Component -ne 'FFmpeg') {
    Build-CMakeDependency 'zlib' @('-DZLIB_BUILD_STATIC=OFF','-DZLIB_BUILD_TESTING=OFF')
    # FFmpeg's MSVC linker wrapper spells -lz as zlib.lib.
    Copy-Item -LiteralPath "$prefix/lib/z.lib" -Destination "$prefix/lib/zlib.lib" -Force
    Build-CMakeDependency 'libpng' @('-DPNG_SHARED=ON','-DPNG_STATIC=OFF','-DPNG_TESTS=OFF','-DPNG_TOOLS=OFF',
        "-DZLIB_INCLUDE_DIR=$prefix/include","-DZLIB_LIBRARY=$prefix/lib/z.lib")
    Build-CMakeDependency 'libjpeg-turbo' @('-DENABLE_SHARED=ON','-DENABLE_STATIC=OFF','-DWITH_TURBOJPEG=OFF','-DWITH_SIMD=OFF')
    Build-CMakeDependency 'freetype' @('-DFT_DISABLE_ZLIB=ON','-DFT_DISABLE_BZIP2=ON',
        '-DFT_DISABLE_PNG=ON','-DFT_DISABLE_HARFBUZZ=ON','-DFT_DISABLE_BROTLI=ON')
    $osgOptions = @('-DBUILD_OSG_APPLICATIONS=OFF','-DBUILD_OSG_EXAMPLES=OFF',
        '-DBUILD_OSG_PLUGINS_BY_DEFAULT=OFF','-DOSG_MSVC_VERSIONED_DLL=OFF',
        '-DDYNAMIC_OPENSCENEGRAPH=ON','-DDYNAMIC_OPENTHREADS=ON','-DOSG_TEXT_USE_FONTCONFIG=OFF',
        '-DCMAKE_DISABLE_FIND_PACKAGE_CURL=ON','-DCMAKE_DISABLE_FIND_PACKAGE_FFmpeg=ON',
        "-DZLIB_INCLUDE_DIR=$prefix/include","-DZLIB_LIBRARY=$prefix/lib/z.lib",
        "-DPNG_PNG_INCLUDE_DIR=$prefix/include","-DPNG_LIBRARY_RELEASE=$prefix/lib/libpng16.lib",
        "-DJPEG_INCLUDE_DIR=$prefix/include","-DJPEG_LIBRARY_RELEASE=$prefix/lib/jpeg.lib",
        "-DFREETYPE_INCLUDE_DIR_freetype2=$prefix/include/freetype2",
        "-DFREETYPE_INCLUDE_DIR_ft2build=$prefix/include/freetype2",
        "-DFREETYPE_LIBRARY_RELEASE=$prefix/lib/freetype.lib")
    foreach ($plugin in @('BMP','DDS','FREETYPE','JPEG','OSG','PNG','TGA')) { $osgOptions += "-DBUILD_OSG_PLUGIN_$plugin=ON" }
    Build-CMakeDependency 'openscenegraph' $osgOptions
    Build-CMakeDependency 'openal-soft' @('-DALSOFT_UTILS=OFF','-DALSOFT_EXAMPLES=OFF','-DALSOFT_TESTS=OFF',
        '-DALSOFT_CONFIG=OFF','-DALSOFT_HRTF_DEFS=OFF','-DALSOFT_AMBDEC_PRESETS=OFF',
        '-DALSOFT_BUILD_ROUTER=OFF','-DALSOFT_BACKEND_SDL2=OFF','-DALSOFT_BACKEND_PORTAUDIO=OFF')
}
if ($Component -ne 'Graphics') {
    # FFmpeg's makefiles need a path without spaces. NTFS short paths keep every
    # generated file inside the chosen dependency directory even in spaced paths.
    if (!('SharedDialogue.BuildPaths' -as [type])) {
        Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
namespace SharedDialogue { public static class BuildPaths {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern uint GetShortPathName(string path, StringBuilder result, uint size);
} }
'@
    }
    function Get-BuildShortPath([string]$Path) {
        $buffer = New-Object Text.StringBuilder 32768
        if (![SharedDialogue.BuildPaths]::GetShortPathName($Path,$buffer,32768)) { throw "Cannot resolve build path: $Path" }
        $result = $buffer.ToString()
        if ($result.Contains(' ')) { throw 'FFmpeg needs a checkout path without spaces, or enabled NTFS short names.' }
        $result.Replace('\','/')
    }
    $gitRoot = Split-Path (Split-Path (Get-Command git.exe).Source -Parent) -Parent
    $bash = Join-Path $gitRoot 'usr/bin/bash.exe'
    if (!(Test-Path -LiteralPath $bash)) { throw 'Git for Windows with its bundled Bash is required.' }
    $ffBuild = Join-Path $buildRoot 'ffmpeg'
    New-Item -ItemType Directory -Force -Path $ffBuild | Out-Null
    # A disposable source copy keeps generated files out of the source archive
    # tree and keeps FFmpeg's SRC_PATH relative.
    if (!(Test-Path -LiteralPath "$ffBuild/configure")) {
        Get-ChildItem -LiteralPath (Get-Source 'ffmpeg') -Force | Copy-Item -Destination $ffBuild -Recurse -Force
    }
    $ffmpegVersion = ($manifest.archives | Where-Object name -eq 'ffmpeg').version
    if ((Get-Content -LiteralPath "$ffBuild/RELEASE" -Raw).Trim() -ne $ffmpegVersion) {
        throw "FFmpeg's existing build copy is a different version. Use a fresh DependenciesPath for the updated source manifest."
    }
    $env:SD_SHELL = Get-BuildShortPath (Join-Path $gitRoot 'usr/bin/sh.exe')
    $env:SD_VC_BIN = Get-BuildShortPath (Split-Path (Get-Command cl.exe).Source -Parent)
    Invoke-Checked $bash @('--noprofile','--norc',"$PSScriptRoot/build-ffmpeg.sh",
        (Get-BuildShortPath (Get-Source 'ffmpeg')),(Get-BuildShortPath $ffBuild),
        (Get-BuildShortPath $prefix),(Get-BuildShortPath "$script:Dependencies/tools/msys-make/usr/bin/make.exe"),"$Jobs")
    # FFmpeg installs MSVC import libraries beside its DLLs. CMake's finder
    # expects them in lib; keep the installed originals and copy the five imports.
    foreach ($library in @('avcodec','avformat','avutil','swscale','swresample')) {
        Copy-Item -LiteralPath "$prefix/bin/$library.lib" -Destination "$prefix/lib/$library.lib" -Force
    }
}
