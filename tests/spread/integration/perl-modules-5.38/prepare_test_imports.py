import glob
import os
import subprocess

import yaml

NO_IMPORT = {"feature"}
PROJECT_PATH = os.environ.get("PROJECT_PATH", os.getcwd())

slice_def = yaml.safe_load(
    open(os.path.join(PROJECT_PATH, "slices/perl-modules-5.38.yaml"), encoding="utf-8")
)

slices = slice_def.get("slices", [])

for slice_name, chisel_slice in slices.items():
    slice_deps = set()
    for filename in chisel_slice.get("contents", {}):
        if filename.endswith(".pm"):
            globbing = glob.glob(filename)
            for perl_module in globbing:
                proc = subprocess.run(
                    ["scandeps", "--no-recurse", perl_module],
                    capture_output=True,
                    text=True,
                    check=True,
                )
                if proc.returncode != 0:
                    raise RuntimeError(
                        "Failed to inspect module dependencies for {}".format(
                            perl_module
                        )
                    )
                slice_deps.update(
                    {
                        line.split("=>")[0].strip(" '")
                        for line in proc.stdout.splitlines()
                    }
                )
    if len(slice_deps) == 0:
        continue

    test_dir = os.path.join(
        PROJECT_PATH, "tests/spread/integration/perl-modules-5.38/cases"
    )
    os.makedirs(test_dir, exist_ok=True)
    filepath = os.path.join(test_dir, "{}.pm".format(slice_name))
    with open(filepath, "w", encoding="utf-8") as f:
        for item in slice_deps:
            if item in NO_IMPORT:
                continue
            f.write("use %s;\n" % item)
