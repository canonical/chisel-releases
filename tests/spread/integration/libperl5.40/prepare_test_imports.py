import glob
import os
import subprocess
import argparse
import yaml

NO_IMPORT = {"feature"}


def main(args: argparse.Namespace) -> None:

    slice_def = yaml.safe_load(
        open(
            os.path.join(args.project_path, "slices/libperl5.40.yaml"), encoding="utf-8"
        )
    )

    slices = slice_def.get("slices", [])

    for slice_name, chisel_slice in slices.items():
        slice_deps = set()
        for filename in chisel_slice.get("contents", {}):
            if filename.endswith(".pm"):
                globbing: list[str] = glob.glob(filename)
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

        os.makedirs(args.output_dir, exist_ok=True)
        filepath = os.path.join(args.output_dir, "{}.pm".format(slice_name))
        with open(filepath, "w", encoding="utf-8") as f:
            for item in slice_deps:
                if item in NO_IMPORT:
                    continue
                f.write("use %s;\n" % item)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare test imports for libperl5.40 slices"
    )
    parser.add_argument("project_path", help="Path to chisel-release root directory")
    parser.add_argument(
        "output_dir", help="Directory to output the generated test files"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args)
