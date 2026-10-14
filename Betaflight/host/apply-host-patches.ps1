param(
    [Parameter(Mandatory=$true)][string]$SourceRoot
)
$ErrorActionPreference = 'Stop'
$sourcePath = (Resolve-Path -LiteralPath $SourceRoot).Path
$hostPath = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Edit-Source([string]$relative, [scriptblock]$transform) {
    $path = Join-Path $sourcePath $relative
    $text = [System.IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    if ($text.Contains('BF_SIMULINK_HOST')) {
        Write-Output "Already patched: $relative"
        return
    }
    $result = & $transform $text
    [System.IO.File]::WriteAllText($path, $result, $utf8)
    Write-Output "Patched: $relative"
}

function Replace-Once([string]$text, [string]$before, [string]$after) {
    $first = $text.IndexOf($before, [StringComparison]::Ordinal)
    if ($first -lt 0 -or $text.IndexOf($before, $first + $before.Length, [StringComparison]::Ordinal) -ge 0) {
        throw "Expected exactly one source anchor: $before"
    }
    return $text.Substring(0,$first) + $after + $text.Substring($first+$before.Length)
}

if (-not (Test-Path -LiteralPath (Join-Path $sourcePath 'src/platform/SIMULATOR/sitl.c'))) {
    throw 'SourceRoot must be the pinned Betaflight source checkout/build copy.'
}
Copy-Item -LiteralPath (Join-Path $hostPath 'bf_host.c') -Destination (Join-Path $sourcePath 'src/platform/SIMULATOR/bf_host.c') -Force
Copy-Item -LiteralPath (Join-Path $hostPath 'bf_host.h') -Destination (Join-Path $sourcePath 'src/platform/SIMULATOR/bf_host.h') -Force
Copy-Item -LiteralPath (Join-Path $hostPath 'bf_host_rc.inc') -Destination (Join-Path $sourcePath 'src/platform/SIMULATOR/bf_host_rc.inc') -Force

Edit-Source 'src/platform/SIMULATOR/mk/SITL.mk' {
    param($s)
    $s + "`n# BF_SIMULINK_HOST: deterministic host boundary; original flight stack stays compiled.`nTARGET_FLAGS += -DBF_SIMULINK_HOST -DVIRTUAL_GYRO_SAMPLE_RATE_HZ=4000`nMCU_COMMON_SRC += SIMULATOR/bf_host.c`n"
}
Edit-Source 'src/platform/SIMULATOR/target/SITL/target.h' {
    param($s)
    Replace-Once $s '#define ENABLE_SIMULATOR_MULTITHREAD 1' "#if defined(BF_SIMULINK_HOST)`n#define ENABLE_SIMULATOR_MULTITHREAD 0`n#else`n#define ENABLE_SIMULATOR_MULTITHREAD 1`n#endif"
}
Edit-Source 'src/main/main.c' {
    param($s)
    $s = Replace-Once $s '#include "scheduler/scheduler.h"' "#include `"scheduler/scheduler.h`"`n#ifdef BF_SIMULINK_HOST`n#include `"bf_host.h`"`n#endif"
    Replace-Once $s "void FAST_CODE run(void)`n{" "void FAST_CODE run(void)`n{`n#ifdef BF_SIMULINK_HOST`n    bfHostRun();`n    return;`n#endif"
}
Edit-Source 'src/main/fc/rc.c' {
    param($s)
    $s + "`n#ifdef BF_SIMULINK_HOST`n#include `"bf_host_rc.inc`"`n#endif`n"
}
Edit-Source 'src/main/sensors/gyro.c' {
    param($s)
    # Upstream SITL assumes an unbiased virtual gyro and skips calibration.
    # Our sensor model includes bias: run the original flight-hardware
    # calibration algorithm, including its movement detection and duration.
    Replace-Once $s '#if defined(USE_VIRTUAL_GYRO) && !defined(UNIT_TEST)' '#if defined(USE_VIRTUAL_GYRO) && !defined(UNIT_TEST) && !defined(BF_SIMULINK_HOST)'
}
Edit-Source 'src/main/scheduler/scheduler.c' {
    param($s)
    $s = Replace-Once $s '#include "scheduler.h"' "#include `"scheduler.h`"`n#ifdef BF_SIMULINK_HOST`n#include `"bf_host.h`"`n#endif"
    $s = Replace-Once $s '        selectedTask->attribute->taskFunc(currentTimeBeforeTaskCallUs);' "#ifdef BF_SIMULINK_HOST`n        bfHostNoteTask();`n#endif`n        selectedTask->attribute->taskFunc(currentTimeBeforeTaskCallUs);"
    $before = "            while (schedLoopRemainingCycles > 0) {`n                nowCycles = getCycleCounter();`n                schedLoopRemainingCycles = cmpTimeCycles(nextTargetCycles, nowCycles);`n            }"
    $after = "#ifdef BF_SIMULINK_HOST`n            // Simulated clock advances only between scheduler invocations.`n            if (schedLoopRemainingCycles > 0) return;`n#else`n$before`n#endif"
    Replace-Once $s $before $after
}
Edit-Source 'src/platform/SIMULATOR/sitl.c' {
    param($s)
    $s = Replace-Once $s '#include "sitl_gyro.h"' "#include `"sitl_gyro.h`"`n#ifdef BF_SIMULINK_HOST`n#include `"bf_host.h`"`n#endif"
    $s = Replace-Once $s '    for (int i = 1; i < argc; i++) {' "    for (int i = 1; i < argc; i++) {`n#ifdef BF_SIMULINK_HOST`n        if (bfHostParseArgument(argc, argv, &i)) continue;`n#endif"
    $s = Replace-Once $s "void systemInit(void)`n{" "void systemInit(void)`n{`n#ifdef BF_SIMULINK_HOST`n    clock_gettime(CLOCK_MONOTONIC, &start_time);`n    SystemCoreClock = 500 * 1e6;`n    bfHostInit();`n    return;`n#endif"
    $s = Replace-Once $s "void systemReset(void)`n{" "void systemReset(void)`n{`n#ifdef BF_SIMULINK_HOST`n    bfHostShutdown();`n    exit(0);`n#endif"
    $s = Replace-Once $s "void systemResetToBootloader(bootloaderRequestType_e requestType)`n{" "void systemResetToBootloader(bootloaderRequestType_e requestType)`n{`n#ifdef BF_SIMULINK_HOST`n    bfHostShutdown();`n    exit(0);`n#endif"
    $s = Replace-Once $s "uint64_t micros64(void)`n{" "uint64_t micros64(void)`n{`n#ifdef BF_SIMULINK_HOST`n    return bfHostMicros();`n#endif"
    $s = Replace-Once $s "uint64_t millis64(void)`n{" "uint64_t millis64(void)`n{`n#ifdef BF_SIMULINK_HOST`n    return bfHostMicros()/1000;`n#endif"
    $s = Replace-Once $s "void delayMicroseconds(uint32_t us)`n{" "void delayMicroseconds(uint32_t us)`n{`n#ifdef BF_SIMULINK_HOST`n    bfHostDelayUs(us);`n    return;`n#endif"
    $s = Replace-Once $s "void delay(uint32_t ms)`n{" "void delay(uint32_t ms)`n{`n#ifdef BF_SIMULINK_HOST`n    bfHostDelayUs((uint64_t)ms*1000);`n    return;`n#endif"
    $s = Replace-Once $s "static void pwmWriteMotor(uint8_t index, float value)`n{" "static void pwmWriteMotor(uint8_t index, float value)`n{`n#ifdef BF_SIMULINK_HOST`n    bfHostWriteMotor(index, value);`n#endif"
    Replace-Once $s "static void pwmCompleteMotorUpdate(void)`n{" "static void pwmCompleteMotorUpdate(void)`n{`n#ifdef BF_SIMULINK_HOST`n    return;`n#endif"
}
Write-Output 'Host source patches complete. Platform compiler/linker adaptations are applied separately by the build script.'
