import os
import subprocess
import sys

# python3 and python3.14 ship the same scripts under their own suffix
suffix = sys.argv[1] if len(sys.argv) > 1 else os.path.basename(sys.executable).removeprefix("python")

for script, args in (("pdb", ["--help"]), ("pydoc", ["pydoc"]), ("pygettext", ["--help"])):
    # pygettext prints its help to stderr
    out = subprocess.run(
        [f"{script}{suffix}", *args], check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True
    ).stdout
    assert out, f"{script}{suffix} printed nothing"
