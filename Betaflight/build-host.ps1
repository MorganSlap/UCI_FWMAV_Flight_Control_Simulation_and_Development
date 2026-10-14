param([switch]$InstallToolchain)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$pin = 'c78d9e7bd24ef60f4324dffde11df26c53d4f29f'
$source = Join-Path $root 'upstream'
$cygwin = Join-Path $root 'toolchain/cygwin'
$bash = Join-Path $cygwin 'bin/bash.exe'
$utf8 = [Text.UTF8Encoding]::new($false)

if ($InstallToolchain) {
    $toolchain = Join-Path $root 'toolchain'
    New-Item -ItemType Directory -Path $toolchain -Force | Out-Null
    $installer = Join-Path $toolchain 'setup-x86_64.exe'
    Invoke-WebRequest 'https://cygwin.com/setup-x86_64.exe' -OutFile $installer
    $arguments = '-q -B -N -n -d --no-admin --no-write-registry -R "' + $cygwin + '" -l "' + (Join-Path $toolchain 'cache') + '" -s https://mirrors.kernel.org/sourceware/cygwin/ -P gcc-core,make,git,python3'
    $setup = Start-Process -FilePath $installer -ArgumentList $arguments -WindowStyle Hidden -PassThru -Wait
    if ($setup.ExitCode -ne 0) { throw "Cygwin installation failed: $($setup.ExitCode)" }
    $package = Join-Path $toolchain 'gcc-core-13.5.0.tar.zst'
    Invoke-WebRequest 'https://mirrors.kernel.org/sourceware/cygwin/x86_64/release/gcc/gcc-core/gcc-core-13.5.0-1-x86_64.tar.zst' -OutFile $package
    $expected = 'aa670ff777968a34e103d0567acb542da9baacc8ce9723b464f4056f4c65af83377de80a8775ee5bc2d4db06a92f43e6ff593ba7dc5d78b2fb832f1a3cf09c21'
    if ((Get-FileHash -LiteralPath $package -Algorithm SHA512).Hash.ToLowerInvariant() -ne $expected) { throw 'GCC package checksum mismatch.' }
    New-Item -ItemType Directory -Path (Join-Path $cygwin 'build') -Force | Out-Null
    Copy-Item -LiteralPath $package -Destination (Join-Path $cygwin 'build/gcc-core.tar.zst') -Force
    & $bash --noprofile --norc -c 'export PATH=/usr/bin:/bin; tar -xf /build/gcc-core.tar.zst -C /'
    if ($LASTEXITCODE -ne 0) { throw 'GCC extraction failed.' }
}
if (-not (Test-Path -LiteralPath $bash)) { throw 'Run build-host.ps1 -InstallToolchain first (requires Internet access).' }
if (-not (Test-Path -LiteralPath (Join-Path $source '.git'))) {
    & git clone --no-checkout https://github.com/betaflight/betaflight.git $source
    if ($LASTEXITCODE -ne 0) { throw 'Upstream clone failed.' }
    & git -C $source checkout --detach $pin
    if ($LASTEXITCODE -ne 0) { throw 'Pinned checkout failed.' }
}
$actual = (& git -C $source rev-parse HEAD).Trim()
if ($actual -ne $pin) { throw "Upstream HEAD is $actual; expected $pin. The existing checkout was left unchanged." }
& git -C $source submodule update --init --depth 1 lib/modules/dronecan/libcanard src/config
if ($LASTEXITCODE -ne 0) { throw 'Submodule setup failed.' }
$buildSource = Join-Path $cygwin 'build/betaflight'
if (-not (Test-Path -LiteralPath $buildSource)) {
    New-Item -ItemType Directory -Path (Split-Path $buildSource) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $buildSource -Recurse
}
& (Join-Path $root 'host/apply-host-patches.ps1') -SourceRoot $buildSource
# Windows PE has no ELF .fini_array and does not accept -z noexecstack.
$makefile = Join-Path $buildSource 'src/platform/SIMULATOR/mk/SITL.mk'
[IO.File]::WriteAllText($makefile,[IO.File]::ReadAllText($makefile).Replace('-Wl,-z,noexecstack',''),$utf8)
$linker = Join-Path $buildSource 'src/platform/SIMULATOR/link/sitl.ld'
[IO.File]::WriteAllText($linker,[IO.File]::ReadAllText($linker).Replace('INSERT BEFORE .fini_array;','INSERT BEFORE .data;'),$utf8)
# Serial make is intentional: Cygwin GCC's LTO jobserver fails with -j8.
& $bash --noprofile --norc -c 'export PATH=/usr/bin:/bin; cd /build/betaflight && make TARGET=SITL -j1 > /build/host-build.log 2>&1'
if ($LASTEXITCODE -ne 0) { throw "Firmware build failed. Inspect $cygwin/build/host-build.log" }
$output = Join-Path $root 'build'
New-Item -ItemType Directory -Path $output -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $buildSource 'obj/main/betaflight_SITL.elf') -Destination (Join-Path $output 'betaflight_simulink.exe') -Force
Get-FileHash -LiteralPath (Join-Path $output 'betaflight_simulink.exe') -Algorithm SHA256
