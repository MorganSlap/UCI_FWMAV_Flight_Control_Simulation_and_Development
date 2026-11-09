"""Select the local development build or the checked-in Windows runtime."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
NATIVE_FILES = ('hover_desktop_sil.exe', 'cygwin1.dll', 'cyggcc_s-seh-1.dll')


def select_engine(root=ROOT):
    root = Path(root)
    development = root / 'build' / NATIVE_FILES[0]
    return development if development.is_file() else root / 'runtime' / 'windows-x64' / NATIVE_FILES[0]


def validate_engine(executable=None, root=ROOT):
    root = Path(root)
    executable = Path(executable) if executable is not None else select_engine(root)
    for name in NATIVE_FILES:
        if not (executable.parent / name).is_file():
            raise FileNotFoundError(
                f'Missing native runtime file: {executable.parent / name}. '
                'Extract the complete repository ZIP, or rebuild with DesktopSIL/build.ps1.'
            )
    packaged = executable.parent == root / 'runtime' / 'windows-x64'
    if packaged:
        manifest = json.loads((executable.parent / 'manifest.json').read_text(encoding='utf-8-sig'))
        for name in NATIVE_FILES:
            actual = hashlib.sha256((executable.parent / name).read_bytes()).hexdigest()
            if actual != manifest['files'][name]:
                raise RuntimeError(f'Runtime checksum mismatch: {name}. Download/extract the repository again.')
    return {'engine_source': 'packaged runtime' if packaged else 'local development build',
            'engine_path': str(executable)}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    parser.parse_args()
    details = validate_engine()
    print(f"Native engine ready ({details['engine_source']}): {details['engine_path']}")
