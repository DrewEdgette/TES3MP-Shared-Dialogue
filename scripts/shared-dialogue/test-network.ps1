param([string]$DependenciesPath, [string]$BuildPath)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
$fixture = Join-Path $script:Build 'network-test'
New-Item -ItemType Directory -Force -Path $fixture,"$fixture/server/scripts","$fixture/resources" | Out-Null
Copy-Item -LiteralPath "$script:Build/Release/tes3mp-server.exe" -Destination $fixture -Force
Copy-Item -LiteralPath "$script:Dependencies/LuaJIT/src/lua51.dll" -Destination $fixture -Force
Copy-Item -LiteralPath "$script:RepositoryRoot/tests/shared-dialogue/server.lua" -Destination "$fixture/server/scripts/server.lua" -Force
Copy-Item -LiteralPath "$script:Build/Release/resources/version" -Destination "$fixture/resources/version" -Force
Set-Content -LiteralPath "$fixture/tes3mp-portable.txt" -Value 'Isolated network test'
Set-Content -LiteralPath "$fixture/openmw.cfg" -Value 'resources=resources'
Set-Content -LiteralPath "$fixture/tes3mp-server-default.cfg" -Value @'
[General]
localAddress = 127.0.0.1
port = 25576
maximumPlayers = 8
hostname = Shared Dialogue network test
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
$hash = (Get-Content -LiteralPath "$fixture/resources/version")[1].Trim()
$serverProcess = Start-Process -FilePath "$fixture/tes3mp-server.exe" -WorkingDirectory $fixture -WindowStyle Hidden -PassThru -RedirectStandardOutput "$fixture/server.out.log" -RedirectStandardError "$fixture/server.err.log"
try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 30; ++$attempt) {
        Start-Sleep -Milliseconds 100
        if ($serverProcess.HasExited) { throw "Test server exited: $($serverProcess.ExitCode). See $fixture/server.out.log" }
        if (Select-String -LiteralPath "$fixture/server.out.log" -Pattern 'Shared Dialogue network fixture ready' -Quiet) { $ready = $true; break }
    }
    if (!$ready) { throw "Test server did not become ready. See $fixture/server.out.log" }
    Invoke-Checked "$script:Build/dialogue-tests/Release/shared_dialogue_network_tests.exe" @($hash)
} finally {
    if (!$serverProcess.HasExited) { Stop-Process -Id $serverProcess.Id; $serverProcess.WaitForExit() }
}
