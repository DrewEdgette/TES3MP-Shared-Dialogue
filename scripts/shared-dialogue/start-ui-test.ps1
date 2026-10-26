param([string]$DependenciesPath, [string]$BuildPath)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
$fixture = Join-Path $script:Build 'ui-test'
New-Item -ItemType Directory -Force -Path $fixture,"$fixture/server/scripts","$fixture/resources" | Out-Null
Copy-Item -LiteralPath "$script:Build/Release/tes3mp-server.exe" -Destination $fixture -Force
Copy-Item -LiteralPath "$script:Dependencies/LuaJIT/src/lua51.dll" -Destination $fixture -Force
Copy-Item -LiteralPath "$script:Build/Release/resources/version" -Destination "$fixture/resources/version" -Force
Copy-Item -LiteralPath "$script:RepositoryRoot/tests/shared-dialogue/game-server.lua" -Destination "$fixture/server/scripts/server.lua" -Force
Set-Content -LiteralPath "$fixture/tes3mp-portable.txt" -Value 'Disposable local UI fixture'
Set-Content -LiteralPath "$fixture/openmw.cfg" -Value 'resources=resources'
Set-Content -LiteralPath "$fixture/tes3mp-server-default.cfg" -Value @'
[General]
localAddress = 127.0.0.1
port = 25577
maximumPlayers = 4
hostname = Shared Dialogue UI test
logLevel = 1
password =
[Plugins]
home = ./server
plugins = server.lua
[MasterServer]
enabled = false
[Dialogue]
radius = 420
'@
$serverProcess = Start-Process -FilePath "$fixture/tes3mp-server.exe" -WorkingDirectory $fixture -WindowStyle Hidden -PassThru -RedirectStandardOutput "$fixture/server.out.log" -RedirectStandardError "$fixture/server.err.log"
Write-Output "Local UI server PID $($serverProcess.Id); commands: $fixture/command.txt"
Write-Output 'Launch test clients with --connect=127.0.0.1:25577 --skip-menu'
try { $serverProcess.WaitForExit() }
finally { if (!$serverProcess.HasExited) { Stop-Process -Id $serverProcess.Id; $serverProcess.WaitForExit() } }
