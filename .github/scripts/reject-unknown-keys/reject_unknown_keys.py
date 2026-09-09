#!/usr/bin/env python3
"""
Reject slice definition files that use keys Chisel does not read.

Chisel deliberately ignores unrecognised keys in an SDF so that an older Chisel
binary can still parse a release that uses fields added in a later format. That
leniency is correct for Chisel, but it means a misspelled key is indistinguishable
from a future one: it is silently dropped, and the slice resolves to something
other than what the author wrote. `chisel cut` succeeds, no gate complains, and
the defect ships.

Since this repository knows which format each branch targets (the `format` field
in chisel.yaml), it can afford to be strict where Chisel cannot. This script reads
that format, derives the set of keys Chisel would actually read, and reports any
key outside it.

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

# Formats Chisel accepts, per the check in setup.parseRelease.
KNOWN_FORMATS = ("v1", "v2", "v3", "v4")

# Keys valid regardless of format.
PACKAGE_KEYS = frozenset({"package", "archive", "essential", "slices"})
SLICE_KEYS = frozenset({"hint", "essential", "contents", "mutate"})
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

# Format-gated keys. Chisel errors on these when used under the wrong format
# rather than ignoring them, but they are still the wrong key for the branch.
LEGACY_ESSENTIAL_FORMATS = frozenset({"v1", "v2"})  # where v3-essential applies
STORE_KEYS = frozenset({"store", "default-track"})  # v3 onwards

# Only format v3 keeps bin slice definitions in their own directory, so that
# older Chisel versions -- which read slices/ and know nothing of stores -- are
# unaffected by the new store fields. v4 moved them back into slices/.
BIN_SLICES_FORMATS = frozenset({"v3"})


@dataclass(frozen=True)
class KeySets:
    """The keys Chisel reads for a given release format."""

    package: frozenset[str]
    slice: frozenset[str]
    path: frozenset[str]
    essential: frozenset[str]


@dataclass(frozen=True)
class Finding:
    path: Path
    line: int
    column: int
    where: str
    key: str
    reason: str

    def annotation(self) -> str:
        """Render as a GitHub Actions error annotation."""
        return (
            f"::error file={self.path},line={self.line},col={self.column}::"
            f"{self.where}: {self.reason}"
        )

    def human(self) -> str:
        return f"{self.path}:{self.line}:{self.column}: {self.where}: {self.reason}"


def key_sets_for(release_format: str) -> KeySets:
    """Derive the readable key set for a release format."""
    if release_format not in KNOWN_FORMATS:
        raise ValueError(
            f"unknown format {release_format!r}, expected one of {', '.join(KNOWN_FORMATS)}"
        )
    package = set(PACKAGE_KEYS)
    slice_keys = set(SLICE_KEYS)
    if release_format in LEGACY_ESSENTIAL_FORMATS:
        # v3-essential back-ports arch-specific essentials into v1/v2 releases.
        package.add("v3-essential")
        slice_keys.add("v3-essential")
    else:
        package |= STORE_KEYS
    return KeySets(
        package=frozenset(package),
        slice=frozenset(slice_keys),
        path=PATH_KEYS,
        essential=ESSENTIAL_KEYS,
    )


def slice_dirs(release_format: str) -> tuple[str, ...]:
    """Directories Chisel reads slice definitions from, for a release format."""
    if release_format in BIN_SLICES_FORMATS:
        return ("slices", "bin-slices")
    return ("slices",)


def read_format(release_dir: Path) -> str:
    """Read the `format` field from a release's chisel.yaml."""
    chisel_yaml = release_dir / "chisel.yaml"
    try:
        doc = yaml.safe_load(chisel_yaml.read_text())
    except OSError as err:
        raise ValueError(f"cannot read {chisel_yaml}: {err}") from err
    except yaml.YAMLError as err:
        raise ValueError(f"cannot parse {chisel_yaml}: {err}") from err
    if not isinstance(doc, dict) or "format" not in doc:
        raise ValueError(f"{chisel_yaml}: no 'format' field")
    return str(doc["format"])


def _mapping_items(node: yaml.Node | None) -> Iterator[tuple[yaml.ScalarNode, yaml.Node]]:
    """Yield (key node, value node) pairs, or nothing if the node is not a mapping."""
    if isinstance(node, yaml.MappingNode):
        yield from node.value


def _find(node: yaml.Node, name: str) -> yaml.Node | None:
    for key, value in _mapping_items(node):
        if isinstance(key, yaml.ScalarNode) and key.value == name:
            return value
    return None


