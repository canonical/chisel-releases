"""Validation: yamllint + sort-check + parse-check.

Run before writing the final SDF. On failure, the agent is retried (up to ``--retries``).
"""

from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass, field
from pathlib import Path

from slice_builder.sdf import SDF, byte_sorted, parse_sdf

# Path to the tool-owned yamllint config, next to this package's source tree.
_YAMLLINT_CONFIG = Path(__file__).resolve().parents[2] / "yamllint.yaml"

# Slice names: lowercase a-z, digits 0-9, minus; at least 3 chars; must start with a letter.
# Matches the rule documented in skills/sdf-generation/SKILL.md.
_SLICE_NAME_RE = re.compile(r"[a-z][a-z0-9-]{2,}")


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
    # yamllint prints "file:line:col: message". When invoked with "-" (stdin) it uses "stdin"
    # as the filename header on its own line, followed by "<line>:<col>  <level>  <msg>" lines.
    # Drop the bare filename header and any leading "-:" prefix so only the messages survive.
    cleaned: list[str] = []
    for ln in (proc.stdout + proc.stderr).splitlines():
        ln = ln.strip()
        if not ln or ln in ("-", "stdin"):
            continue
        if ln.startswith("-:"):
            ln = ln[2:].strip()
        elif ln.startswith("stdin:"):
            ln = ln[len("stdin:") :].strip()
        if ln:
            cleaned.append(ln)
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
    elif sdf.store != "bin":
        # This tool exists solely to generate bin SDFs; the store must be "bin".
        errors.append(f"store must be 'bin' for bin packages, got: {sdf.store!r}")
    if sdf.default_track is None:
        errors.append("missing required field: default-track")
    if not sdf.slices:
        errors.append("missing required field: slices (or empty)")
    for name, sl in sdf.slices.items():
        if not _SLICE_NAME_RE.fullmatch(name):
            errors.append(
                f"invalid slice name {name!r}: must be lowercase a-z/0-9/-, >=3 chars, "
                "start with a letter"
            )
        for p in sl.contents:
            if not p.startswith("/"):
                errors.append(f"slices.{name}.contents path is not absolute: {p!r}")
    return errors


def _parse_and_check_semantic(sdf_text: str) -> tuple[ValidationResult, SDF | None]:
    """Parse ``sdf_text`` and run the semantic checks (parse + required + absolute paths).

    Returns the result and the parsed SDF (None on parse failure). Does NOT run yamllint or the
    sort check — those are style concerns the builder's own ``render()`` re-imposes, so they
    should not trigger an agent retry.
    """

    result = ValidationResult(ok=True)

    import yaml

    try:
        data = yaml.safe_load(sdf_text)
    except yaml.YAMLError as exc:
        result.add(f"YAML parse error: {exc}")
        return result, None

    try:
        sdf = parse_sdf(data)
    except ValueError as exc:
        result.add(f"parse error: {exc}")
        return result, None

    result.errors.extend(_check_required(sdf))
    if result.errors:
        result.ok = False
    return result, sdf


def validate_semantic(sdf_text: str) -> ValidationResult:
    """Validate only what the agent is responsible for: parse + required fields + absolute paths.

    Used in the agent retry loop. yamllint and byte-sort are skipped because ``render()``
    re-imposes them deterministically after the agent runs; retrying the agent for a style or
    ordering issue it was about to have fixed would waste an LLM round-trip.
    """

    result, _ = _parse_and_check_semantic(sdf_text)
    return result


def validate(sdf_text: str) -> ValidationResult:
    """Validate a draft SDF string: yamllint + parse + sort + required-fields.

    The full check, run on the final rendered text after ``render()`` has re-imposed style and
    ordering. For the agent retry loop prefer :func:`validate_semantic`.
    """

    result = ValidationResult(ok=True)

    # 1. yamllint (config: 2-space indent, 100-char lines, no document-start marker).
    result.errors.extend(_run_yamllint(sdf_text))
    if result.errors:
        result.ok = False

    # 2. parse + required fields + absolute paths.
    sem, _ = _parse_and_check_semantic(sdf_text)
    if not sem.ok:
        # Preserve yamllint errors already collected, then add semantic ones.
        result.errors.extend(sem.errors)
        result.ok = False
        # If parsing failed there is nothing more to check.
        if not any("parse" in e for e in sem.errors):
            pass
        else:
            return result

    # Re-parse to run the sort check (cheap, and _parse_and_check already validated structure).
    import yaml

    try:
        sdf = parse_sdf(yaml.safe_load(sdf_text))
    except (yaml.YAMLError, ValueError):
        # Already reported above; nothing more to do.
        return result

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
