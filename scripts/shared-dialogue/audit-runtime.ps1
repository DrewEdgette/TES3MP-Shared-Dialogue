param([string]$DependenciesPath, [string]$BuildPath, [string]$OutputPath)
. "$PSScriptRoot/common.ps1"
Initialize-BuildPaths $DependenciesPath $BuildPath
Initialize-VisualStudio
$files = Get-RuntimeLibraryMap
$files['tes3mp.exe'] = Join-Path $script:Build 'Release/tes3mp.exe'
$files['tes3mp-server.exe'] = Join-Path $script:Build 'Release/tes3mp-server.exe'
$supplied = @{}
foreach ($name in $files.Keys) { $supplied[[IO.Path]::GetFileName($name).ToLower()] = $name }
$windowsLibraries = @('advapi32.dll','bcrypt.dll','gdi32.dll','imm32.dll','kernel32.dll','msvcrt.dll',
    'ole32.dll','oleaut32.dll','opengl32.dll','setupapi.dll','shell32.dll','user32.dll',
    'version.dll','winmm.dll','ws2_32.dll')
$report = @()
foreach ($name in ($files.Keys | Sort-Object)) {
    if (!(Test-Path -LiteralPath $files[$name])) { throw "Missing runtime file: $name" }
    $output = & dumpbin.exe /nologo /dependents $files[$name]
    if ($LASTEXITCODE) { throw "Cannot inspect runtime imports: $name" }
    $imports = @()
    foreach ($line in $output) {
        if ($line -notmatch '^\s+([\w.-]+\.dll)\s*$') { continue }
        $import = $Matches[1].ToLower()
        $kind = if ($supplied.ContainsKey($import)) { 'included' }
            elseif ($import -match '^(api-ms-win-|ext-ms-win-)' -or $windowsLibraries -contains $import) { 'Windows' }
            elseif ($import -match '^(msvcp140|vcruntime140(_1)?)\.dll$') { 'Microsoft Visual C++ x64 runtime' }
            else { throw "$name imports an unaccounted-for library: $import" }
        $imports += [ordered]@{name=$import;providedBy=$kind}
    }
    $report += [ordered]@{path=$name;sha256=(Get-FileHash -LiteralPath $files[$name] -Algorithm SHA256).Hash.ToLower();imports=$imports}
}
if (!$OutputPath) { $OutputPath = Join-Path $script:Build 'runtime-dependencies.json' }
[IO.File]::WriteAllText($OutputPath,($report | ConvertTo-Json -Depth 5) + "`n",(New-Object Text.UTF8Encoding $false))
Write-Output "Runtime import audit passed for $($report.Count) binaries: $OutputPath"