def _check_keys(
    path: Path,
    node: yaml.Node | None,
    allowed: frozenset[str],
    where: str,
    findings: list[Finding],
) -> None:
    for key, _ in _mapping_items(node):
        if not isinstance(key, yaml.ScalarNode) or key.value in allowed:
            continue
        findings.append(
            Finding(
                path=path,
                line=key.start_mark.line + 1,
                column=key.start_mark.column + 1,
                where=where,
                key=key.value,
                reason=(
                    f"{key.value!r} is not a key Chisel reads; it is silently ignored. "
                    f"Expected one of: {', '.join(sorted(allowed))}"
                ),
            )
        )


def _check_essential(
    path: Path, node: yaml.Node | None, keys: KeySets, where: str, findings: list[Finding]
) -> None:
    """Check the per-entry options of a mapping-style `essential` block.

    A v1/v2 `essential` is a list, which has no per-entry options; _mapping_items
    yields nothing for it, so this is a no-op there.
    """
    for entry, options in _mapping_items(node):
        if not isinstance(entry, yaml.ScalarNode):
            continue
        _check_keys(path, options, keys.essential, f"{where}[{entry.value}]", findings)


def check_file(path: Path, keys: KeySets) -> list[Finding]:
    """Report every key in an SDF that Chisel would not read."""
    findings: list[Finding] = []
    try:
        root = yaml.compose(path.read_text())
    except yaml.YAMLError as err:
        return [
            Finding(
                path=path,
                line=1,
                column=1,
                where="<file>",
                key="",
                reason=f"cannot parse as YAML: {err}",
            )
        ]
    if not isinstance(root, yaml.MappingNode):
        return [
            Finding(
                path=path,
                line=1,
                column=1,
                where="<file>",
                key="",
                reason="expected a top-level mapping",
            )
        ]

    _check_keys(path, root, keys.package, "top level", findings)
    _check_essential(path, _find(root, "essential"), keys, "essential", findings)
    _check_essential(path, _find(root, "v3-essential"), keys, "v3-essential", findings)

    slices = _find(root, "slices")
    if slices is None:
        return findings
    for name, body in _mapping_items(slices):
        if not isinstance(name, yaml.ScalarNode):
            continue
        where = f"slice {name.value!r}"
        _check_keys(path, body, keys.slice, where, findings)
        _check_essential(path, _find(body, "essential"), keys, f"{where} essential", findings)
        _check_essential(
            path, _find(body, "v3-essential"), keys, f"{where} v3-essential", findings
        )
        for entry, options in _mapping_items(_find(body, "contents")):
            if not isinstance(entry, yaml.ScalarNode):
                continue
            _check_keys(path, options, keys.path, f"{where} path {entry.value!r}", findings)
    return findings


def resolve_targets(release_dir: Path, files: Iterable[str], dirs: tuple[str, ...]) -> list[Path]:
    """Return the SDFs to check: those named, else every slice in the release.

    Paths in directories Chisel does not read slices from are dropped, so the
    caller can hand over a raw changed-file list, and missing paths are dropped
    because a pull request may name files it deleted.
    """
    named = [Path(f) for f in files]
    if not named:
        return sorted(
            path for name in dirs for path in (release_dir / name).glob("*.yaml")
        )
    return sorted(
        path
        for path in named
        if path.suffix == ".yaml" and path.parent.name in dirs and path.is_file()
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reject slice definition files that use keys Chisel does not read."
    )
    parser.add_argument(
        "files",
        nargs="*",
        help=(
            "SDFs to check. Entries outside the release's slice directories are "
            "ignored. Defaults to every slice."
        ),
    )
    parser.add_argument(
        "--release",
        type=Path,
        default=Path("."),
        help="Path to the release checkout containing chisel.yaml (default: .)",
    )
    parser.add_argument(
        "--annotate",
        action="store_true",
        help="Emit GitHub Actions error annotations as well as human-readable output.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(format="%(message)s", level=logging.INFO)
    args = parse_args(argv)

    try:
        release_format = read_format(args.release)
        keys = key_sets_for(release_format)
    except ValueError as err:
        logging.error("error: %s", err)
        return 2

    targets = resolve_targets(args.release, args.files, slice_dirs(release_format))
    if not targets:
        logging.info("no slice definition files to check")
        return 0

    findings: list[Finding] = []
    for path in targets:
        findings.extend(check_file(path, keys))

    logging.info("checked %d slice(s) against format %s", len(targets), release_format)
    for finding in findings:
        if args.annotate:
            print(finding.annotation())
        logging.error("%s", finding.human())

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
