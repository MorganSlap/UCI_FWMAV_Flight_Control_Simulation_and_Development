"""Small dependency/Tk probe used before launching, including on a fresh PC."""
import argparse
import importlib
from importlib.metadata import version
from pathlib import Path
import re
import struct
import sys


def check(strict=False):
    if sys.version_info < (3, 11) or struct.calcsize('P') != 8:
        raise RuntimeError('Desktop SIL requires 64-bit Python 3.11 or newer.')
    for name in ('tkinter', 'numpy', 'scipy.io', 'matplotlib.backends.backend_agg', 'h5py', 'PIL.Image'):
        importlib.import_module(name)
    if strict:
        lock = Path(__file__).with_name('requirements-lock.txt').read_text(encoding='utf-8')
        for name, expected in re.findall(r'^([\w-]+)==([^\s\\]+)', lock, re.MULTILINE):
            if version(name) != expected:
                raise RuntimeError(f'{name}: expected {expected}, found {version(name)}')
    import tkinter as tk
    window = tk.Tk()
    window.withdraw()
    window.update_idletasks()
    window.destroy()
    print(f'Python, Tk, plotting and storage libraries ready: {sys.executable}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--strict', action='store_true')
    check(parser.parse_args().strict)
