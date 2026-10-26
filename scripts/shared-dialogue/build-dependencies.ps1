param([string]$DependenciesPath, [string]$BuildPath, [int]$Jobs = 4)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
Initialize-VisualStudio
$crab = Join-Path $script:Dependencies 'CrabNet'
Invoke-Checked cmake @('-S',$crab,'-B',"$crab/build",'-G','Visual Studio 17 2022','-A','x64',"-DCMAKE_GENERATOR_INSTANCE=$script:VisualStudio",'-DCRABNET_ENABLE_DLL=OFF')
Invoke-Checked cmake @('--build',"$crab/build",'--config','Release','--target','RakNetLibStatic','--parallel',"$Jobs")
Push-Location (Join-Path $script:Dependencies 'LuaJIT/src')
try { Invoke-Checked cmd.exe @('/d','/c','msvcbuild.bat') } finally { Pop-Location }
$io = Join-Path $script:Dependencies 'Lua-io2'
Invoke-Checked cmake @('-S',$io,'-B',"$io/build",'-G','Visual Studio 17 2022','-A','x64',
    "-DCMAKE_GENERATOR_INSTANCE=$script:VisualStudio",
    "-DLuaJit_INCLUDE_DIR=$script:Dependencies/LuaJIT/src","-DLuaJit_LIBRARY=$script:Dependencies/LuaJIT/src/lua51.lib",
    '-DCMAKE_CXX_FLAGS=/EHsc /D_SILENCE_EXPERIMENTAL_FILESYSTEM_DEPRECATION_WARNING /utf-8')
Invoke-Checked cmake @('--build',"$io/build",'--config','Release','--parallel',"$Jobs")
& "$PSScriptRoot/build-media-dependencies.ps1" -DependenciesPath $script:Dependencies -BuildPath $script:Build -Jobs $Jobs
