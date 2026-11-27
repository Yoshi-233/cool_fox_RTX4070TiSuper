$ErrorActionPreference = 'Stop'
$stage = Join-Path $env:RUNNER_TEMP 'rtx-package'
$extract = Join-Path $env:RUNNER_TEMP 'rtx clean extraction'
$out = Join-Path $env:RUNNER_TEMP 'rtx-artifacts'
$null = New-Item -ItemType Directory $stage, $extract, $out
$null = New-Item -ItemType Directory (Join-Path $stage 'scripts'), (Join-Path $stage 'docs')
$runner = 'victory-3d-rtx-pareto-residency.exe'
Copy-Item 'target/x86_64-pc-windows-msvc/release/victory.exe' (Join-Path $stage $runner)
Copy-Item 'Play-VIctory.cmd','LICENSE','README.md','victory.example.toml' $stage
Copy-Item 'scripts/watch.ps1','scripts/PerformancePanel.cs' (Join-Path $stage 'scripts')
Copy-Item 'docs/windows-monitor.md','docs/pc-controls.md','docs/asset-policy.md' (Join-Path $stage 'docs')
$env:GITHUB_SHA | Set-Content -Encoding ascii (Join-Path $stage 'SOURCE-COMMIT.txt')
$archive = Join-Path $out 'VIctory-RTX-Windows-x64.zip'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $archive
Expand-Archive -LiteralPath $archive -DestinationPath $extract
Push-Location $extract
try {
    $version = & ".\$runner" --version
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^victory ') { throw "Unexpected version output: $version" }
    & ".\$runner" inspect ".\$runner"
    if ($LASTEXITCODE -ne 0) { throw 'The packaged runner failed to inspect its own PE image' }
    $env:VICTORY_GAME_DIR = Join-Path $extract 'absent game directory'
    & .\Play-VIctory.cmd pareto-residency
    if ($LASTEXITCODE -ne 2) { throw 'Unexpected launcher exit code for a missing title' }
    Add-Type -Path '.\scripts\PerformancePanel.cs' -ReferencedAssemblies @(
        'System.dll', 'System.Drawing.dll', 'System.Windows.Forms.dll', 'System.Web.Extensions.dll')
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $extract 'scripts\watch.ps1'), [ref]$null, [ref]$parseErrors)
    if ($parseErrors.Count) { throw $parseErrors[0] }
    Write-Host "Clean extraction passed for $version at $env:GITHUB_SHA"
} finally {
    Pop-Location
}
Get-FileHash -Algorithm SHA256 $archive
# The last native command exercised the launcher's expected error path.
exit 0
