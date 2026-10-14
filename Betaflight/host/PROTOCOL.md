# Betaflight Simulink host boundary

This is a single-process, single-client TCP interface around the actual enabled
Betaflight SITL flight stack. Source pin: `c78d9e7bd24ef60f4324dffde11df26c53d4f29f`.
The patches adapt the simulated hardware, clock, transport and scheduler's
wall-clock wait. They do not replace flight-control algorithms.

The host build also disables the virtual-gyro shortcut that skips startup
calibration in upstream SITL. Real Betaflight calibration now runs on the
supplied stationary gyro samples, including bias and movement detection.
Allow at least the configured calibration duration before arming. The Simulink
wrapper defaults to five seconds, then arming and one second at flight throttle
before releasing the airborne plant. This changes the binary hash and renders
older exact-replay captures incompatible with the new executable.

Start the compiled process with `--host-port 9005`. It binds **127.0.0.1 only**.
Each new run must use a new process and its own working directory / `eeprom.bin`.
The existing `--config path/to/config.cli` mode executes normal firmware startup,
processes CLI commands, saves EEPROM and exits before opening the host listener.
Use `get` / `dump all` in such a file to obtain firmware-generated configuration
output. Check CLI error messages as well as the exit code; command validation
errors can precede a successful `save`.

Messages are unframed fixed-length IEEE754 **little-endian double** arrays. Read
exactly the entire response before sending another request. Use TCP_NODELAY and
a finite client read timeout. MATLAB `typecast(double(request),'uint8')` on the
Windows host produces the correct byte order. Java ByteBuffer must explicitly
set LITTLE_ENDIAN if it is used instead. Integers are encoded as exact doubles.

## Request: 52 doubles / 416 bytes

Indices below are MATLAB one-based.

| Index | Meaning |
|---|---|
| 1 | Magic `20261011` |
| 2 | Version `1` |
| 3 | Opcode: `1` STEP, `2` QUERY, `3` CLOSE |
| 4 | Sequence, nonnegative integer; strictly increases for STEP |
| 5 | Simulated seconds since host startup completed; monotonically increasing |
| 6:8 | Aircraft body-FRD angular velocity, rad/s |
| 9:11 | Aircraft body-FRD specific force, m/s²; level rest is `[0 0 -9.80665]` |
| 12:27 | Sixteen **raw receiver channel** pulse values, nominally 1000–2000 µs |
| 28:39 | True state `[N E D u v w phi theta psi p q r]`; positions NED, velocities body FRD, angles/rates radians |
| 40 | Bitmask: `1` ideal barometer, `2` ideal magnetometer, `4` ideal GPS, `8` new RC frame, `16` angle reference adapter, `32` rate reference adapter |
| 41:52 | Reference `Xref` in the same twelve-state order |

All words, even unused ones, must be finite. A STEP may advance at most ten
seconds, and total protocol time is limited to one day. Default packet flags
should be **8 only at receiver-frame times**, otherwise 0; gyro/control packets
can run at 4 kHz while RC arrives at e.g. 250 Hz. `16` and `32` are mutually
exclusive. RC conversion only occurs on packets also containing bit 8.

The angle adapter synthesizes roll and pitch receiver inputs for `Xref(7:8)`
and a yaw rate for `Xref(12)`. It requires Angle mode to be selected through the
normal firmware AUX configuration. The rate adapter uses `Xref(10:12)` and
requires Acro mode. Throttle and AUX inputs remain the supplied raw RC values.
The adapters invert the **actual current firmware rate function**, including
the current rate profile, receiver mapping, deadbands, yaw reversal and endpoint
calibration. Setpoints saturate at firmware limits and have receiver-pulse
quantization. RC smoothing, feedforward, trims, control modes and the subsequent
controller behavior remain active; these helpers do not bypass them.

The optional navigation feeds are ideal sensors, disabled by default. GPS uses
a local tangent origin at 33.6405° N, 117.8443° W and zero reference altitude.
They are not substitutes for the noisy sensor subsystem or a configurable
navigation environment. The actual attitude estimator always runs; no truth
quaternion is assigned to it.

## Response: 40 doubles / 320 bytes

| Index | Meaning |
|---|---|
| 1:2 | Magic, version |
| 3 | Status: 0 success; 1 protocol, 2 time, 3 value, 4 sensors not ready, 5 step too large, 6 scheduler failed to quiesce |
| 4 | Echoed sequence |
| 5 | Actual relative firmware simulation time, seconds |
| 6:9 | Four absolute firmware motor PWM commands in native mixer output order |
| 10:12 | Estimated aircraft-FRD roll, pitch, yaw, rad; native Euler resolution is 0.1° |
| 13:15 | Filtered aircraft-FRD gyro, rad/s |
| 16:18 | RC rate setpoint before angle conversion, aircraft-FRD rad/s |
| 19:30 | Native Betaflight PID terms `[rollP rollI rollD rollF pitchP pitchI pitchD pitchF yawP yawI yawD yawF]` |
| 31 | Armed flag |
| 32 | Firmware arming-disable bitmask |
| 33 | Firmware flight-mode bitmask |
| 34:35 | Configured gyro sampling and PID periods, µs |
| 36 | Firmware motor count |
| 37:39 | Native Betaflight PID sums, roll/pitch/yaw |
| 40 | Internal simulated scheduler tick count |

PID values have native firmware signs and scaling. Body gyro/rate and Mahony
roll/pitch signs match the plant FRD convention. Firmware heading is negated
and wrapped to ±pi for the Euler yaw output. Motor ordering is left unchanged
for the model boundary to map. Version 1 exports four motors; the
client should reject configurations whose motor count is not four.

## Clock, warmup and reproducibility

Initialization delays advance a virtual microsecond clock. The epoch is captured
after normal startup, so the first requested time zero is unambiguous. During
simulation the clock only advances for STEP. Between incoming samples, the prior
IMU values are held; the new sample is applied **before** tasks at the requested
timestamp. The scheduler dispatches at a deterministic 10 µs quantum, executing
eligible upstream tasks until none run. It models zero CPU execution duration,
not operating-system jitter, MCU instruction timing or CPU overload.

The build uses `VIRTUAL_GYRO_SAMPLE_RATE_HZ=4000`. Exchange sensor packets at
250 µs regardless of `pid_process_denom`. Dividers 1–16 select the native
PID/mixer period independently; always verify response 34:35. Motor PWM remains
held between native mixer calls, even though sensor packets continue at 4 kHz.
Firmware arming checks remain intact. Before releasing the plant, send held
initial-state sensor readings and regular RC frames at low throttle with ARM
off, then request ARM through its configured AUX channel. Inspect response
31:32 and retain a bounded warmup timeout. No hidden automatic arming, estimator
reset, or disabling of checks occurs in the bridge.

Identical sensor packets, command packets, EEPROM/config and binary should
produce identical outputs. Record the upstream SHA, host-source hashes, compiler
flags, EEPROM/CLI config, initial conditions, warmup and packet schedule with
each run. Prove repeatability with two fresh processes before claiming it for a
new compiler or firmware revision.

The optional MATLAB client trace stores successive `[request(52); response(40)]`
records as little-endian doubles (736 bytes per exchange). A `.mat` sidecar stores
the requested configuration and executable SHA-256. It includes warmup and
arming exchanges. `bf.replayTrace` checks every response against a fresh process
with the same binary and configuration; the trace contains no source snapshots.
