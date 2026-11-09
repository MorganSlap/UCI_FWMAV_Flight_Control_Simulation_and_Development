param([string]$MatlabRoot = 'C:\Program Files\MATLAB\R2025b', [switch]$PlantOnly, [switch]$SkipFirmware)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$cygwin = Join-Path $root 'Betaflight/toolchain/cygwin'
$gcc = Join-Path $cygwin 'bin/gcc.exe'
$ar = Join-Path $cygwin 'bin/ar.exe'
$gen = Join-Path $PSScriptRoot 'generated/hover_plant_sil_ert_rtw'
$linearGen = Join-Path $PSScriptRoot 'generated/hover_linear_sil_ert_rtw'
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Force -Path $build | Out-Null
if (!(Test-Path $gcc)) { throw 'Run Betaflight/build-host.ps1 -InstallToolchain first.' }
if (!(Test-Path (Join-Path $gen 'hover_plant_sil.c'))) { throw 'Run DesktopSIL/matlab/buildPlantCode in MATLAB first.' }
$oldPath = $env:PATH
$env:PATH = (Join-Path $cygwin 'bin') + ';' + $env:PATH
try {
    $flags = @('-std=c11','-O2','-fno-fast-math','-ffp-contract=off',('-I'+$gen),('-I'+$linearGen),('-I'+$build),('-I'+(Join-Path $PSScriptRoot 'native')),('-I'+(Join-Path $MatlabRoot 'simulink/include')),('-I'+(Join-Path $MatlabRoot 'extern/include')))
    $objects = @()
    foreach ($source in Get-ChildItem -LiteralPath $gen -Filter '*.c') {
        $obj = Join-Path $build ($source.BaseName+'.o')
        & $gcc @flags -c $source.FullName -o $obj
        if ($LASTEXITCODE -ne 0) { throw "C compilation failed: $source" }
        $objects += $obj
    }
    & $gcc @flags (Join-Path $PSScriptRoot 'native/plant_probe.c') @objects -lm -o (Join-Path $build 'plant_probe.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Plant probe link failed.' }
    if ($PlantOnly) { Write-Output 'Generated plant compiled successfully.'; return }
    foreach ($name in @('hover_linear_sil.c','hover_linear_sil_data.c')) {
        $obj = Join-Path $build ($name+'.o')
        & $gcc @flags -c (Join-Path $linearGen $name) -o $obj
        if ($LASTEXITCODE -ne 0) { throw "Linear plant compilation failed: $name" }
        $objects += $obj
    }
    $pattern = '(?:real_T|boolean_T|struct_\w+)\s+(\w+)(?:\[\d+\])?;'
    $fields = @{}
    foreach ($model in @('hover_plant_sil','hover_linear_sil')) {
        $header = Get-Content (Join-Path $PSScriptRoot "generated/$($model)_ert_rtw/$model.h") -Raw
        $body = [regex]::Match($header,"(?s)struct P_$($model)_T_ \{(.*?)\n\};").Groups[1].Value
        $fields[$model] = @([regex]::Matches($body,$pattern) | ForEach-Object { $_.Groups[1].Value })
    }
    $copies = foreach ($field in $fields['hover_linear_sil']) {
        if ($fields['hover_plant_sil'] -contains $field) { "memcpy(&hover_linear_sil_P.$field, &hover_plant_sil_P.$field, sizeof(hover_linear_sil_P.$field));" }
    }
    [IO.File]::WriteAllLines((Join-Path $build 'plant_shared_fields.inc'),$copies)
    & $gcc @flags -Wall -Wextra -Werror -c (Join-Path $PSScriptRoot 'native/plant_adapter.c') -o (Join-Path $build 'plant_adapter.o')
    if ($LASTEXITCODE -ne 0) { throw 'Plant adapter compilation failed.' }
    $objects += (Join-Path $build 'plant_adapter.o')
    & $gcc @flags -Wall -Wextra -Werror -c (Join-Path $PSScriptRoot 'native/desktop_sil.c') -o (Join-Path $build 'desktop_sil.o')
    if ($LASTEXITCODE -ne 0) { throw 'Desktop runner compilation failed.' }
    # Always construct a fresh archive with basename members. Cygwin ar can
    # treat Windows absolute paths as different member names and retain stale
    # code when updating an existing archive.
    $archive = Join-Path $build 'libdesktop_sil.a'
    if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive }
    $objectNames = @($objects | ForEach-Object { Split-Path -Leaf $_ })
    Push-Location $build
    try { & $ar rcs libdesktop_sil.a @objectNames desktop_sil.o }
    finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw 'Native library build failed.' }
    & $gcc @flags (Join-Path $PSScriptRoot 'native/adapter_probe.c') (Join-Path $build 'libdesktop_sil.a') -lm -o (Join-Path $build 'adapter_probe.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Adapter verification probe link failed.' }
    if ($SkipFirmware) { Write-Output 'Generated plants, native adapter and verification probes compiled.'; return }
    $sourceRoot = Join-Path $cygwin 'build/betaflight'
    if (!(Test-Path $sourceRoot)) { throw 'Build the existing Betaflight host first with Betaflight/build-host.ps1.' }
    & (Join-Path $root 'Betaflight/host/apply-host-patches.ps1') -SourceRoot $sourceRoot
    $hostFile = Join-Path $sourceRoot 'src/platform/SIMULATOR/bf_host.c'
    $makeFile = Join-Path $sourceRoot 'src/platform/SIMULATOR/mk/SITL.mk'
    $imuFile = Join-Path $sourceRoot 'src/main/flight/imu.c'
    $gyroInitFile = Join-Path $sourceRoot 'src/main/sensors/gyro_init.c'
    $schedulerFile = Join-Path $sourceRoot 'src/main/scheduler/scheduler.c'
    $sitlFile = Join-Path $sourceRoot 'src/platform/SIMULATOR/sitl.c'
    $serialTcpFile = Join-Path $sourceRoot 'src/main/drivers/serial_tcp.c'
    $originalHost = [IO.File]::ReadAllText($hostFile)
    $originalMake = [IO.File]::ReadAllText($makeFile)
    $originalImu = [IO.File]::ReadAllText($imuFile)
    $originalGyroInit = [IO.File]::ReadAllText($gyroInitFile)
    $originalScheduler = [IO.File]::ReadAllText($schedulerFile)
    $originalSitl = [IO.File]::ReadAllText($sitlFile)
    $originalSerialTcp = [IO.File]::ReadAllText($serialTcpFile)
    $utf8 = [Text.UTF8Encoding]::new($false)
    try {
        # Desktop SIL feeds sensors/receiver/configuration directly. Keep the
        # serial-port buffers and task behavior, but do not open unused UART
        # TCP listeners (or prompt Windows for inbound firewall permission).
        # The separate MATLAB host retains its original network behavior.
        $serialAnchor = '    s->serv = dyad_newStream();'
        if (!$originalSerialTcp.Contains($serialAnchor)) { throw 'SITL serial listener anchor changed.' }
        $serialText = $originalSerialTcp.Replace($serialAnchor, ("    if (getenv(`"BF_DESKTOP_CASE`")) return s;`n" + $serialAnchor))
        [IO.File]::WriteAllText($serialTcpFile,$serialText,$utf8)
        $hostText = $originalHost.Replace('    listenSocket = socket(AF_INET, SOCK_STREAM, 0);', "    if (getenv(`"BF_DESKTOP_CASE`")) { extern int desktopSilRun(void); exit(desktopSilRun()); }`n    listenSocket = socket(AF_INET, SOCK_STREAM, 0);")
        $hostText += "`nint bfDesktopStep(const double *request, double *response) {`n    int status = stepTo(request);`n    makeResponse(response, request, status);`n    return status;`n}`n"
        $hostText += "`n" + [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'native/firmware_timing.inc'))
        $hostText = $hostText.Replace('#define BF_HOST_QUANTUM_US 10U', "extern int bfDesktopSynchronizedClock(void);`n#define BF_HOST_QUANTUM_US (bfDesktopSynchronizedClock() ? 1U : 10U)")
        [IO.File]::WriteAllText($hostFile,$hostText,$utf8)
        # Upstream SITL treats one cycle as one microsecond. A nanosecond cycle
        # counter can represent 312.5 us; micros() and all flight dt stay upstream.
        $sitlText = $originalSitl
        foreach ($spec in @(@('clockCyclesToMicros','int32_t clockCycles','clockCycles / 1000'),@('clockCyclesTo10thMicros','int32_t clockCycles','clockCycles / 100'),@('clockCyclesTo100thMicros','int32_t clockCycles','clockCycles / 10'),@('clockMicrosToCycles','uint32_t micros','micros * 1000U'),@('getCycleCounter','void','(uint32_t)(micros64() * 1000ULL)'))) {
            $anchor = "$($spec[0])($($spec[1]))`n{"
            if (!$sitlText.Contains($anchor)) { throw "SITL clock anchor changed: $anchor" }
            $sitlText = $sitlText.Replace($anchor,($anchor+"`n    extern int bfDesktopSynchronizedClock(void);`n    if (bfDesktopSynchronizedClock()) return $($spec[2]);"))
        }
        [IO.File]::WriteAllText($sitlFile,$sitlText,$utf8)
        # Read the rates before upstream calibration, filter and scheduler setup.
        foreach ($anchor in @('gyroSensor->gyroDev.gyroSampleRateHz = VIRTUAL_GYRO_SAMPLE_RATE_HZ;', 'gyroSensor->gyroDev.accSampleRateHz = VIRTUAL_GYRO_SAMPLE_RATE_HZ;')) {
            if (!$originalGyroInit.Contains($anchor)) { throw 'Virtual sensor initialization anchors changed.' }
        }
        $gyroText = $originalGyroInit.Replace('gyroSensor->gyroDev.gyroSampleRateHz = VIRTUAL_GYRO_SAMPLE_RATE_HZ;', 'extern unsigned bfDesktopGyroRateHz(void); extern unsigned bfDesktopAccelRateHz(void); gyroSensor->gyroDev.gyroSampleRateHz = bfDesktopGyroRateHz();').Replace('gyroSensor->gyroDev.accSampleRateHz = VIRTUAL_GYRO_SAMPLE_RATE_HZ;', 'gyroSensor->gyroDev.accSampleRateHz = bfDesktopAccelRateHz();')
        if ($gyroText -eq $originalGyroInit) { throw 'Virtual sensor initialization anchors changed.' }
        [IO.File]::WriteAllText($gyroInitFile,$gyroText,$utf8)
        # Hardware locks to the sensor interrupt clock, including fractional-us
        # periods (312.5 us at 3200 Hz). Supply that ideal clock in desktop SIL.
        # Retain upstream integer-us filter dt and all upstream task bodies.
        $schedulerText = $originalScheduler.Replace('#include "bf_host.h"', "#include `"bf_host.h`"`nextern unsigned bfDesktopGyroRateHz(void);`nextern int bfDesktopSynchronizedClock(void);`nextern void bfDesktopNoteTask(const void *, uint32_t);")
        $periodAnchor = 'desiredPeriodCycles = (int32_t)clockMicrosToCycles((uint32_t)getTask(TASK_GYRO)->attribute->desiredPeriodUs);'
        foreach ($anchor in @($periodAnchor,'#include "bf_host.h"','        bfHostNoteTask();','        // Realtime gyro/filtering/PID tasks get complete priority')) {
            if (!$originalScheduler.Contains($anchor)) { throw "Desktop timing anchor changed: $anchor" }
        }
        $schedulerText = $schedulerText.Replace($periodAnchor, ($periodAnchor+"`n    if (bfDesktopSynchronizedClock()) desiredPeriodCycles = (int32_t)(clockMicrosToCycles(1000000U) / bfDesktopGyroRateHz());"))
        $schedulerText = $schedulerText.Replace('        bfHostNoteTask();', "        bfHostNoteTask();`n        bfDesktopNoteTask(selectedTask, currentTimeBeforeTaskCallUs);")
        $schedulerText = $schedulerText.Replace('        // Realtime gyro/filtering/PID tasks get complete priority', "        static bool desktopClockStarted;`n        if (bfDesktopSynchronizedClock() && !desktopClockStarted) { lastTargetCycles = getCycleCounter() - desiredPeriodCycles; desktopClockStarted = true; }`n        // Realtime gyro/filtering/PID tasks get complete priority")
        [IO.File]::WriteAllText($schedulerFile,$schedulerText,$utf8)
        # Passive taps at the exact Mahony input and quaternion propagation
        # boundaries. No firmware filtering or estimator equations are changed.
        $inputAnchor = '    static float integralFBx = 0.0f,'
        $rateAnchor = '    // Integrate rate of change of quaternion'
        if (!$originalImu.Contains($inputAnchor) -or !$originalImu.Contains($rateAnchor)) { throw 'Pinned IMU telemetry anchors changed; review the instrumentation.' }
        $inputTap = @'
    extern double bfDesktopImuTelemetry[12];
    bfDesktopImuTelemetry[0]=gx; bfDesktopImuTelemetry[1]=gy; bfDesktopImuTelemetry[2]=gz;
    bfDesktopImuTelemetry[3]=ax; bfDesktopImuTelemetry[4]=ay; bfDesktopImuTelemetry[5]=az;
    bfDesktopImuTelemetry[6]=useAcc; bfDesktopImuTelemetry[7]=dt; bfDesktopImuTelemetry[8]+=1;
'@
        $rateTap = @'
    bfDesktopImuTelemetry[9]=gx; bfDesktopImuTelemetry[10]=gy; bfDesktopImuTelemetry[11]=gz;
'@
        $imuText = $originalImu.Replace($inputAnchor,($inputTap+"`n"+$inputAnchor)).Replace($rateAnchor,($rateTap+"`n"+$rateAnchor))
        $imuText += "`ndouble bfDesktopImuTelemetry[12];`n"
        [IO.File]::WriteAllText($imuFile,$imuText,$utf8)
        # Cygwin make cannot reliably handle a workspace path containing spaces.
        Copy-Item -LiteralPath (Join-Path $build 'libdesktop_sil.a') -Destination (Join-Path $cygwin 'build/libdesktop_sil.a') -Force
        [IO.File]::WriteAllText($makeFile,($originalMake + "`nLD_FLAGS += /build/libdesktop_sil.a`n"),$utf8)
        $bash = Join-Path $cygwin 'bin/bash.exe'
        & $bash --noprofile --norc -c 'export PATH=/usr/bin:/bin; cd /build/betaflight && make TARGET=SITL -j1 > /build/desktop-sil-build.log 2>&1'
        if ($LASTEXITCODE -ne 0) { throw "Firmware link failed. See $cygwin/build/desktop-sil-build.log" }
        Copy-Item -LiteralPath (Join-Path $sourceRoot 'obj/main/betaflight_SITL.elf') -Destination (Join-Path $build 'hover_desktop_sil.exe') -Force
    } finally {
        [IO.File]::WriteAllText($hostFile,$originalHost,$utf8)
        [IO.File]::WriteAllText($makeFile,$originalMake,$utf8)
        [IO.File]::WriteAllText($imuFile,$originalImu,$utf8)
        [IO.File]::WriteAllText($gyroInitFile,$originalGyroInit,$utf8)
        [IO.File]::WriteAllText($schedulerFile,$originalScheduler,$utf8)
        [IO.File]::WriteAllText($sitlFile,$originalSitl,$utf8)
        [IO.File]::WriteAllText($serialTcpFile,$originalSerialTcp,$utf8)
    }
    # Runtime DLLs belong beside the executable; no MATLAB Runtime is needed.
    foreach ($name in @('cygwin1.dll','cyggcc_s-seh-1.dll')) {
        if (Test-Path (Join-Path $cygwin "bin/$name")) { Copy-Item (Join-Path $cygwin "bin/$name") $build -Force }
    }
    . (Join-Path $PSScriptRoot 'native-manifest.ps1')
    Write-DesktopNativeManifest -Folder $build -MatlabRoot $MatlabRoot
    Get-FileHash -Algorithm SHA256 (Join-Path $build 'hover_desktop_sil.exe')
} finally { $env:PATH = $oldPath }
