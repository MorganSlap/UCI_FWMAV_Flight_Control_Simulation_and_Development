# Refresh the runtime in Git after generating, rebuilding and verifying a plant.
# This never replaces the development build or changes MATLAB models.
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'native-manifest.ps1')
$build = Join-Path $PSScriptRoot 'build'
$manifestPath = Join-Path $build 'manifest.json'
if (!(Test-Path -LiteralPath $manifestPath)) { throw 'Rebuild with DesktopSIL/build.ps1 before publishing the runtime.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$current = Get-DesktopSourceHashes
if (@($manifest.sources.PSObject.Properties).Count -ne $current.Count) { throw 'Build inputs changed. Rebuild before publishing.' }
foreach ($key in $current.Keys) {
    if ($manifest.sources.$key -ne $current[$key]) { throw "Source changed since the build: $key. Rebuild and verify before publishing." }
}
foreach ($item in $manifest.files.PSObject.Properties) {
    if ((Get-FileHash -LiteralPath (Join-Path $build $item.Name) -Algorithm SHA256).Hash -ne $item.Value) { throw "Build file changed since the build: $($item.Name). Rebuild before publishing." }
}
$destination = Join-Path $PSScriptRoot 'runtime/windows-x64'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
foreach ($name in @('hover_desktop_sil.exe','cygwin1.dll','cyggcc_s-seh-1.dll','manifest.json')) {
    Copy-Item -LiteralPath (Join-Path $build $name) -Destination (Join-Path $destination $name) -Force
}
Write-Host 'Packaged native runtime updated. Run tests/verify_portable.py, then include runtime/windows-x64 in your commit.'
