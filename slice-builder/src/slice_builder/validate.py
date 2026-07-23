"""Validation: yamllint + sort-check + parse-check.

Run before writing the final SDF. On failure, the agent is retried (up to ``--retries``).
"""

from __future__ import annotations

import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from slice_builder.sdf import SDF, byte_sorted, parse_sdf

# Path to the tool-owned yamllint config, next to this package's source tree.
_YAMLLINT_CONFIG = Path(__file__).resolve().parents[2] / "yamllint.yaml"


@dataclass
class ValidationResult:
    """Outcome of validating a draft SDF."""

    ok: bool
    errors: list[str] = field(default_factory=list)

    def add(self, msg: str) -> None:
        self.errors.append(msg)
        self.ok = False


def _run_yamllint(sdf_text: str) -> list[str]:
    """Run yamllint (as a subprocess) against ``sdf_text`` using the tool-owned config.

    Returns a list of human-readable error strings (empty if clean).
    """

    if not _YAMLLINT_CONFIG.is_file():
        return [f"yamllint config not found: {_YAMLLINT_CONFIG}"]

    try:
        proc = subprocess.run(
            ["yamllint", "-c", str(_YAMLLINT_CONFIG), "-"],
            input=sdf_text,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return ["yamllint not installed (run: uv run yamllint ...)"]

    if proc.returncode == 0:
        return []
    # yamllint prints "file:line:col: message" — strip the leading "-:" filename.
    lines = [ln for ln in (proc.stdout + proc.stderr).splitlines() if ln.strip()]
    cleaned: list[str] = []
    for ln in lines:
        if ln.startswith("-:"):
            ln = ln[2:]
        cleaned.append(ln.strip())
    return cleaned or ["yamllint reported errors"]


def _check_sorted(sdf: SDF) -> list[str]:
    """Verify ``contents`` and ``essential`` keys are in byte order."""

    errors: list[str] = []
    keys = list(sdf.essential)
    if keys != byte_sorted(keys):
        errors.append("top-level essential entries are not byte-sorted")
    for name, sl in sdf.slices.items():
        keys = list(sl.essential)
        if keys != byte_sorted(keys):
            errors.append(f"slices.{name}.essential entries are not byte-sorted")
        keys = list(sl.contents)
        if keys != byte_sorted(keys):
            errors.append(f"slices.{name}.contents paths are not byte-sorted")
    return errors


def _check_required(sdf: SDF) -> list[str]:
    """Verify required fields and basic invariants."""

    errors: list[str] = []
    if not sdf.package:
        errors.append("missing required field: package")
    if sdf.store is None:
        errors.append("missing required field: store")
    if sdf.default_track is None:
        errors.append("missing required field: default-track")
    if not sdf.slices:
        errors.append("missing required field: slices (or empty)")
    for name, sl in sdf.slices.items():
        for p in sl.contents:
            if not p.startswith("/"):
                errors.append(f"slices.{name}.contents path is not absolute: {p!r}")
    return errors


def validate(sdf_text: str) -> ValidationResult:
    """Validate a draft SDF string: yamllint + parse + sort + required-fields."""

    result = ValidationResult(ok=True)

    # 1. yamllint (config: 2-space indent, 100-char lines, no document-start marker).
    result.errors.extend(_run_yamllint(sdf_text))
    if result.errors:
        result.ok = False

    # 2. parse + required fields.
    import yaml

    try:
        data = yaml.safe_load(sdf_text)
    except yaml.YAMLError as exc:
        result.add(f"YAML parse error: {exc}")
        return result

    try:
        sdf = parse_sdf(data)
    except ValueError as exc:
        result.add(f"parse error: {exc}")
        return result

    result.errors.extend(_check_required(sdf))
    if result.errors:
        result.ok = False

    # 3. sort check.
    result.errors.extend(_check_sorted(sdf))
    if result.errors:
        result.ok = False

    return result


def format_errors(errors: list[str]) -> str:
    """Format validation errors for inclusion in an agent retry prompt."""

    if not errors:
        return ""
    body = "\n".join(f"  - {e}" for e in errors)
    return f"Validation errors:\n{body}\n\nFix these and regenerate the SDF."
