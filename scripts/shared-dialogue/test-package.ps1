param([Parameter(Mandatory=$true)][string]$PackagePath, [string]$DependenciesPath, [string]$BuildPath)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Join-Path $script:Build ('package-tests/' + [Guid]::NewGuid().ToString('N'))
$fresh = Join-Path $root 'fresh'
New-Item -ItemType Directory -Force -Path $fresh | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory([IO.Path]::GetFullPath($PackagePath), $fresh)
$script:checks = 0
function Check([bool]$Condition, [string]$Message) {
    if (!$Condition) { throw "Package check failed: $Message" }
    $script:checks++
}
function Write-TestFile([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding $false))
}
$manifest = @(Get-Content -LiteralPath "$fresh/FILE-MANIFEST.json" -Raw | ConvertFrom-Json)
foreach ($entry in $manifest) {
    Check ((Get-FileHash -LiteralPath (Join-Path $fresh $entry.path)).Hash -eq $entry.sha256) "archive hash: $($entry.path)"
    Check ($entry.path -notmatch '^(user|Data Files)/|(?i)\.(esm|esp|bsa|ess|omwsave|log|pid)$') "no private data: $($entry.path)"
}
foreach ($relative in @('tes3mp.exe','tes3mp-server.exe','openmw-iniimporter.exe','defaults.bin',
    'openmw-launcher.exe','openmw-wizard.exe','tes3mp-browser.exe','platforms/qwindows.dll',
    'resources/mygui/openmw_dialogue_window.layout','resources/mygui/RussoOne-OFL.txt',
    'server/scripts/serverCore.lua','server/lib/io2.dll','server/data/requiredDataFiles.json',
    'openmw.cfg','tes3mp-client-default.cfg','tes3mp-server-default.cfg')) {
    Check (Test-Path -LiteralPath "$fresh/$relative") "standard TES3MP payload: $relative"
}
Check (!(Test-Path -LiteralPath "$fresh/START.cmd")) 'no custom launcher'
Check (!(Test-Path -LiteralPath "$fresh/tes3mp-portable.txt")) 'normal Windows configuration mode by default'
foreach ($directory in @('player','world','cell','recordstore')) {
    $private = @(Get-ChildItem -LiteralPath "$fresh/server/data/$directory" -File -Recurse | Where-Object Name -ne '.gitkeep')
    Check ($private.Count -eq 0) "no bundled campaign data in $directory"
}
# Exercise the documented side-by-side copy with disposable custom files.
$old = Join-Path $root 'existing'
$protected = @('openmw.cfg','tes3mp-client-default.cfg','tes3mp-server-default.cfg',
    'server/scripts/config.lua','server/lib/custom.dll','server/data/player/player.json',
    'server/data/world/world.json','server/data/requiredDataFiles.json','user/settings.cfg',
    'user/openmw.cfg','user/saves/save.omwsave','tes3mp-portable.txt')
$before = @{}
foreach ($relative in $protected) {
    Write-TestFile "$old/$relative" "Original personal contents: $relative"
    $before[$relative] = (Get-FileHash -LiteralPath "$old/$relative").Hash
}
$migrated = Join-Path $root 'upgraded'
[IO.Compression.ZipFile]::ExtractToDirectory([IO.Path]::GetFullPath($PackagePath), $migrated)
$newExeHash = (Get-FileHash -LiteralPath "$migrated/tes3mp.exe").Hash
Get-ChildItem -LiteralPath $old -Filter '*.cfg' -File | Copy-Item -Destination $migrated -Force
Rename-Item -LiteralPath "$migrated/server" -NewName 'server-stock'
Copy-Item -LiteralPath "$old/server" -Destination "$migrated/server" -Recurse
Copy-Item -LiteralPath "$old/user" -Destination "$migrated/user" -Recurse
Copy-Item -LiteralPath "$old/tes3mp-portable.txt" -Destination $migrated
foreach ($relative in $protected) {
    Check ((Get-FileHash -LiteralPath "$migrated/$relative").Hash -eq $before[$relative]) "migration preserves $relative"
    Check ((Get-FileHash -LiteralPath "$old/$relative").Hash -eq $before[$relative]) "backup untouched: $relative"
}
Check ((Get-FileHash -LiteralPath "$migrated/tes3mp.exe").Hash -eq $newExeHash) 'migration keeps the new executable'

# Isolate smoke tests from the user's Documents configuration.
Write-TestFile "$fresh/tes3mp-portable.txt" 'Test fixture only; not in the ZIP.'
Write-TestFile "$fresh/user/tes3mp-server.cfg" "[General]`nlocalAddress = 127.0.0.1`nport = 25579`n[MasterServer]`nenabled = false`n"
Write-TestFile "$fresh/user/tes3mp-client.cfg" "[Master]`naddress = 127.0.0.1`nport = 25579`n"
foreach ($executable in @('tes3mp.exe','openmw-iniimporter.exe')) {
    $process = Start-Process -FilePath "$fresh/$executable" -ArgumentList '--help' -WorkingDirectory $fresh -WindowStyle Hidden -PassThru -RedirectStandardOutput "$root/$executable.out.log" -RedirectStandardError "$root/$executable.err.log"
    if (!$process.WaitForExit(15000)) { Stop-Process -Id $process.Id; throw "$executable --help did not exit" }
    Check ($process.ExitCode -eq 0) "$executable starts"
}
$server = Start-Process -FilePath "$fresh/tes3mp-server.exe" -WorkingDirectory $fresh -WindowStyle Hidden -PassThru -RedirectStandardOutput "$root/server.out.log" -RedirectStandardError "$root/server.err.log"
try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Milliseconds 100
        if ($server.HasExited) { throw "Packaged server exited: see $root/server.out.log" }
        if (Select-String -LiteralPath "$root/server.out.log" -Pattern 'Called "OnServerPostInit"' -Quiet) { $ready = $true; break }
    }
    Check $ready 'packaged CoreScripts server initializes'
} finally { if (!$server.HasExited) { Stop-Process -Id $server.Id; $server.WaitForExit() } }

# Exercise the shipped Windows backend. Qt 5.15's offscreen QMessageBox path
# crashes during first-run prompting, so it is not a valid launcher smoke test.
# All settings are isolated above and the browser points only to localhost.
foreach ($executable in @('openmw-launcher.exe','openmw-wizard.exe','tes3mp-browser.exe')) {
    $process = Start-Process -FilePath "$fresh/$executable" -WorkingDirectory $fresh -WindowStyle Hidden -PassThru -RedirectStandardOutput "$root/$executable.out.log" -RedirectStandardError "$root/$executable.err.log"
    try {
        Check (!$process.WaitForExit(2000)) "$executable stays running with packaged Qt libraries"
        $errors = Get-Content -LiteralPath "$root/$executable.err.log" -Raw
        Check (!$errors -or $errors -notmatch 'Cannot load library|could not find|could not be initialized|ERROR:') "$executable dependency startup"
    } finally { if (!$process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() } }
}
Write-Output "Passed $script:checks package checks. Fixtures and logs: $root"
