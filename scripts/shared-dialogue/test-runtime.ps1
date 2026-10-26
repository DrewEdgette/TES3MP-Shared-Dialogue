param([string]$DependenciesPath, [string]$BuildPath, [int]$Jobs = 4, [string[]]$MediaFiles = @())
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
Initialize-VisualStudio
$directory = Join-Path $script:Build 'runtime-tests'
Invoke-Checked cmake @('-S',"$script:RepositoryRoot/tests/runtime-dependencies",'-B',$directory,
    '-G','Visual Studio 17 2022','-A','x64',"-DCMAKE_GENERATOR_INSTANCE=$script:VisualStudio",
    "-DDEPENDENCY_PREFIX=$script:Dependencies/built")
Invoke-Checked cmake @('--build',$directory,'--config','Release','--parallel',"$Jobs")
$runtime = Join-Path $directory 'Release'
Copy-FileMap (Get-RuntimeLibraryMap) $runtime
$originalPath = $env:PATH
$originalOsgPath = $env:OSG_LIBRARY_PATH
$originalAudio = $env:ALSOFT_DRIVERS
try {
    $env:PATH = "$runtime;$env:PATH"
    $env:OSG_LIBRARY_PATH = Join-Path $runtime 'osgPlugins-3.6.5'
    $env:ALSOFT_DRIVERS = 'null'
    $check = Join-Path $runtime 'runtime_dependency_checks.exe'
    Invoke-Checked $check @('images',$runtime,"$script:RepositoryRoot/files/mygui/RussoOne-Regular.ttf")
    Invoke-Checked $check @('audio')
    # A generated PCM WAV exercises decoding and resampling in CI without game data.
    $wave = Join-Path $runtime 'generated.wav'
    $stream = [IO.File]::Create($wave)
    $writer = New-Object IO.BinaryWriter $stream
    try {
        $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int]16420)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
        $writer.Write([int]16); $writer.Write([short]1); $writer.Write([short]1)
        $writer.Write([int]22050); $writer.Write([int]44100)
        $writer.Write([short]2); $writer.Write([short]16)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('data')); $writer.Write([int]16384)
        $writer.Write((New-Object byte[] 16384))
    } finally { $writer.Dispose(); $stream.Dispose() }
    Invoke-Checked $check @('media',$wave)
    Invoke-Checked $check @('media',"$runtime/roundtrip.png")
    foreach ($media in $MediaFiles) { Invoke-Checked $check @('media',[IO.Path]::GetFullPath($media)) }
} finally {
    $env:PATH = $originalPath
    $env:OSG_LIBRARY_PATH = $originalOsgPath
    $env:ALSOFT_DRIVERS = $originalAudio
}
