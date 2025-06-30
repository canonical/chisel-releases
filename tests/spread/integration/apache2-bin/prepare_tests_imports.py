import glob
import os
import subprocess
import yaml


PROJECT_PATH = os.environ.get("PROJECT_PATH", os.getcwd())
with open(
    os.path.join(PROJECT_PATH, "slices/apache2-bin.yaml"),
    encoding="utf-8",
) as f:
    slice_def = yaml.safe_load(f)

slices = slice_def.get("slices", [])
SKIP_SLICES = {"apache2", "bins", "modules", "mod-mpm-prefork", "mod-authz-core", "mod-dir"}

for slice_name, chisel_slice in slices.items():
    if slice_name in SKIP_SLICES:
        continue

    slice_deps = chisel_slice.get("essential", [])
    if not slice_deps:
        continue

    out_dir = os.path.join(PROJECT_PATH, "tests/spread/integration/apache2-bin/cases")
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, f"{slice_name}.deps")
    with open(out_file, "w", encoding="utf-8") as f:
        for dep in sorted(slice_deps):
            f.write(f"{dep}\n")
    print(f"Generated {out_file} with {len(slice_deps)} essentials")
