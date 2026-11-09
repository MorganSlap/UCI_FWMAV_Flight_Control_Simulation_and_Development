"""Portable-runtime checks, including real flights without a compiler/MATLAB path."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import runtime_support as runtime


class RuntimeSelectionTests(unittest.TestCase):
    def test_bundled_engine_and_checksums(self):
        bundled = ROOT / 'runtime/windows-x64/hover_desktop_sil.exe'
        self.assertEqual(runtime.validate_engine(bundled)['engine_source'], 'packaged runtime')

    def test_development_build_wins_and_is_not_overwritten(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'build') as temporary:
            root = Path(temporary)
            (root / 'build').mkdir()
            expected = root / 'build/hover_desktop_sil.exe'
            expected.write_bytes(b'developer build')
            self.assertEqual(runtime.select_engine(root), expected)
            self.assertEqual(expected.read_bytes(), b'developer build')

    def test_missing_dll_is_actionable(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'build') as temporary:
            root = Path(temporary)
            (root / 'build').mkdir()
            exe = root / 'build/hover_desktop_sil.exe'
            exe.write_bytes(b'engine')
            with self.assertRaisesRegex(FileNotFoundError, 'cygwin1.dll'):
                runtime.validate_engine(exe, root)

    def test_corrupt_bundle_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'build') as temporary:
            root = Path(temporary)
            folder = root / 'runtime/windows-x64'
            folder.mkdir(parents=True)
            files = {}
            for name in runtime.NATIVE_FILES:
                (folder / name).write_bytes(b'correct')
                files[name] = hashlib.sha256(b'correct').hexdigest()
            (folder / 'manifest.json').write_text(json.dumps({'files': files}))
            (folder / 'cygwin1.dll').write_bytes(b'corrupt')
            with self.assertRaisesRegex(RuntimeError, 'checksum mismatch'):
                runtime.validate_engine(root=root)


def smoke(require_packaged=False, compare_engine=None):
    import numpy as np
    import runner
    import storage
    import monte_carlo as mc
    from matplotlib.figure import Figure
    from matplotlib.backends.backend_agg import FigureCanvasAgg
    if require_packaged:
        assert runner.EXE.parent == ROOT / 'runtime/windows-x64', runner.EXE
    # Remove all development paths. The DLLs must resolve beside the executable.
    os.environ['PATH'] = str(Path(os.environ['SystemRoot']) / 'System32')
    report = {'engine': runtime.validate_engine(runner.EXE), 'flights': []}
    output = ROOT / 'build/portable-verification'
    output.mkdir(parents=True, exist_ok=True)
    for fidelity in ('high', 'low'):
        case = runner.load_case(ROOT / 'presets/noisy_hover.json')
        case.update(duration=2, fidelity=fidelity, storage_root=str(output), noise=True)
        folder = runner.execute(case, progress=lambda *args: None)
        record = storage.load_run(folder)
        summary = storage.read_json(folder / 'engine_summary.json')
        assert summary['completed'] and summary['simulation_seconds'] == 2, summary
        assert np.isfinite(record['roll_rad']).all() and np.isfinite(record['raw_gyro_x_radps']).all()
        assert np.all(record['armed'] == 1)
        assert (folder / 'signals.h5').is_file()
        report['flights'].append({'fidelity': fidelity, 'samples': len(record['time_s']), 'complete': True})
        if compare_engine:
            # The portability changes must not change the numerical flight loop.
            current = runner.EXE
            try:
                runner.EXE = Path(compare_engine).resolve()
                prior = storage.load_run(runner.execute(case, progress=lambda *args: None))
            finally:
                runner.EXE = current
            assert set(record.dtype.names) == set(prior.dtype.names)
            assert all(np.array_equal(record[key], prior[key]) for key in record.dtype.names)
            report['flights'][-1]['previous_build_exact_match'] = True
    figure = Figure(figsize=(8, 4))
    FigureCanvasAgg(figure)
    axes = figure.subplots()
    axes.plot(record['time_s'], np.rad2deg(record['roll_rad']))
    figure.savefig(output / 'portable-flight.png')
    figure.savefig(output / 'portable-flight.pdf')
    design = mc.default_design(runner.load_case(ROOT / 'presets/noisy_recovery.json'))
    design['base'].update(duration=.5, log_hz=400)
    design.update(count=2, workers=2, grid_points=101, include_nominal=False)
    study = mc.create_study(design, output / 'monte_carlo')
    manifest = mc.run_study(study)
    assert len(manifest['rows']) == 2 and all(row['status'] == 'complete' for row in manifest['rows'])
    report.update(passed=True, parallel_monte_carlo_trials=2, hdf5=True, png_pdf=True)
    (output / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


def verify_no_listeners():
    """A desktop run must not listen for LAN/Configurator input."""
    import runner
    case = runner.load_case(ROOT / 'presets/noisy_hover.json')
    case.update(duration=15, realtime=True, storage_root=str(ROOT / 'build/network-verification'))
    folder = runner.prepare(case)
    runner.configure(folder)
    with (folder / 'engine.log').open('w') as log:
        process = subprocess.Popen([str(runner.EXE)], cwd=folder, env=runner.environment(folder),
                                   stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            deadline = time.monotonic() + 15
            while 'TIME 0.3000' not in (folder / 'engine.log').read_text():
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('Network verification flight did not start')
                time.sleep(.05)
            network = subprocess.check_output([str(Path(os.environ['SystemRoot']) / 'System32/netstat.exe'), '-ano'], text=True)
            owned = [row for row in network.splitlines() if row.split() and row.split()[-1] == str(process.pid)]
            assert not owned, f'Unexpected network sockets for desktop engine: {owned}'
        finally:
            (folder / 'stop').touch()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.terminate()
                process.wait(timeout=5)
    assert 'bind port ' not in (folder / 'configuration.log').read_text()
    assert 'bind port ' not in (folder / 'engine.log').read_text()
    print('Desktop flight has no TCP/UDP sockets; no inbound firewall access is needed.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--smoke', action='store_true')
    parser.add_argument('--require-packaged', action='store_true')
    parser.add_argument('--compare-engine')
    parser.add_argument('--no-listeners', action='store_true')
    args = parser.parse_args()
    (ROOT / 'build').mkdir(exist_ok=True)
    result = unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(RuntimeSelectionTests))
    if not result.wasSuccessful():
        raise SystemExit(1)
    if args.smoke:
        smoke(args.require_packaged, args.compare_engine)
    if args.no_listeners:
        verify_no_listeners()
