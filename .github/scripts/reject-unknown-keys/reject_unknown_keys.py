#!/usr/bin/env python3
"""
Reject slice definition files that use keys Chisel does not read.

Chisel deliberately ignores unrecognised keys in an SDF so that an older Chisel
binary can still parse a release that uses fields added in a later format. That
leniency is correct for Chisel, but it means a misspelled key is indistinguishable
from a future one: it is silently dropped, and the slice resolves to something
other than what the author wrote. `chisel cut` succeeds, no gate complains, and
the defect ships.

This check only asks whether Chisel reads a key at all. Keys that are valid under
some formats and not others are Chisel's own business: it errors on those rather
than ignoring them, so the installability tests already catch their misuse.

The key sets below mirror the yaml struct tags in Chisel's internal/setup/yaml.go.
They must be updated whenever Chisel gains a field, otherwise this check will
reject a legitimately new key.
"""

from __future__ import annotations

import argparse
import logging
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator

import yaml

# Release formats this check understands.
KNOWN_FORMATS = ("v1", "v2", "v3")

# Every key Chisel reads.
PACKAGE_KEYS = frozenset(
    {"package", "archive", "essential", "slices", "store", "default-track", "v3-essential"}
)
SLICE_KEYS = frozenset({"hint", "essential", "contents", "mutate", "v3-essential"})
PATH_KEYS = frozenset(
    {
        "make",
        "mode",
        "copy",
        "text",
        "symlink",
        "mutable",
        "until",
        "arch",
        "generate",
        "prefer",
    }
)
ESSENTIAL_KEYS = frozenset({"arch"})


@dataclass(frozen=True)
class Finding:
    path: Path
    line: int
    key: str

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: {self.key!r} is not a key known to Chisel"


def read_format(release_dir: Path) -> str:
    """Read and validate the `format` field from a release's chisel.yaml.

    An unrecognised format means Chisel may read keys this check knows nothing
    about, so such a release is rejected rather than checked.
    """
    chisel_yaml = release_dir / "chisel.yaml"
    try:
        doc = yaml.safe_load(chisel_yaml.read_text())
    except OSError as err:
        raise ValueError(f"cannot read {chisel_yaml}: {err}") from err
    except yaml.YAMLError as err:
        raise ValueError(f"cannot parse {chisel_yaml}: {err}") from err
    if not isinstance(doc, dict) or "format" not in doc:
        raise ValueError(f"{chisel_yaml}: no 'format' field")
    release_format = str(doc["format"])
    if release_format not in KNOWN_FORMATS:
        raise ValueError(
            f"unknown format {release_format!r}, expected one of {', '.join(KNOWN_FORMATS)}"
        )
    return release_format


def _mapping_items(node: yaml.Node | None) -> Iterator[tuple[yaml.ScalarNode, yaml.Node]]:
    """Yield (key node, value node) pairs, or nothing if the node is not a mapping."""
    if isinstance(node, yaml.MappingNode):
        yield from node.value


def _find(node: yaml.Node, name: str) -> yaml.Node | None:
    for key, value in _mapping_items(node):
        if isinstance(key, yaml.ScalarNode) and key.value == name:
            return value
    return None


def _check_keys(path: Path, node: yaml.Node | None, allowed: frozenset[str]) -> list[Finding]:
    return [
        Finding(path=path, line=key.start_mark.line + 1, key=key.value)
        for key, _ in _mapping_items(node)
        if isinstance(key, yaml.ScalarNode) and key.value not in allowed
    ]


def _check_essential(path: Path, node: yaml.Node | None) -> list[Finding]:
    """Check the per-entry options of a mapping-style `essential` block.

    A v1/v2 `essential` is a list, which has no per-entry options; _mapping_items
    yields nothing for it, so this finds nothing there.
    """
    return [
        finding
        for _, options in _mapping_items(node)
        for finding in _check_keys(path, options, ESSENTIAL_KEYS)
    ]


def _check_slice(path: Path, body: yaml.Node) -> list[Finding]:
    """Check one slice: its own keys, its essentials, and its contents entries."""
    findings = _check_keys(path, body, SLICE_KEYS)
    findings += _check_essential(path, _find(body, "essential"))
    findings += _check_essential(path, _find(body, "v3-essential"))
    for _, options in _mapping_items(_find(body, "contents")):
        findings += _check_keys(path, options, PATH_KEYS)
    return findings


def check_file(path: Path) -> list[Finding]:
    """Report every key in an SDF that Chisel would not read."""
    try:
        root = yaml.compose(path.read_text())
    except yaml.YAMLError as err:
        raise ValueError(f"{path}: cannot parse as YAML: {err}") from err
    if not isinstance(root, yaml.MappingNode):
        raise ValueError(f"{path}: expected a top-level mapping")

    findings = _check_keys(path, root, PACKAGE_KEYS)
    findings += _check_essential(path, _find(root, "essential"))
    findings += _check_essential(path, _find(root, "v3-essential"))
    for _, body in _mapping_items(_find(root, "slices")):
        findings += _check_slice(path, body)
    return findings


def resolve_targets(release_dir: Path, files: Iterable[str]) -> list[Path]:
    """Return the SDFs to check: those named, else every slice in the release.

    Paths outside slices/ are dropped so the caller can hand over a raw
    changed-file list, and missing paths are dropped because a pull request may
    name files it deleted.
    """
    named = [Path(f) for f in files]
    if not named:
        return sorted((release_dir / "slices").glob("*.yaml"))
    return sorted(path for path in named if path.match("slices/*.yaml") and path.is_file())


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reject slice definition files that use keys Chisel does not read."
    )
    parser.add_argument(
        "files",
        nargs="*",
        help="SDFs to check. Entries outside slices/ are ignored. Defaults to every slice.",
    )
    parser.add_argument(
        "--release",
        type=Path,
        default=Path("."),
        help="Path to the release checkout containing chisel.yaml (default: .)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(format="%(message)s", level=logging.INFO)
    args = parse_args(argv)

    try:
        release_format = read_format(args.release)
        targets = resolve_targets(args.release, args.files)
        findings: list[Finding] = []
        for path in targets:
            findings.extend(check_file(path))
    except ValueError as err:
        logging.error("error: %s", err)
        return 2

    logging.info("checked %d slice(s) against format %s", len(targets), release_format)
    for finding in findings:
        logging.error("%s", finding)

    if findings:
        logging.error(
            "%d unreadable key(s) found. Chisel ignores unknown keys, so these are "
            "silently dropped rather than reported at cut time.",
            len(findings),
        )
        return 1
    logging.info("no unreadable keys")
    return 0


if __name__ == "__main__":
    sys.exit(main())
