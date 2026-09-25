#!/usr/bin/env python3
"""
Script to find the slices of a chisel release affected by a change.

A slice is changed if it was added, removed or modified between the base
revision and the working tree. Package-level fields count as part of every
slice of the package, and hints are ignored. A slice is affected if it is
changed or if it depends, directly or transitively, on a changed slice.
Removed slices are never affected themselves, but their dependents are, so
that dangling references to them get caught.

Changes to chisel.yaml or to the .github directory affect the whole release,
as does passing --all=true.

The result is printed to stdout as JSON.
"""

from __future__ import annotations

import argparse
import json
import logging
import subprocess
from collections import defaultdict
from pathlib import Path

import yaml

# Changes to any of these paths affect every slice in the release.
ALL_TRIGGERS = ("chisel.yaml",)  # ".github/"


def git(release: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(release), *args],
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def _normalise_essential(fields: dict) -> dict:
    """Essential is a list or, since format v3, a map. Turn it into a map."""
    essential = fields.get("essential")
    if isinstance(essential, list):
        return {**fields, "essential": dict.fromkeys(essential)}
    return fields


def parse_sdf(text: str) -> tuple[str, dict[str, dict]]:
    """Parse a slice definition file into the package name and a map of slice
    keys (e.g. "libc6_libs") to slice definitions."""
    sdf = yaml.safe_load(text)
    package = sdf["package"]
    shared = {k: v for k, v in sdf.items() if k not in ("package", "slices")}
    shared = _normalise_essential(shared)
    slices: dict[str, dict] = {}
    for name, fields in (sdf.get("slices") or {}).items():
        fields = {k: v for k, v in (fields or {}).items() if k != "hint"}
        slices[f"{package}_{name}"] = {
            "package": shared,
            "slice": _normalise_essential(fields),
        }
    return package, slices


def dependencies(definition: dict) -> set[str]:
    """The slices which a slice definition directly depends on."""
    deps: set[str] = set()
    for fields in definition.values():
        deps.update(fields.get("essential") or {})
        deps.update(fields.get("v3-essential") or {})
    return deps


def changed_slices(base: dict[str, dict], head: dict[str, dict]) -> set[str]:
    return {k for k in base.keys() | head.keys() if base.get(k) != head.get(k)}


def affected_slices(head: dict[str, dict], changed: set[str]) -> set[str]:
    """The changed slices and their transitive dependents, limited to the
    slices which exist in head."""
    # NOTE: this keeps edges to slices missing from head, so dependents of a
    # removed slice are still found.
    dependents: dict[str, set[str]] = defaultdict(set)
    for key, definition in head.items():
        for dep in dependencies(definition):
            dependents[dep].add(key)

    affected = set(changed)
    pending = list(changed)
    while pending:
        for key in dependents[pending.pop()] - affected:
            affected.add(key)
            pending.append(key)
    return affected & head.keys()


def changed_paths(release: Path, base: str) -> dict[str, str]:
    """Map the paths changed between base and the working tree to their git
    status letter (A, M, D, ...)."""
    args = ["-z", "--name-status", "--no-renames", base, "--", "slices", *ALL_TRIGGERS]
    fields = git(release, "diff", *args).split("\0")[:-1]
    return dict(zip(fields[1::2], fields[::2]))


def find_affected(release: Path, base: str | None) -> dict:
    """Find the slices affected by the changes since base. If base is None,
    every slice is affected."""
    paths = changed_paths(release, base) if base is not None else {}

    base_slices: dict[str, dict] = {}
    for path, status in paths.items():
        if path.startswith("slices/") and path.endswith(".yaml") and status != "A":
            _, slices = parse_sdf(git(release, "show", f"{base}:{path}"))
            base_slices.update(slices)

    head_slices: dict[str, dict] = {}
    head_changed_slices: dict[str, dict] = {}
    files: dict[str, str] = {}
    for file in sorted((release / "slices").rglob("*.yaml")):
        path = file.relative_to(release).as_posix()
        package, slices = parse_sdf(file.read_text())
        files[package] = path
        head_slices.update(slices)
        if path in paths:
            head_changed_slices.update(slices)

    everything = base is None or any(p.startswith(ALL_TRIGGERS) for p in paths)
    changed = changed_slices(base_slices, head_changed_slices)
    if everything:
        affected = set(head_slices)
    else:
        affected = affected_slices(head_slices, changed)
    packages = {key.split("_", 1)[0] for key in affected}

    return {
        "all": everything,
        "changed_slices": sorted(changed),
        "affected_slices": sorted(affected),
        "packages": sorted(packages),
        "files": sorted(files[p] for p in packages),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Find the slices of a chisel release affected by a change",
    )
    parser.add_argument(
        "--release",
        default=".",
        type=Path,
        help="chisel-releases checkout to compare against base (default: .)",
    )
    parser.add_argument(
        "--base",
        default="HEAD^1",
        help="git revision to compare against (default: HEAD^1, the base "
        "branch of a PR merge commit)",
    )
    parser.add_argument(
        "--all",
        type=lambda value: value == "true",
        default=False,
        help="if 'true', ignore --base and treat every slice as affected",
    )
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    result = find_affected(args.release, None if args.all else args.base)
    if result["all"]:
        logging.info("All %d slices are affected", len(result["affected_slices"]))
    else:
        logging.info(
            "%d changed slices affect %d slices in %d packages",
            len(result["changed_slices"]),
            len(result["affected_slices"]),
            len(result["packages"]),
        )
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
