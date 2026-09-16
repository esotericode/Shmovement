"""Run the actual Godot engine; reject errors even when Godot exits with code 0."""

from pathlib import Path
import re
import shutil
import subprocess
import sys


def main() -> int:
    project = Path(__file__).resolve().parents[1]
    requested = sys.argv[1] if len(sys.argv) > 1 else "godot"
    engine = shutil.which(requested)
    if engine is None:
        print(f"Godot executable not found: {requested}", file=sys.stderr)
        return 2
    jobs = [
        ("Import", ["--editor", "--import", "--quit"]),
        ("Scene startup", ["--fixed-fps", "60", "--quit-after", "120"]),
        ("Reference action rules", ["--script", "tests/test_reference.gd"]),
        ("Movement", ["--fixed-fps", "60", "--script", "tests/test_movement.gd"]),
        ("Playground", ["--fixed-fps", "60", "--script", "tests/test_playground.gd"]),
    ]
    for name, args in jobs:
        print(f"\n{name}", flush=True)
        try:
            result = subprocess.run(
                [engine, "--headless", "--path", str(project), *args],
                capture_output=True, text=True, timeout=90, cwd=project,
            )
        except subprocess.TimeoutExpired:
            print(f"FAIL: {name} exceeded 90 seconds", file=sys.stderr)
            return 1
        output = result.stdout + result.stderr
        print(output, end="", flush=True)
        if result.returncode or re.search(r"(?:SCRIPT ERROR:|(?:^|\n)ERROR:)", output):
            print(f"FAIL: {name}", file=sys.stderr)
            return 1
    print("\nAll engine checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
