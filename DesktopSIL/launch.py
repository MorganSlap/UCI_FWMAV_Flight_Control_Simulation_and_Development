"""Desktop entry point with visible startup errors, including under pythonw."""
from contextlib import redirect_stderr, redirect_stdout
from datetime import datetime
from pathlib import Path
import os
import sys
import traceback


def main():
    root = Path(__file__).resolve().parent
    log_path = root / "build" / "desktop-launch.log"
    try:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        with log_path.open("a", encoding="utf-8", buffering=1) as log:
            with redirect_stdout(log), redirect_stderr(log):
                print(f"\n{datetime.now().isoformat()} Starting Desktop SIL (PID {os.getpid()})")
                print(f"Python: {sys.executable}")
                try:
                    os.chdir(root)
                    from runtime_support import validate_engine
                    print(validate_engine())
                    from app import App
                    application = App()
                    application.update_idletasks()
                    print("Desktop interface ready")
                    application.mainloop()
                    print("Desktop interface closed")
                except Exception:
                    traceback.print_exc()
                    raise
        return 0
    except Exception as error:
        message = f"Desktop SIL could not open.\n\n{type(error).__name__}: {error}\n\nStartup log:\n{log_path}"
        if sys.platform == "win32":
            import ctypes
            ctypes.windll.user32.MessageBoxW(None, message, "Desktop SIL startup error", 0x10)
        elif sys.stderr is not None:
            print(message, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
