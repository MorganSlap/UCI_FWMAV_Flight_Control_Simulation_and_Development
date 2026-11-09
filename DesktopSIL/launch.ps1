param([switch]$SetupOnly, [switch]$ForceManaged)
$ErrorActionPreference = 'Stop'
$build = Join-Path $PSScriptRoot 'build'
$transcriptStarted = $false
$setupLock = $null

function Get-DesktopHash([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}

function Test-DesktopPython([string]$Candidate, [switch]$Strict) {
    if (!(Test-Path -LiteralPath $Candidate)) { return $false }
    $checkArgs = @('-E', '-s', (Join-Path $PSScriptRoot 'runtime_check.py'))
    if ($Strict) { $checkArgs += '--strict' }
    try {
        & $Candidate @checkArgs *> (Join-Path $build 'python-check.log')
        return ($LASTEXITCODE -eq 0)
    } catch { return $false }
}

try {
    if (![Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64') {
        throw 'This runtime supports Intel/AMD 64-bit Windows 10/11. Windows ARM is not tested.'
    }
    New-Item -ItemType Directory -Force -Path $build | Out-Null
    try {
        $setupLock = [IO.File]::Open((Join-Path $build 'desktop-setup.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    } catch { throw 'Another Desktop SIL launcher is setting up this checkout. Wait for it to finish, then try again.' }
    Start-Transcript -Path (Join-Path $build 'desktop-setup.log') -Append | Out-Null
    $transcriptStarted = $true

    # Never install into, delete, or upgrade a developer's existing environment.
    $developerPython = Join-Path $build 'venv/Scripts/python.exe'
    $runtimeVenv = Join-Path $build 'runtime-venv'
    $runtimePython = Join-Path $runtimeVenv 'Scripts/python.exe'
    $python = $null
    if (!$ForceManaged -and (Test-DesktopPython $developerPython)) {
        Write-Host 'Using the existing development Python environment.'
        $python = $developerPython
    } elseif (Test-DesktopPython $runtimePython -Strict) {
        $python = $runtimePython
    } else {
        Write-Host 'First-run setup: downloading private Python and plotting/data libraries.'
        Write-Host 'This can take several minutes. Keep this window open. Internet access is needed once.'
        Write-Host 'System Python, PATH, MATLAB, and the development environment are not modified.'
        $bootstrap = Join-Path $build 'bootstrap'
        New-Item -ItemType Directory -Force -Path $bootstrap | Out-Null
        $uvVersion = '0.13.7'
        $uvSha256 = '0cdc5b38fe5a8168ed6a25814f5ba43c21d313dd3187314fccb37b7cec46e021'
        $archive = Join-Path $bootstrap "uv-$uvVersion.zip"
        $uvFolder = Join-Path $bootstrap "uv-$uvVersion"
        $uv = Join-Path $uvFolder 'uv.exe'
        $validArchive = (Test-Path -LiteralPath $archive) -and ((Get-DesktopHash $archive) -eq $uvSha256)
        if (!$validArchive) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/astral-sh/uv/releases/download/$uvVersion/uv-x86_64-pc-windows-msvc.zip" -OutFile ($archive + '.download')
            if ((Get-DesktopHash ($archive + '.download')) -ne $uvSha256) { throw 'uv download checksum mismatch. Retry setup.' }
            Move-Item -LiteralPath ($archive + '.download') -Destination $archive -Force
        }
        # Only extract the needed executable from the checksum-verified archive.
        # .NET is built into Windows PowerShell; no optional archive module needed.
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        New-Item -ItemType Directory -Force -Path $uvFolder | Out-Null
        $zip = [IO.Compression.ZipFile]::OpenRead($archive)
        try {
            $entry = $zip.GetEntry('uv.exe')
            if (!$entry) { throw 'uv executable not found in the verified archive.' }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $uv, $true)
        } finally { $zip.Dispose() }
        # All settings are process-local. No registry registration, shims or PATH edits.
        $env:UV_PYTHON_INSTALL_DIR = Join-Path $build 'portable-python'
        $env:UV_CACHE_DIR = Join-Path $build 'uv-cache'
        $env:UV_PYTHON_INSTALL_REGISTRY = '0'
        $env:UV_PYTHON_INSTALL_BIN = '0'
        $env:UV_NO_CONFIG = '1'
        $env:UV_SYSTEM_CERTS = 'true'
        & $uv python install 3.12.14 --no-bin --no-registry --no-config
        if ($LASTEXITCODE -ne 0) { throw 'Private Python download failed. Check the Internet/proxy connection and retry.' }
        if (Test-Path -LiteralPath $runtimeVenv) {
            # Preserve an interrupted or relocated runtime instead of deleting it.
            $resolved = (Resolve-Path -LiteralPath $runtimeVenv).Path
            if ((Split-Path $resolved) -ne (Resolve-Path -LiteralPath $build).Path) { throw 'Unexpected runtime directory.' }
            Move-Item -LiteralPath $resolved -Destination ($runtimeVenv + '.previous-' + [Guid]::NewGuid().ToString('N'))
        }
        & $uv venv $runtimeVenv --python 3.12.14 --managed-python --no-project --no-config
        if ($LASTEXITCODE -ne 0) { throw 'Could not create the private application environment.' }
        & $uv pip sync (Join-Path $PSScriptRoot 'requirements-lock.txt') --python $runtimePython --require-hashes --only-binary :all: --link-mode copy --default-index https://pypi.org/simple --no-config
        if ($LASTEXITCODE -ne 0) { throw 'Dependency download failed. Retry the launcher. See build/desktop-setup.log.' }
        if (!(Test-DesktopPython $runtimePython -Strict)) { throw 'Python/Tk verification failed. See build/python-check.log.' }
        $python = $runtimePython
    }
    & $python -E -s (Join-Path $PSScriptRoot 'runtime_support.py') --check
    if ($LASTEXITCODE -ne 0) { throw 'Native engine verification failed. See the message above.' }
    Write-Host "Python ready: $python"
    if (!$SetupOnly) {
        $pythonw = Join-Path (Split-Path $python) 'pythonw.exe'
        # This is the user-requested interactive application window.
        Start-Process -FilePath $pythonw -ArgumentList @('-E', '-s', ('"' + (Join-Path $PSScriptRoot 'launch.py') + '"')) -WorkingDirectory $PSScriptRoot -WindowStyle Normal
        Write-Host 'Opening Desktop SIL.'
    }
} catch {
    Write-Host "`nDesktop SIL setup could not finish: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "See $build\desktop-setup.log and $PSScriptRoot\docs\Windows_Setup.md"
    exit 1
} finally {
    if ($transcriptStarted) { Stop-Transcript | Out-Null }
    if ($setupLock) { $setupLock.Dispose() }
}
