#!/usr/bin/python3

"""
Custom linter for chisel slice definition files.

Use in addition with yamllint (https://yamllint.readthedocs.io), since this
script only covers slice definition file specifc rules.
"""

import argparse
import sys
import typing
from dataclasses import dataclass

import yaml


def parse_args() -> argparse.Namespace:
    """
    Parse CLI args passed to this script.
    """
    parser = argparse.ArgumentParser(
        description="Lint slice definition files",
    )
    parser.add_argument(
        "files",
        metavar="file",
        help="Chisel slice definition file(s)",
        nargs="*",
    )
    parser.add_argument(
        "--sorted-slices",
        action=argparse.BooleanOptionalAction,
        help="Slice names must be sorted",
    )
    parser.add_argument(
        "--sorted-essential",
        action=argparse.BooleanOptionalAction,
        help="Entries in 'essential' must be sorted",
    )
    parser.add_argument(
        "--sorted-contents",
        action=argparse.BooleanOptionalAction,
        help="Entries in 'contents' need to be sorted",
    )
    return parser.parse_args()


def is_sorted(entries: list) -> bool:
    """
    Return true if a list is sorted in ASCENDING order.
    """
    for i in range(len(entries) - 1):
        if entries[i] > entries[i + 1]:
            return False
    return True


def lint_sorted_slices(yaml_data: dict) -> list[str] | None:
    """
    Slice names must be sorted.
    """
    slices = list(yaml_data["slices"].keys())
    if not is_sorted(slices):
        return ["slice names are not sorted (--sorted-slices)"]
    return None


def lint_sorted_essential(yaml_data: dict) -> list[str] | None:
    """
    'essential' entries must be sorted in a slice.
    """
    slices = yaml_data["slices"]
    errs = []
    for key, slice in slices.items():
        if "essential" not in slice:
            continue
        entries = slice["essential"]
        if is_sorted(entries):
            continue
        errs.append(
            f'{key}: "essential" entries are not sorted (--sorted-essential)',
        )
    if len(errs) > 0:
        return errs
    return None


def lint_sorted_contents(yaml_data: dict) -> list[str] | None:
    """
    'contents' entries must be sorted in a slice.
    """
    slices = yaml_data["slices"]
    errs = []
    for key, slice in slices.items():
        if "contents" not in slice:
            continue
        entries = list(slice["contents"].keys())
        if is_sorted(entries):
            continue
        errs.append(
            f'{key}: "contents" entries are not sorted (--sorted-contents)',
        )
    if len(errs) > 0:
        return errs
    return None


@dataclass
class LintOptions:
    sorted_slices: bool = True
    sorted_essential: bool = True
    sorted_contents: bool = True


def lint(filename: str, opts: LintOptions) -> list[str] | None:
    """
    Run all lint rules on a file using the provided options.
    """
    with open(filename, "r", encoding="utf-8") as f:
        data = f.read()
    yaml_data = yaml.safe_load(data)

    all_errs = []

    def lint_yaml_data(func: typing.Callable):
        errs = func(yaml_data)
        if errs:
            all_errs.extend(errs)

    if opts.sorted_slices is not False:
        lint_yaml_data(lint_sorted_slices)
    if opts.sorted_essential is not False:
        lint_yaml_data(lint_sorted_essential)
    if opts.sorted_contents is not False:
        lint_yaml_data(lint_sorted_contents)

    if len(all_errs) > 0:
        return all_errs
    return None


def print_errors(errs: dict[str, list[str]] | None) -> None:
    """
    Print the found linting errors.
    """
    if not errs:
        return
    for filename in sorted(errs.keys()):
        print(f"\033[4m{filename}\033[0m")
        for e in sorted(errs[filename]):
            print(f"  \033[91m{'error':8s}\033[0m{e}")
        print()


def main() -> None:
    """
    The main function -- execution should start from here.
    """
    args = parse_args()
    files = args.files
    opts = LintOptions(args.sorted_slices, args.sorted_essential, args.sorted_contents)
    #
    ok = True
    errs = {}
    for file in files:
        e = lint(file, opts)
        if e:
            errs[file] = e
            ok = False
    print_errors(errs)
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
