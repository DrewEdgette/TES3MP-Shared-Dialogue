param([string]$DependenciesPath, [string]$BuildPath, [int]$Jobs = 4)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
Initialize-VisualStudio
$testBuild = Join-Path $script:Build 'dialogue-tests'
Invoke-Checked cmake @('-S',"$script:RepositoryRoot/tests/shared-dialogue",'-B',$testBuild,
    '-G','Visual Studio 17 2022','-A','x64',"-DCMAKE_GENERATOR_INSTANCE=$script:VisualStudio",
    "-DDIALOGUE_DEPS=$script:Dependencies")
Invoke-Checked cmake @('--build',$testBuild,'--config','Release','--parallel',"$Jobs")
Invoke-Checked ctest @('--test-dir',$testBuild,'-C','Release','--output-on-failure')
& "$PSScriptRoot/test-network.ps1" -DependenciesPath $script:Dependencies -BuildPath $script:Build
& "$PSScriptRoot/test-runtime.ps1" -DependenciesPath $script:Dependencies -BuildPath $script:Build -Jobs $Jobs
