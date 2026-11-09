# Shared by build.ps1 and publish-runtime.ps1. Hash text with normalized newlines
# so a Windows ZIP download and a Git checkout describe the same source.
function Get-DesktopSourceHashes {
    $repo = Split-Path $PSScriptRoot
    $paths = @((Join-Path $PSScriptRoot 'build.ps1'), (Join-Path $PSScriptRoot 'native-manifest.ps1'), (Join-Path $repo 'Betaflight/build-host.ps1'))
    foreach ($directory in @('native', 'generated/hover_plant_sil_ert_rtw', 'generated/hover_linear_sil_ert_rtw')) {
        $paths += Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot $directory) -File | Where-Object { $_.Extension -in @('.c','.h','.inc') } | ForEach-Object FullName
    }
    $paths += Get-ChildItem -LiteralPath (Join-Path $repo 'Betaflight/host') -File | Where-Object { $_.Extension -in @('.c','.h','.ps1') } | ForEach-Object FullName
    $hashes = [ordered]@{}
    foreach ($path in ($paths | Sort-Object)) {
        $key = $path.Substring($repo.Length + 1).Replace('\','/')
        $data = [Text.Encoding]::UTF8.GetBytes([IO.File]::ReadAllText($path).Replace("`r`n","`n"))
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hashes[$key] = [BitConverter]::ToString($sha.ComputeHash($data)).Replace('-','').ToLowerInvariant() }
        finally { $sha.Dispose() }
    }
    return $hashes
}

function Write-DesktopNativeManifest([string]$Folder, [string]$MatlabRoot) {
    $repo = Split-Path $PSScriptRoot
    $files = [ordered]@{}
    foreach ($name in @('hover_desktop_sil.exe','cygwin1.dll','cyggcc_s-seh-1.dll')) {
        $files[$name] = (Get-FileHash -LiteralPath (Join-Path $Folder $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    $manifest = [ordered]@{
        format = 1
        platform = 'windows-x64'
        built_utc = [DateTime]::UtcNow.ToString('o')
        firmware_commit = 'c78d9e7bd24ef60f4324dffde11df26c53d4f29f'
        matlab_release = Split-Path $MatlabRoot -Leaf
        compiler = 'Cygwin GCC 13.5.0; -O2 -fno-fast-math -ffp-contract=off'
        files = $files
        sources = Get-DesktopSourceHashes
    }
    $json = $manifest | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText((Join-Path $Folder 'manifest.json'), ($json + "`n"), [Text.UTF8Encoding]::new($false))
}
