param([string]$DependenciesPath, [string]$BuildPath, [string]$RuntimePath)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
$release = Join-Path $script:Build 'Release'
$runtime = if ($RuntimePath) { [IO.Path]::GetFullPath($RuntimePath) } else { Join-Path $script:Build 'runtime' }
New-Item -ItemType Directory -Force -Path $runtime | Out-Null
Set-Content -LiteralPath "$runtime/tes3mp-portable.txt" -Value 'Local Shared Dialogue runtime; user files stay beside this executable.'
foreach ($name in @('tes3mp.exe','tes3mp-server.exe','openmw-iniimporter.exe','defaults.bin',
    'gamecontrollerdb.txt','tes3mp-client-default.cfg','tes3mp-server-default.cfg','openmw.cfg')) {
    if ($name -eq 'openmw.cfg' -and (Test-Path -LiteralPath "$runtime/$name")) { continue }
    Copy-Item -LiteralPath "$release/$name" -Destination $runtime -Force
}
Copy-Item -LiteralPath "$release/resources" -Destination $runtime -Recurse -Force
Copy-FileMap (Get-RuntimeLibraryMap) $runtime
$server = Join-Path $runtime 'server'
New-Item -ItemType Directory -Force -Path $server | Out-Null
foreach ($directory in @('scripts','lib','data')) {
    if ($directory -eq 'data' -and (Test-Path -LiteralPath "$server/data")) { continue }
    Copy-Item -LiteralPath "$script:Dependencies/CoreScripts/$directory" -Destination $server -Recurse -Force
}
Copy-Item -LiteralPath "$script:Dependencies/Lua-io2/build/Release/io2.dll" -Destination "$server/lib" -Force
New-Item -ItemType Directory -Force -Path "$runtime/user" | Out-Null
if (!(Test-Path -LiteralPath "$runtime/user/tes3mp-server.cfg")) {
    Set-Content -LiteralPath "$runtime/user/tes3mp-server.cfg" -Value @'
[General]
localAddress = 127.0.0.1
port = 25575
hostname = Shared Dialogue local development
[MasterServer]
enabled = false
[Dialogue]
radius = 420
'@
}
# Upstream shares its networking/game settings map and saves user overrides into
# settings.cfg. Keep this local fixture's connection defaults in the default file
# to avoid duplicating user overrides on the next launch.
$clientDefaults = Get-Content -LiteralPath "$runtime/tes3mp-client-default.cfg" -Raw
$clientDefaults = $clientDefaults.Replace('destinationAddress = localhost','destinationAddress = 127.0.0.1').Replace('port = 25565','port = 25575').Replace('logLevel = 0','logLevel = 1')
[IO.File]::WriteAllText("$runtime/tes3mp-client-default.cfg", $clientDefaults, (New-Object Text.UTF8Encoding $false))
Copy-Item -LiteralPath "$script:RepositoryRoot/LICENSE" -Destination $runtime -Force
Write-Output "Local runtime: $runtime"
