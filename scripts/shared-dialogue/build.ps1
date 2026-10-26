param([string]$DependenciesPath, [string]$BuildPath, [int]$Jobs = 4)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
Initialize-VisualStudio
Assert-ReleaseVersion
$d = $script:Dependencies.Replace('\','/')
$env:MYGUI_HOME = "$d/MyGUI-3.4.0-msvc2019-win64"
$env:FFMPEG_HOME = "$d/built"
$env:SDL2DIR = "$d/SDL2-2.0.12"
$arguments = @('-S',$script:RepositoryRoot,'-B',$script:Build,'-G','Visual Studio 17 2022','-A','x64',
    '-U','OSG*','-U','OPENTHREADS*','-U','OPENSCENEGRAPH*','-U','FFmpeg_*',
    "-DCMAKE_GENERATOR_INSTANCE=$script:VisualStudio",
    '-DBUILD_OPENMW=ON','-DBUILD_LAUNCHER=OFF','-DBUILD_BROWSER=OFF','-DBUILD_OPENCS=OFF',
    '-DBUILD_WIZARD=OFF','-DBUILD_ESMTOOL=OFF','-DBUILD_BSATOOL=OFF','-DBUILD_NIFTEST=OFF',
    '-DBUILD_MWINIIMPORTER=ON','-DBUILD_UNITTESTS=OFF','-DENABLE_BREAKPAD=OFF','-DOPENMW_MP_BUILD=ON',
    '-DBOOST_STATIC=ON','-DBoost_COMPILER=-vc142',"-DCMAKE_INSTALL_PREFIX=$script:Build/install",
    "-DBOOST_ROOT=$d/boost-prebuilt/app","-DBOOST_LIBRARYDIR=$d/boost-prebuilt/app/lib64-msvc-14.2",
    "-DBoost_INCLUDE_DIR=$d/boost-prebuilt/app","-DOSG_DIR=$d/built",
    "-DBULLET_ROOT=$d/Bullet-2.89-msvc2015-win64-double","-DLZ4_INCLUDE_DIR=$d/include","-DLZ4_LIBRARY=$d/lib/liblz4.lib",
    "-DRakNet_INCLUDES=$d/CrabNet/include","-DRakNet_LIBRARY_RELEASE=$d/CrabNet/build/lib/Release/RakNetLibStatic.lib",
    "-DRakNet_LIBRARY_DEBUG=$d/CrabNet/build/lib/Release/RakNetLibStatic.lib",
    "-DLuaJit_INCLUDE_DIR=$d/LuaJIT/src","-DLuaJit_LIBRARY=$d/LuaJIT/src/lua51.lib",
    "-DOPENAL_INCLUDE_DIR=$d/built/include/AL",
    "-DOPENAL_LIBRARY=$d/built/lib/OpenAL32.lib","-DCMAKE_PREFIX_PATH=$d/built;$d")
Invoke-Checked cmake $arguments
Invoke-Checked cmake @('--build',$script:Build,'--config','Release','--target','tes3mp','tes3mp-server','openmw-iniimporter','--parallel',"$Jobs")
