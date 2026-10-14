# Noise-enabled example and model corrections

Branch: `codex/betaflight-simulation`. Changes remain uncommitted.

## Which issues were pre-existing?

The source audit read the model from Git base commit `4f2f207` without running
or modifying that historical model. Its last model-file commit was `1146e6f`
(2026-10-03), before this Betaflight integration. That saved model contains:

| Issue | Evidence in the original model | Applied change |
|---|---|---|
| Free-flight accelerometer physics | `accel_gravity + noise_true*a_drag + noise_true*a_thrust` | Measure non-gravitational force/mass, matching linear/quadratic plant drag; physical force no longer depends on the noise switch |
| White-noise scaling | Band-Limited White Noise power was density squared times bandwidth, without multiplying by sample time | Set power to density squared times bandwidth times sample time |
| Nonlinear arm-length input | Constant3, SID 555, had `Value=m` | Use `S` |

The original mass and arm length were both numerically 0.11, which masked the
last wiring error until either parameter changed.

I introduced a compile error in the first version of the correction by passing
the text `sim_fidelity` into a numeric Stateflow parameter. This is fixed:
the script and workbench now derive the logical `imu_nonlinear` parameter.
Both plant variants compile and run. I also initially overlooked upstream
SITL's skipped virtual-gyro calibration when building the adapter; that
integration gap was fixed in the preceding continuation by enabling the
existing native calibration routine for this host build.

## Changes in this continuation

- Noise defaults **ON**, with a bold **Simulated noise: ON/OFF** toolbar checkbox
  visible from every page. It synchronizes with settings/presets and is locked
  during a simulation.
- Applied the explicitly approved model corrections above. Exposed sensor bias,
  noise density, vibration amplitude and sample rate in the GUI/init variables.
- Added ideal/measured accelerometer and gyro logging. Explore now includes
  104 scalar signals; raw sensor noise can be plotted separately from filtered
  attitude. No source scripts or model files are copied into run archives.
- Added an explicit **Ideal bench accel calibration** option. The example uses
  known simulated bias to prefill native integer offsets; it changes to zero
  offsets when noise is OFF. Disable it to retain manual CLI calibration.
  Requested settings and effective firmware settings are both saved; the latter
  are in `Variables.bfConfig`. This is an ideal calibration assumption, not a
  replacement estimator or an in-flight truth correction.
- Set the example's native `imu_dcm_kp` to 250 (0.025), from 2500 (0.25), to
  reduce accelerometer correction during thrust-driven motion. Rate PID gains
  remain P=10, I/D/F=0. No altitude sensor or altitude/position loop was added.
- Updated both complete JSON example presets and the flight/noise validation
  plots. Plot titles identify noise state and seed. Noise fixtures handle
  Simulink's time-last vector data correctly.

## Results and limits

For the default 10 s noisy nonlinear case (seed 23341), peak absolute roll/pitch
is 0.136/0.177 deg, horizontal displacement is 0.713 m and height loss is 0.293 m.
The noisy +5/-3 deg recovery enters and remains within 1 deg after 5.16 s,
finishing at 0.489/-0.580 deg. Position drifts because it is not controlled.
Both plants, noise on/off, an additional seed and the actual GUI run pass;
39 unit tests pass. The noise-OFF level run has exactly matching ideal/measured
IMU signals. Detailed metrics and criteria are in [VALIDATION.md](VALIDATION.md).
A new noisy Simulink trace, including ideal bench calibration and startup,
replays all 2,632 firmware exchanges exactly in a fresh process.

Remaining limitations include zero default yaw authority, common-axis
vibration/correlated random noise inherited from the sensor model, ideal
pre-release calibration, quantized fixed-throttle trim, and the hardware/SITL
coverage boundaries documented in [README.md](README.md).
